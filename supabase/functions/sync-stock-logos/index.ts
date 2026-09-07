// Hisse logolarını Financial Modeling Prep'ten alır, Storage'a kopyalar ve
// assets_prices.logo_url'e kendi kalıcı adresimizi yazar.
//
// Neden FMP: fiyat kaynağımız Yahoo Finance ve Yahoo logo servis etmiyor
// (quoteSummary artık crumb istiyor, üstelik logo alanı yok). FMP'nin
// `image-stock` ucu anahtarsız çalışıyor ve — beklenmedik şekilde — BIST
// sembollerini de kapsıyor.
//
// Kapsam ölçüldü: ABD 34/34, BIST blue-chip 24/24, BIST geneli 40 örnekte
// 10/40. Bulunamayan sembol 404 döner, logo_url NULL kalır ve istemci mevcut
// kategori ikonunda kalır — yani eksik kapsam bir bozulma değil.
//
// `asset_type` gövdeden geçiliyor (varsayılan "us_stock"). BIST tamamen aynı
// kod yolunu kullanıyor; 660 sembol tek çağrıya sığmayabileceği için `limit`
// ve `offset` ile parça parça çalıştırılabilir.

import { createServiceClient } from "../_shared/prices.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { mapWithConcurrency, storeLogo } from "../_shared/logos.ts";

const IMAGE_URL = "https://financialmodelingprep.com/image-stock";
const SUPPORTED = new Set(["us_stock", "bist"]);

interface Params {
  asset_type?: string;
  limit?: number;
  offset?: number;
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const params: Params = req.method === "POST"
      ? await req.json().catch(() => ({}))
      : {};
    const assetType = params.asset_type ?? "us_stock";
    if (!SUPPORTED.has(assetType)) {
      return jsonResponse(
        { status: "error", error: `unsupported asset_type: ${assetType}` },
        400,
      );
    }

    const supabase = createServiceClient();

    const { data: rows, error } = await supabase
      .from("assets_prices")
      .select("symbol")
      .eq("asset_type", assetType);
    if (error) throw new Error("DB read error: " + error.message);

    const all = [...new Set((rows ?? []).map((r) => r.symbol))].sort();
    const offset = params.offset ?? 0;
    const symbols = params.limit ? all.slice(offset, offset + params.limit) : all.slice(offset);

    const outcomes = await mapWithConcurrency(symbols, 8, async (symbol) => {
      const ok = await storeLogo(supabase, {
        symbol,
        assetType,
        sourceURL: `${IMAGE_URL}/${encodeURIComponent(symbol)}.png`,
        folder: "stocks",
      });
      return { symbol, ok };
    });

    const updated = outcomes.filter((o) => o.ok).map((o) => o.symbol);
    const missing = outcomes.filter((o) => !o.ok).map((o) => o.symbol);

    return jsonResponse({
      status: "ok",
      asset_type: assetType,
      total: all.length,
      processed: symbols.length,
      updated: updated.length,
      missing_count: missing.length,
      missing,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
