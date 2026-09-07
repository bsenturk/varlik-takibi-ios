// Kripto logolarını CoinGecko'dan alır, Storage'a kopyalar ve
// assets_prices.logo_url'e kendi kalıcı URL'imizi yazar.
//
// Neden ayrı bir fonksiyon: kripto fiyatlarını yazan iş bu repoda değil; ona
// dokunmadan logoları doldurabilmek gerekiyor. Logolar da fiyat gibi dakikalık
// bir veri değil — coin listesi değiştiğinde elle ya da seyrek bir cron ile
// çalıştırmak yeterli. Çalıştırması idempotent.
//
// Sembol → CoinGecko id eşlemesi elle tutulmuyor: `assets_prices.name` kolonu
// kripto satırlarında zaten CoinGecko id'sini taşıyor ("avalanche-2", "ripple").
// Liste veritabanından türetildiği için yeni bir coin eklendiğinde burada
// değişiklik gerekmiyor.
//
// Görseller neden kopyalanıyor: CoinGecko CDN'i Cache-Control göndermiyor, bu
// yüzden istemcide önbelleklenmiyor; ayrıca hotlink her kullanıcının IP'sini
// üçüncü tarafa açar ve o uç kapanırsa bütün logolar birden kırılır.

import { createServiceClient } from "../_shared/prices.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";
import { mapWithConcurrency, storeLogo } from "../_shared/logos.ts";

const MARKETS_URL = "https://api.coingecko.com/api/v3/coins/markets";

interface MarketRow {
  id: string;
  image: string | null;
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const supabase = createServiceClient();

    // 1) Hangi coin'ler var? (name = CoinGecko id)
    const { data: rows, error } = await supabase
      .from("assets_prices")
      .select("symbol,name")
      .eq("asset_type", "crypto");
    if (error) throw new Error("DB read error: " + error.message);

    // symbol → id. Aynı sembolün TRY/USD satırları aynı id'yi taşıyor.
    const idBySymbol = new Map<string, string>();
    for (const row of rows ?? []) {
      if (row.name) idBySymbol.set(row.symbol, row.name);
    }
    if (idBySymbol.size === 0) {
      return jsonResponse({ status: "ok", updated: 0, reason: "no crypto rows" });
    }

    // 2) Logo adreslerini tek çağrıda al.
    const ids = [...new Set(idBySymbol.values())].join(",");
    const url = `${MARKETS_URL}?vs_currency=usd&ids=${encodeURIComponent(ids)}&per_page=250`;
    const response = await fetch(url, { headers: { accept: "application/json" } });
    if (!response.ok) {
      throw new Error(`CoinGecko ${response.status}: ${await response.text()}`);
    }
    const markets = (await response.json()) as MarketRow[];
    const imageById = new Map(markets.map((m) => [m.id, m.image]));

    // 3) İndir → Storage'a koy → logo_url'e kendi adresimizi yaz.
    const entries = [...idBySymbol.entries()];
    const outcomes = await mapWithConcurrency(entries, 6, async ([symbol, id]) => {
      const sourceURL = imageById.get(id);
      if (!sourceURL) return { symbol, ok: false };
      const ok = await storeLogo(supabase, {
        symbol,
        assetType: "crypto",
        sourceURL,
        folder: "crypto",
      });
      return { symbol, ok };
    });

    return jsonResponse({
      status: "ok",
      updated: outcomes.filter((o) => o.ok).map((o) => o.symbol),
      missing: outcomes.filter((o) => !o.ok).map((o) => o.symbol),
    });
  } catch (err) {
    return errorResponse(err);
  }
});
