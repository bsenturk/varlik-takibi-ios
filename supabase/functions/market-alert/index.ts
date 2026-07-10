// market-alert — daily check: did gold, USD/TRY or BIST 100 move by more
// than ±1.5% today? If so, broadcast a push via `send-push-notification`.
//
// Intended to run once a day (see supabase/README.md for the pg_cron
// schedule). Protected by the same shared-secret convention as tefas-sync.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

const THRESHOLD_PERCENT = 1.5;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const FUNCTIONS_URL = SUPABASE_URL.replace(".supabase.co", ".functions.supabase.co");

interface Movement {
  label: string;
  changePercent: number;
}

// BIST 100 isn't in `assets_prices` (only individual BIST stocks are), so we
// read it straight from Yahoo Finance's public chart endpoint — same spirit
// as `tefas-sync` scraping TEFAS directly for fund prices.
async function fetchBist100ChangePercent(): Promise<number | null> {
  const res = await fetch(
    "https://query1.finance.yahoo.com/v8/finance/chart/XU100.IS?range=5d&interval=1d",
    { headers: { "User-Agent": "Mozilla/5.0" } },
  );
  if (!res.ok) return null;
  const data = await res.json();
  const result = data?.chart?.result?.[0];
  const current = result?.meta?.regularMarketPrice;
  const timestamps: number[] = result?.timestamp ?? [];
  const closes: (number | null)[] = result?.indicators?.quote?.[0]?.close ?? [];
  if (typeof current !== "number") return null;

  // NOTE: Yahoo's meta.chartPreviousClose is the close of the day *before the
  // range window* (~5 days ago for range=5d), NOT yesterday — using it gives
  // wildly wrong daily % changes (and false alerts). Derive the real previous
  // close from the daily candles instead: the most recent bar dated before
  // today (Europe/Istanbul). The cron only runs on weekdays during market
  // hours, so today's (forming) bar is always present.
  const dateFmt = (ms: number) =>
    new Date(ms).toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
  const today = dateFmt(Date.now());
  let prevClose: number | null = null;
  for (let i = timestamps.length - 1; i >= 0; i--) {
    if (dateFmt(timestamps[i] * 1000) < today && typeof closes[i] === "number") {
      prevClose = closes[i];
      break;
    }
  }
  if (prevClose === null) return null;
  return ((current - prevClose) / prevClose) * 100;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  const expected = Deno.env.get("SYNC_SECRET");
  if (expected && req.headers.get("x-sync-secret") !== expected) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  try {
    const today = new Date().toISOString().slice(0, 10);

    // Fast path: today's alert already went out — skip the price/Yahoo fetch.
    const { data: already } = await supabase
      .from("market_alert_log")
      .select("alert_date")
      .eq("alert_date", today)
      .maybeSingle();
    if (already) {
      return jsonResponse({ sent: false, reason: "already sent today" });
    }

    const { data: rows, error } = await supabase
      .from("assets_prices")
      .select("symbol, change_percent")
      .eq("currency", "TRY")
      .in("symbol", ["GRAM_ALTIN", "USD"]);
    if (error) throw error;

    const byPct = new Map(rows?.map((r) => [r.symbol, r.change_percent as number | null]));
    const bist = await fetchBist100ChangePercent();

    const candidates: Movement[] = [
      { label: "Altın", changePercent: byPct.get("GRAM_ALTIN") ?? null },
      { label: "Dolar", changePercent: byPct.get("USD") ?? null },
      { label: "BIST 100", changePercent: bist },
    ].filter((m): m is Movement =>
      typeof m.changePercent === "number" && Math.abs(m.changePercent) >= THRESHOLD_PERCENT
    );

    if (candidates.length === 0) {
      return jsonResponse({ sent: false, reason: "no threshold crossed", gold: byPct.get("GRAM_ALTIN"), usd: byPct.get("USD"), bist });
    }

    // Durable-ish trail in the Edge function logs (net._http_response is purged
    // within hours) so a future "why did this fire?" is answerable.
    console.log("market-alert triggering:", JSON.stringify({ candidates, gold: byPct.get("GRAM_ALTIN"), usd: byPct.get("USD"), bist }));

    // Atomically claim today BEFORE sending. alert_date is the PK, so if two
    // invocations race (two cron ticks, or a manual re-run alongside the cron),
    // only the one that wins this insert sends — the loser bails here. This is
    // the real dedup guard; the SELECT above is just a cheap fast path.
    const { error: claimErr } = await supabase
      .from("market_alert_log")
      .insert({ alert_date: today });
    if (claimErr) {
      return jsonResponse({ sent: false, reason: "already claimed today" });
    }

    const title = "Piyasalarda hareketlilik";
    const body = "📈 Piyasalarda hareketlilik var, portföyünüzü kontrol etmeyi unutmayın.";

    const pushRes = await fetch(`${FUNCTIONS_URL}/send-push-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-push-secret": Deno.env.get("PUSH_SECRET") ?? "",
      },
      body: JSON.stringify({ title, body }),
    });
    const push = await pushRes.json().catch(() => ({}));

    // If the push didn't actually go out, release today's claim so a later
    // tick can retry instead of silently swallowing the alert.
    if (!pushRes.ok) {
      await supabase.from("market_alert_log").delete().eq("alert_date", today);
      return jsonResponse({ sent: false, reason: "push failed", push }, 502);
    }

    return jsonResponse({ sent: true, title, movements: candidates, push });
  } catch (err) {
    console.error("market-alert error:", err);
    return errorResponse(err);
  }
});
