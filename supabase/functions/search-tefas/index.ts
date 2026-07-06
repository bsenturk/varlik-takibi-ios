// On-demand TEFAS fund search. The app's fund search bar calls this when the
// user types a code or name that isn't in the locally-cached "popular" funds.
//
// It pulls every fund TEFAS published over the last ~7 days, keeps the latest
// NAV per fund, filters by code OR name (Turkish accent/case-insensitive),
// upserts the matches into `assets_prices`, and returns them so the client can
// show results immediately.

import {
  createServiceClient,
  upsertPrices,
  type AssetPrice,
} from "../_shared/prices.ts";
import {
  fetchTefasFunds,
  foldTr,
  latestRowPerFund,
  rowToAssetPrice,
} from "../_shared/tefas.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

const MIN_QUERY = 2;
const MAX_RESULTS = 25;

// Read `q` from the query string (?q=) or a JSON/form POST body.
async function readQuery(req: Request, url: URL): Promise<string> {
  const fromUrl = url.searchParams.get("q");
  if (fromUrl) return fromUrl;
  if (req.method === "POST") {
    const body = await req.json().catch(() => null) as { q?: unknown } | null;
    if (body && typeof body.q === "string") return body.q;
  }
  return "";
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const url = new URL(req.url);
    const q = (await readQuery(req, url)).trim();

    if (q.length < MIN_QUERY) {
      return jsonResponse(
        { status: "error", error: `Query 'q' must be at least ${MIN_QUERY} characters.` },
        400,
      );
    }

    // Pull all funds for the last ~7 days, keep the latest NAV per fund.
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - 7);
    const allFunds = latestRowPerFund(await fetchTefasFunds(null, start, end));

    const needle = foldTr(q);
    const matches = allFunds.filter((r) =>
      foldTr(r.fonKodu).includes(needle) ||
      foldTr(r.fonUnvan ?? "").includes(needle)
    );

    // Exact code match first, then alphabetically by code.
    matches.sort((a, b) => {
      const aExact = foldTr(a.fonKodu) === needle ? 0 : 1;
      const bExact = foldTr(b.fonKodu) === needle ? 0 : 1;
      if (aExact !== bExact) return aExact - bExact;
      return a.fonKodu.localeCompare(b.fonKodu);
    });

    const prices = matches
      .slice(0, MAX_RESULTS)
      .map(rowToAssetPrice)
      .filter((p): p is AssetPrice => p !== null);

    const supabase = createServiceClient();
    const saved = await upsertPrices(supabase, prices);

    // Echo the saved rows shaped like `assets_prices` (incl. updated_at) so the
    // client can decode them with the same model it uses for the table.
    const now = new Date().toISOString();
    const data = saved.map((p) => ({
      symbol: p.symbol,
      currency: p.currency,
      name: p.name ?? null,
      asset_type: p.asset_type,
      price: p.price,
      change_percent: p.change_percent ?? null,
      source: p.source,
      updated_at: now,
    }));

    return jsonResponse({
      status: "success",
      source: "tefas",
      query: q,
      total_matches: matches.length,
      total_saved: data.length,
      data,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
