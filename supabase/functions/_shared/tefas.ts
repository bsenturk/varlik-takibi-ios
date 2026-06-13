// Minimal TEFAS (Türkiye Elektronik Fon Alım Satım Platformu) client.
//
// TEFAS exposes a JSON endpoint used by its own website. We call it server-side
// only (never from the iOS app) and cache the results in our own tables.
//
// NOTE: TEFAS is an undocumented/3rd-party endpoint. If the response shape or
// anti-bot headers change, adjust `TEFAS_HEADERS` / field names below.

const TEFAS_BASE = "https://www.tefas.gov.tr";

const TEFAS_HEADERS: HeadersInit = {
  "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
  "Accept": "application/json, text/javascript, */*; q=0.01",
  "X-Requested-With": "XMLHttpRequest",
  "Referer": `${TEFAS_BASE}/TarihselVeriler.aspx`,
  "Origin": TEFAS_BASE,
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15",
};

export interface FundRow {
  code: string;        // FONKODU
  name: string;        // FONUNVAN
  price: number;       // FIYAT (unit price, TRY)
  date: Date;          // TARIH
  investors: number;   // KISISAYISI
  size: number;        // PORTBUYUKLUK
}

/** dd.MM.yyyy — the format TEFAS expects. */
function formatDate(d: Date): string {
  const dd = String(d.getUTCDate()).padStart(2, "0");
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  return `${dd}.${mm}.${d.getUTCFullYear()}`;
}

async function tefasPost(path: string, body: Record<string, string>): Promise<any> {
  const res = await fetch(`${TEFAS_BASE}${path}`, {
    method: "POST",
    headers: TEFAS_HEADERS,
    body: new URLSearchParams(body).toString(),
  });
  if (!res.ok) {
    throw new Error(`TEFAS ${path} failed: ${res.status} ${res.statusText}`);
  }
  return await res.json();
}

/**
 * Fetches the latest available row for EVERY fund (empty `fonkod` returns all
 * funds in the date window). We look back a few days to skip weekends/holidays
 * and keep the newest row per fund code.
 */
export async function fetchAllFundsLatest(lookbackDays = 7): Promise<FundRow[]> {
  const to = new Date();
  const from = new Date();
  from.setUTCDate(from.getUTCDate() - lookbackDays);

  const json = await tefasPost("/api/DB/BindHistoryInfo", {
    fontip: "YAT",          // YAT = securities mutual funds
    sfontur: "",
    fonkod: "",             // empty => all funds
    fongrup: "",
    bastarih: formatDate(from),
    bittarih: formatDate(to),
    fonturkod: "",
    fonunvantip: "",
    strperiod: "1,1,1,1,1,1",
    islemdurum: "1",
  });

  const rows: any[] = json?.data ?? [];
  const latest = new Map<string, FundRow>();
  for (const r of rows) {
    const code = String(r.FONKODU ?? "").trim();
    if (!code) continue;
    const date = new Date(Number(r.TARIH)); // epoch ms
    const prev = latest.get(code);
    if (!prev || date > prev.date) {
      latest.set(code, {
        code,
        name: String(r.FONUNVAN ?? "").trim(),
        price: Number(r.FIYAT ?? 0),
        date,
        investors: Number(r.KISISAYISI ?? 0),
        size: Number(r.PORTBUYUKLUK ?? 0),
      });
    }
  }
  return [...latest.values()].filter((f) => f.price > 0);
}

/** Daily historical prices for a single fund (used for chart backfill). */
export async function fetchFundHistory(
  code: string,
  from: Date,
  to: Date,
): Promise<{ date: Date; price: number }[]> {
  const json = await tefasPost("/api/DB/BindHistoryInfo", {
    fontip: "YAT",
    sfontur: "",
    fonkod: code,
    fongrup: "",
    bastarih: formatDate(from),
    bittarih: formatDate(to),
    fonturkod: "",
    fonunvantip: "",
    strperiod: "1,1,1,1,1,1",
    islemdurum: "1",
  });
  return (json?.data ?? [])
    .map((r: any) => ({ date: new Date(Number(r.TARIH)), price: Number(r.FIYAT ?? 0) }))
    .filter((p: { price: number }) => p.price > 0)
    .sort((a: { date: Date }, b: { date: Date }) => a.date.getTime() - b.date.getTime());
}
