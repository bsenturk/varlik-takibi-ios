// Shared Supabase client + assets_prices upsert helpers.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export type AssetType =
  | "crypto"
  | "currency"
  | "gold"
  | "bist"
  | "us_stock"
  | "fund";

export interface AssetPrice {
  symbol: string;
  name?: string | null;
  asset_type: AssetType;
  price: number;
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
  const clean = rows.filter((r) => Number.isFinite(r.price));
  if (clean.length === 0) return [];

  const now = new Date().toISOString();
  const payload = clean.map((r) => ({
    symbol: r.symbol,
    name: r.name ?? null,
    asset_type: r.asset_type,
    price: r.price,
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
