// Shared TEFAS (Türkiye Elektronik Fon Alım Satım Platformu) helpers.
//
// NOTE: TEFAS retired the old `api/DB/BindHistoryInfo` gateway (it now returns
// ERR-006 "method disabled" behind F5 Shape bot-defense). The current source is
// the JSON API the new site uses: POST `api/funds/fonGnlBlgSiraliGetir`, which
// works over plain HTTP and returns numeric prices. Both `scrape-tefas`
// (popular funds) and `search-tefas` (search by code/name) use these helpers.

import { type AssetPrice } from "./prices.ts";

export const TEFAS_URL =
  "https://www.tefas.gov.tr/api/funds/fonGnlBlgSiraliGetir";

export interface TefasFundRow {
  fonKodu: string;
  fonUnvan?: string;
  tarih: string; // "YYYY-MM-DD"
  fiyat: number;
  tedPaySayisi?: number;
  kisiSayisi?: number;
  portfoyBuyukluk?: number;
}

// Format a Date as YYYYMMDD (the format the new TEFAS API expects).
export function tefasDate(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}${month}${day}`;
}

/**
 * POST to the TEFAS funds API for a date range. Pass a `code` to fetch a single
 * fund, or `null` to fetch *every* YAT fund in the range (used by search, which
 * then filters by code/name client-side).
 */
export async function fetchTefasFunds(
  code: string | null,
  start: Date,
  end: Date,
): Promise<TefasFundRow[]> {
  const res = await fetch(TEFAS_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "*/*",
      "Origin": "https://www.tefas.gov.tr",
      "Referer": "https://www.tefas.gov.tr/tr/fon-verileri",
      "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    },
    body: JSON.stringify({
      fonTipi: "YAT",
      fonKodu: code, // null = every fund
      basTarih: tefasDate(start),
      bitTarih: tefasDate(end),
      basSira: 1,
      bitSira: 100000,
      aramaMetni: "",
      fonTurKod: "",
      fonGrubu: "",
      sfonTurKod: "",
      fonTurAciklama: "",
      kurucuKod: "",
      dil: "TR",
    }),
  });

  if (!res.ok) {
    throw new Error(
      `TEFAS HTTP ${res.status} for "${code ?? "ALL"}": ${await res.text()}`,
    );
  }

  const json = (await res.json()) as {
    errorCode?: string | null;
    errorMessage?: string | null;
    resultList?: TefasFundRow[];
  };
  if (json.errorCode) {
    throw new Error(`TEFAS error ${json.errorCode}: ${json.errorMessage ?? ""}`);
  }
  return json.resultList ?? [];
}

/**
 * Collapse a multi-day range to the most recent NAV row per fund code. Covers
 * weekends/holidays where there is no NAV published "today". `tarih` is
 * "YYYY-MM-DD", so a lexical comparison is also chronological.
 */
export function latestRowPerFund(rows: TefasFundRow[]): TefasFundRow[] {
  const byCode = new Map<string, TefasFundRow>();
  for (const row of rows) {
    if (!row.fonKodu) continue;
    const prev = byCode.get(row.fonKodu);
    if (!prev || row.tarih > prev.tarih) {
      byCode.set(row.fonKodu, row);
    }
  }
  return [...byCode.values()];
}

/** Map a TEFAS row to an `assets_prices` row. Returns null if the price is junk. */
export function rowToAssetPrice(row: TefasFundRow): AssetPrice | null {
  const price = typeof row.fiyat === "number" ? row.fiyat : Number(row.fiyat);
  if (!Number.isFinite(price)) return null;
  return {
    symbol: row.fonKodu,
    name: row.fonUnvan ?? null,
    asset_type: "fund",
    price,
    currency: "TRY",
    change_percent: null,
    source: "tefas",
  };
}

/**
 * Fold a Turkish string for accent/case-insensitive matching so a search for
 * "teknoloji" matches "TEKNOLOJİ" and "para" matches "PARA". Maps Turkish
 * letters (ı/İ/ş/ğ/ü/ö/ç) to their ASCII counterparts.
 */
export function foldTr(s: string): string {
  return s
    .toLocaleLowerCase("tr-TR")
    .replaceAll("ı", "i")
    .replaceAll("i̇", "i") // dotted-i that some locales emit
    .replaceAll("ş", "s")
    .replaceAll("ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("ö", "o")
    .replaceAll("ç", "c")
    .trim();
}
