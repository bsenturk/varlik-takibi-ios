// Logo indirme → Storage'a kopyalama → assets_prices.logo_url'e yazma.
//
// Kripto (CoinGecko) ve hisse (FMP) fonksiyonları aynı işi yapıyor, yalnızca
// logonun kaynağı farklı; ortak kısım burada.
//
// Görseller neden kopyalanıyor da hotlink edilmiyor: kaynak CDN'ler
// Cache-Control göndermiyor (istemcide önbelleklenmiyor), hotlink her
// kullanıcının IP'sini üçüncü tarafa açar ve o uç kapanırsa bütün logolar
// birden kırılır.

import type { SupabaseClient } from "@supabase/supabase-js";

export const LOGO_BUCKET = "asset-logos";
/// Logolar değişmeyen veri; bir yıl önbellek güvenli.
const CACHE_CONTROL = "31536000";

/// İçerik tipinden dosya uzantısı. Kaynaklar hepsini png servis etmiyor
/// (ör. CoinGecko'da polkadot.jpg), uzantıyı yanıttan almak gerekiyor.
export function extensionFor(contentType: string | null, sourceURL: string): string {
  if (contentType?.includes("png")) return "png";
  if (contentType?.includes("jpeg") || contentType?.includes("jpg")) return "jpg";
  if (contentType?.includes("webp")) return "webp";
  if (contentType?.includes("svg")) return "svg";
  const fromPath = new URL(sourceURL).pathname.split(".").pop();
  return fromPath && fromPath.length <= 4 ? fromPath : "png";
}

/**
 * Bir sembolün logosunu indirir, Storage'a koyar ve o sembolün BÜTÜN
 * satırlarına (ör. bir coin'in TRY ve USD satırı) logo_url yazar.
 *
 * Kaynak 404 verirse — hisselerde yaygın, FMP her sembolü kapsamıyor —
 * `false` döner ve logo_url NULL kalır; istemci kategori ikonunda kalır.
 */
export async function storeLogo(
  supabase: SupabaseClient,
  params: {
    symbol: string;
    assetType: string;
    sourceURL: string;
    /// Bucket içindeki klasör: "crypto", "stocks" …
    folder: string;
  },
): Promise<boolean> {
  const { symbol, assetType, sourceURL, folder } = params;

  const image = await fetch(sourceURL);
  if (!image.ok) return false;

  const contentType = image.headers.get("content-type");
  // Boyut kontrolü: bazı uçlar "bulunamadı"yı 200 + minik bir yer tutucu
  // görselle döndürüyor; birkaç yüz bayt bir logo olamaz.
  const bytes = new Uint8Array(await image.arrayBuffer());
  if (bytes.byteLength < 500) return false;

  const path = `${folder}/${symbol}.${extensionFor(contentType, sourceURL)}`;
  const { error: uploadError } = await supabase.storage
    .from(LOGO_BUCKET)
    .upload(path, bytes, {
      contentType: contentType ?? "image/png",
      cacheControl: CACHE_CONTROL,
      upsert: true,
    });
  if (uploadError) throw new Error(`Storage upload error (${symbol}): ${uploadError.message}`);

  const { data: publicURL } = supabase.storage.from(LOGO_BUCKET).getPublicUrl(path);

  const { error: updateError } = await supabase
    .from("assets_prices")
    .update({ logo_url: publicURL.publicUrl })
    .eq("asset_type", assetType)
    .eq("symbol", symbol);
  if (updateError) throw new Error(`DB update error (${symbol}): ${updateError.message}`);

  return true;
}

/**
 * `items` üzerinde sınırlı eşzamanlılıkla çalışır. Sıralı işlem 660 BIST
 * sembolünde fonksiyon zaman aşımına uğrar; sınırsız eşzamanlılık da kaynak
 * API'yi rate-limit'e sokar.
 */
export async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = new Array(items.length);
  let cursor = 0;
  async function run() {
    while (true) {
      const index = cursor++;
      if (index >= items.length) return;
      results[index] = await worker(items[index]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, run));
  return results;
}
