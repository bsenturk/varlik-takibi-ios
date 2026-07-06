import { createServiceClient, upsertPrices, type AssetPrice } from "../_shared/prices.ts";
import {
  fetchTefasFunds,
  latestRowPerFund,
  rowToAssetPrice,
} from "../_shared/tefas.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

// The 10 "popular" TEFAS funds surfaced by default in the app. Always refreshed,
// even when no user holds them, so the add-asset catalog shows live prices.
const POPULAR_CODES = [
  "MAC",
  "YAS",
  "TI3",
  "NNF",
  "AFT",
  "AFA",
  "TCD",
  "IPB",
  "GTL",
  "TTE",
];

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const supabase = createServiceClient();

    // Every fund a user actually holds (or previously searched) has an
    // assets_prices row. Refresh those too — otherwise a user-added fund that
    // isn't in POPULAR_CODES (e.g. "ALC") never gets a price update and its
    // profit/loss is stuck at 0.
    const { data: tracked } = await supabase
      .from("assets_prices")
      .select("symbol")
      .eq("asset_type", "fund");
    const wanted = new Set<string>([
      ...POPULAR_CODES,
      ...(tracked ?? []).map((r) => r.symbol as string),
    ]);

    // One bulk TEFAS request for ALL funds over the last ~10 days (covers
    // weekends/holidays). Fetching every fund in a single call — instead of one
    // request per code — avoids TEFAS's 429 throttling that dropped funds before.
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 10);
    const allRows = await fetchTefasFunds(null, start, end);

    const latestByCode = new Map(
      latestRowPerFund(allRows).map((row) => [row.fonKodu, row]),
    );

    const rows: AssetPrice[] = [];
    const failures: { code: string; error: string }[] = [];
    for (const code of wanted) {
      const row = latestByCode.get(code);
      const price = row ? rowToAssetPrice(row) : null;
      if (price) rows.push(price);
      else failures.push({ code, error: row ? "invalid price" : "no data" });
    }

    const saved = await upsertPrices(supabase, rows);

    return jsonResponse({
      status: "success",
      source: "tefas",
      total_saved: saved.length,
      data: saved,
      failures,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
