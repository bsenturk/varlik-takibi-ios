// market-alert — daily check: did gold, USD/TRY or BIST 100 move by more
// than ±1.5% today? If so, broadcast a push via `send-push-notification`.
//
// Intended to run once a day (see supabase/README.md for the pg_cron
// schedule). Protected by the same shared-secret convention as tefas-sync.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { handleOptions, json } from "../_shared/cors.ts";

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
  const meta = data?.chart?.result?.[0]?.meta;
  if (!meta?.regularMarketPrice || !meta?.chartPreviousClose) return null;
  return ((meta.regularMarketPrice - meta.chartPreviousClose) / meta.chartPreviousClose) * 100;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  const expected = Deno.env.get("SYNC_SECRET");
  if (expected && req.headers.get("x-sync-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  try {
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
      return json({ sent: false, reason: "no threshold crossed", gold: byPct.get("GRAM_ALTIN"), usd: byPct.get("USD"), bist });
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
    const push = await pushRes.json();

    return json({ sent: true, title, movements: candidates, push });
  } catch (err) {
    console.error("market-alert error:", err);
    return json({ error: String(err) }, 500);
  }
});
