// tefas-sync — daily refresh of the TEFAS fund catalog.
//
// 1. Pull the latest price for every fund from TEFAS.
// 2. Upsert the full catalog into `tefas_funds`.
// 3. Flag the 10 most popular funds (by investor count) as `is_popular`.
// 4. Mirror popular + already-tracked funds' prices into `assets_prices`
//    (asset_type = 'fund') so the iOS app can value holdings.
//
// Intended to run on a schedule (see supabase/README.md). Protect it with a
// shared secret header so it can't be triggered by anyone.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fetchAllFundsLatest } from "../_shared/tefas.ts";
import { corsHeaders, handleOptions, json } from "../_shared/cors.ts";

const POPULAR_COUNT = 10;

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  // Optional shared-secret guard for scheduled invocation.
  const expected = Deno.env.get("SYNC_SECRET");
  if (expected && req.headers.get("x-sync-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const funds = await fetchAllFundsLatest();
    if (funds.length === 0) {
      return json({ error: "TEFAS returned no funds" }, 502);
    }

    // Top-N by investor count = "most popular".
    const popular = new Set(
      [...funds]
        .sort((a, b) => b.investors - a.investors)
        .slice(0, POPULAR_COUNT)
        .map((f) => f.code),
    );

    const now = new Date().toISOString();

    // 1) Catalog upsert.
    const catalog = funds.map((f) => ({
      code: f.code,
      name: f.name,
      price: f.price,
      price_date: f.date.toISOString(),
      investor_count: f.investors,
      fund_size: f.size,
      is_popular: popular.has(f.code),
      updated_at: now,
    }));
    const { error: catErr } = await supabase
      .from("tefas_funds")
      .upsert(catalog, { onConflict: "code" });
    if (catErr) throw catErr;

    // 2) Which funds already have an assets_prices row (user-added / previously searched).
    const { data: tracked } = await supabase
      .from("assets_prices")
      .select("symbol")
      .eq("asset_type", "fund");
    const trackedCodes = new Set((tracked ?? []).map((r) => r.symbol));

    // 3) Mirror popular + tracked into assets_prices.
    const mirror = funds
      .filter((f) => popular.has(f.code) || trackedCodes.has(f.code))
      .map((f) => ({
        symbol: f.code,
        currency: "TRY",
        name: f.name,
        asset_type: "fund",
        price: f.price,
        change_percent: null,
        source: "tefas",
        updated_at: f.date.toISOString(),
      }));

    if (mirror.length > 0) {
      const { error: priceErr } = await supabase
        .from("assets_prices")
        .upsert(mirror, { onConflict: "symbol,currency" });
      if (priceErr) throw priceErr;
    }

    return json({
      ok: true,
      catalog: funds.length,
      popular: popular.size,
      mirrored: mirror.length,
    });
  } catch (err) {
    console.error("tefas-sync error:", err);
    return json({ error: String(err) }, 500);
  }
});
