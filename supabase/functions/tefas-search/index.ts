// tefas-search — on-demand fund search for the app's "add fund" search bar.
//
// GET /tefas-search?q=teknoloji
//   • q empty / <2 chars -> the 10 most popular funds
//   • otherwise          -> fuzzy name/code matches from `tefas_funds`
//
// Matched funds are mirrored into `assets_prices` (asset_type = 'fund') so that
// once the user picks one, the iOS MarketDataManager can price/value it.
//
// The full catalog is kept fresh by `tefas-sync`; this function only reads it,
// so searches are fast and never block on TEFAS.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleOptions, json } from "../_shared/cors.ts";

interface FundResult {
  code: string;
  name: string;
  price: number | null;
  price_date: string | null;
  investor_count: number;
}

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const url = new URL(req.url);
    const q = (url.searchParams.get("q") ?? "").trim();

    // Reuse the SQL search_funds() RPC for consistent ranking.
    const { data, error } = await supabase.rpc("search_funds", { q });
    if (error) throw error;

    const results = (data ?? []) as FundResult[];

    // Mirror matched funds into assets_prices so they can be valued once added.
    const mirror = results
      .filter((f) => f.price && f.price > 0)
      .map((f) => ({
        symbol: f.code,
        currency: "TRY",
        name: f.name,
        asset_type: "fund",
        price: f.price,
        change_percent: null,
        source: "tefas",
        updated_at: f.price_date ?? new Date().toISOString(),
      }));

    if (mirror.length > 0) {
      await supabase
        .from("assets_prices")
        .upsert(mirror, { onConflict: "symbol,currency" });
    }

    return json({
      query: q,
      count: results.length,
      funds: results.map((f) => ({
        symbol: f.code,
        name: f.name,
        price: f.price,
        updatedAt: f.price_date,
      })),
    });
  } catch (err) {
    console.error("tefas-search error:", err);
    return json({ error: String(err) }, 500);
  }
});
