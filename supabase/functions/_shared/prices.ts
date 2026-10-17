// Shared Supabase client + assets_prices upsert helpers.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export type AssetType =
  | "crypto"
  | "currency"
  | "gold"
  | "bist"
  | "us_stock"
  | "us_etf"
  | "fund";

export interface AssetPrice {
  symbol: string;
  name?: string | null;
  asset_type: AssetType;
  /// Satış fiyatı — uygulamanın her yerinde değerleme bunun üzerinden yapılır.
  price: number;
  /// Alış fiyatı. Yalnızca makas yayımlayan kaynaklarda (altın/döviz) dolu;
  /// tek fiyatlı kaynaklarda (kripto, hisse, fon) null.
  buy_price?: number | null;
  currency: string;
  change_percent?: number | null;
  source: string;
}

/**
 * Build a service-role Supabase client. Reads the SUPABASE_URL and
 * SUPABASE_SERVICE_ROLE_KEY that the Edge runtime injects automatically —
 * never hard-code these in source.
 */
export function createServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error(
      "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing from the environment.",
    );
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

/**
 * Upsert a batch of prices into public.assets_prices, keyed on (symbol, currency).
 * Rows with a non-finite price are dropped so one bad data point can't poison
 * the whole batch.
 */
export async function upsertPrices(
  supabase: SupabaseClient,
  rows: AssetPrice[],
): Promise<AssetPrice[]> {
  const finite = rows.filter((r) => Number.isFinite(r.price));
  const clean = await dropTypeCollisions(supabase, finite);
  if (clean.length === 0) return [];

  const now = new Date().toISOString();
  const payload = clean.map((r) => ({
    symbol: r.symbol,
    name: r.name ?? null,
    asset_type: r.asset_type,
    price: r.price,
    buy_price: r.buy_price ?? null,
    currency: r.currency,
    change_percent: r.change_percent ?? null,
    source: r.source,
    updated_at: now,
  }));

  const { error } = await supabase
    .from("assets_prices")
    .upsert(payload, { onConflict: "symbol,currency" });

  if (error) throw new Error("DB upsert error: " + error.message);
  return clean;
}

/**
 * Tablonun anahtarı (symbol, currency) — asset_type anahtarın parçası değil.
 * 3 harfli TEFAS fon kodları kripto sembolleriyle çakışabiliyor (ADA, SOL,
 * DOT…): çakışan upsert öbür türün satırını ezer, uygulama da fiyatı yalnızca
 * sembolle aradığı için Cardano tutanın değeri fon fiyatıyla hesaplanır (ya
 * da tersi) ve her cron'da el değiştirir.
 *
 * Kural: satır zaten BAŞKA bir türe aitse yazılmaz — ilk gelen kazanır.
 * Bilinçli bir tür değişikliği (ör. bir sembolü us_stock'tan us_etf'e taşımak)
 * da bu yüzden engellenir; önce eski satır silinmeli.
 *
 * ponytail: sembol düzeyinde bir bekçi; kalıcı çözüm anahtara asset_type'ı
 * eklemek (istemcideki sembol aramaları da türe bakacak şekilde).
 */
async function dropTypeCollisions(
  supabase: SupabaseClient,
  rows: AssetPrice[],
): Promise<AssetPrice[]> {
  if (rows.length === 0) return rows;
  const symbols = [...new Set(rows.map((r) => r.symbol))];
  const owner = new Map<string, string>(); // "symbol|currency" -> asset_type
  // `in.(…)` URL'de gidiyor; ~700 sembollük fetch-yahoo için parçalı.
  for (let i = 0; i < symbols.length; i += 150) {
    const { data, error } = await supabase
      .from("assets_prices")
      .select("symbol,currency,asset_type")
      .in("symbol", symbols.slice(i, i + 150));
    if (error) throw new Error("DB read error: " + error.message);
    for (const r of data ?? []) owner.set(`${r.symbol}|${r.currency}`, r.asset_type);
  }
  const kept = rows.filter((r) => {
    const existing = owner.get(`${r.symbol}|${r.currency}`);
    return existing === undefined || existing === r.asset_type;
  });
  if (kept.length < rows.length) {
    const skipped = rows.filter((r) => !kept.includes(r))
      .map((r) => `${r.symbol}/${r.currency}(${r.asset_type})`);
    console.warn("assets_prices: tür çakışması, yazılmadı:", skipped.join(", "));
  }
  return kept;
}

/**
 * Parse a numeric value that may arrive as a JS number or a Turkish-formatted
 * string ("3.245,67" -> 3245.67). Returns NaN if it can't be parsed.
 */
export function toNumber(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value !== "string") return NaN;
  const normalized = value
    .trim()
    .replace(/\./g, "") // thousands separator
    .replace(",", "."); // decimal separator
  return parseFloat(normalized);
}
