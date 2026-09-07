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

const MARKETS_URL = "https://api.coingecko.com/api/v3/coins/markets";
const BUCKET = "asset-logos";
/// Logolar değişmiyor; bir yıl önbellek güvenli.
const CACHE_CONTROL = "31536000";

interface MarketRow {
  id: string;
  image: string | null;
}

/// İçerik tipinden dosya uzantısı. CoinGecko hepsini png servis etmiyor
/// (ör. polkadot.jpg), uzantıyı yanıttan almak gerekiyor.
function extensionFor(contentType: string | null, sourceURL: string): string {
  if (contentType?.includes("png")) return "png";
  if (contentType?.includes("jpeg") || contentType?.includes("jpg")) return "jpg";
  if (contentType?.includes("webp")) return "webp";
  if (contentType?.includes("svg")) return "svg";
  const fromPath = new URL(sourceURL).pathname.split(".").pop();
  return fromPath && fromPath.length <= 4 ? fromPath : "png";
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
    const updated: string[] = [];
    const missing: string[] = [];

    for (const [symbol, id] of idBySymbol) {
      const sourceURL = imageById.get(id);
      if (!sourceURL) {
        missing.push(symbol);
        continue;
      }

      const image = await fetch(sourceURL);
      if (!image.ok) {
        missing.push(symbol);
        continue;
      }
      const contentType = image.headers.get("content-type");
      const path = `crypto/${symbol}.${extensionFor(contentType, sourceURL)}`;
      const bytes = new Uint8Array(await image.arrayBuffer());

      const { error: uploadError } = await supabase.storage
        .from(BUCKET)
        .upload(path, bytes, {
          contentType: contentType ?? "image/png",
          cacheControl: CACHE_CONTROL,
          upsert: true,
        });
      if (uploadError) throw new Error(`Storage upload error (${symbol}): ${uploadError.message}`);

      const { data: publicURL } = supabase.storage.from(BUCKET).getPublicUrl(path);

      // Sembole göre güncelleniyor: bir coin'in TRY ve USD satırlarının ikisi
      // de aynı logoyu almalı.
      const { error: updateError } = await supabase
        .from("assets_prices")
        .update({ logo_url: publicURL.publicUrl })
        .eq("asset_type", "crypto")
        .eq("symbol", symbol);
      if (updateError) throw new Error(`DB update error (${symbol}): ${updateError.message}`);

      updated.push(symbol);
    }

    return jsonResponse({ status: "ok", updated, missing });
  } catch (err) {
    return errorResponse(err);
  }
});
