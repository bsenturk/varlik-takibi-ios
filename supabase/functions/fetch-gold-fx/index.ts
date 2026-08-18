import { createServiceClient, toNumber, upsertPrices, type AssetPrice } from "../_shared/prices.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

// Truncgil is the source for Turkish-market gold products (with local premiums)
// and FX. The iOS app used to call this directly; now the backend owns it and
// the app reads everything from assets_prices.
const TRUNCGIL_URL = "https://finance.truncgil.com/api/today.json";

// Truncgil key -> assets_prices symbol (must match AssetType.supabaseSymbol in the app).
const GOLD: { key: string; symbol: string; name: string }[] = [
  { key: "GRA", symbol: "GRAM_ALTIN", name: "Gram Altın" },
  { key: "CEYREKALTIN", symbol: "CEYREK_ALTIN", name: "Çeyrek Altın" },
  { key: "YARIMALTIN", symbol: "YARIM_ALTIN", name: "Yarım Altın" },
  { key: "TAMALTIN", symbol: "TAM_ALTIN", name: "Tam Altın" },
  { key: "CUMHURIYETALTINI", symbol: "CUMHURIYET_ALTIN", name: "Cumhuriyet Altını" },
  { key: "ATAALTIN", symbol: "ATA_ALTIN", name: "Ata Altın" },
  { key: "RESATALTIN", symbol: "RESAT_ALTIN", name: "Reşat Altın" },
  { key: "HAMITALTIN", symbol: "HAMIT_ALTIN", name: "Hamit Altın" },
  { key: "BESLIALTIN", symbol: "BESLI_ALTIN", name: "Beşli Altın" },
  { key: "GREMSEALTIN", symbol: "GREMSE_ALTIN", name: "Gremse Altın" },
  { key: "14AYARALTIN", symbol: "14_AYAR_ALTIN", name: "14 Ayar Altın" },
  { key: "18AYARALTIN", symbol: "18_AYAR_ALTIN", name: "18 Ayar Altın" },
  { key: "IKIBUCUKALTIN", symbol: "IKIBUCUK_ALTIN", name: "İki Buçuk Altın" },
  { key: "YIA", symbol: "22_AYAR_BILEZIK", name: "22 Ayar Bilezik" },
  { key: "GUMUS", symbol: "GRAM_GUMUS", name: "Gram Gümüş" },
];

// `scale`: Truncgil JPY'yi gerçek kurun 1/100'ü olarak veriyor (0,003003 →
// 0,3003 TL). Diğer kurlarda ölçek doğru, o yüzden varsayılan 1.
const FX: { key: string; symbol: string; name: string; scale?: number }[] = [
  { key: "USD", symbol: "USD", name: "Dolar" },
  { key: "EUR", symbol: "EUR", name: "Euro" },
  { key: "GBP", symbol: "GBP", name: "Sterlin" },
  { key: "CHF", symbol: "CHF", name: "İsviçre Frangı" },
  { key: "SAR", symbol: "SAR", name: "Suudi Riyali" },
  { key: "CAD", symbol: "CAD", name: "Kanada Doları" },
  { key: "RUB", symbol: "RUB", name: "Rus Rublesi" },
  { key: "AED", symbol: "AED", name: "BAE Dirhemi" },
  { key: "AUD", symbol: "AUD", name: "Avustralya Doları" },
  { key: "DKK", symbol: "DKK", name: "Danimarka Kronu" },
  { key: "SEK", symbol: "SEK", name: "İsveç Kronu" },
  { key: "NOK", symbol: "NOK", name: "Norveç Kronu" },
  { key: "JPY", symbol: "JPY", name: "Japon Yeni", scale: 100 },
  { key: "KWD", symbol: "KWD", name: "Kuveyt Dinarı" },
];

interface TruncgilRate {
  Buying?: number | string;
  Selling?: number | string;
  Change?: number | string;
}

// Truncgil quotes Buying/Selling; we store Selling as the canonical price.
function priceOf(rate: TruncgilRate | undefined): number {
  if (!rate) return NaN;
  const sell = toNumber(rate.Selling);
  return Number.isFinite(sell) ? sell : toNumber(rate.Buying);
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const res = await fetch(TRUNCGIL_URL, { headers: { Accept: "application/json" } });
    if (!res.ok) throw new Error(`Truncgil HTTP ${res.status}: ${await res.text()}`);

    const body = await res.json();
    const rates: Record<string, TruncgilRate> = body?.Rates ?? body;
    if (!rates || typeof rates !== "object") {
      throw new Error("Truncgil response missing Rates object");
    }

    const rows: AssetPrice[] = [];

    for (const g of GOLD) {
      const rate = rates[g.key];
      const price = priceOf(rate);
      if (!Number.isFinite(price)) continue;
      rows.push({
        symbol: g.symbol,
        name: g.name,
        asset_type: "gold",
        price,
        currency: "TRY",
        change_percent: rate ? toNumber(rate.Change) : null,
        source: "truncgil",
      });
    }

    for (const fx of FX) {
      const rate = rates[fx.key];
      const price = priceOf(rate) * (fx.scale ?? 1);
      if (!Number.isFinite(price)) continue;
      rows.push({
        symbol: fx.symbol,
        name: fx.name,
        asset_type: "currency",
        price,
        currency: "TRY",
        change_percent: rate ? toNumber(rate.Change) : null,
        source: "truncgil",
      });
    }

    // Base currency: 1 TRY = 1 TRY (lets the app treat TRY uniformly).
    rows.push({
      symbol: "TRY",
      name: "Türk Lirası",
      asset_type: "currency",
      price: 1,
      currency: "TRY",
      change_percent: 0,
      source: "truncgil",
    });

    const supabase = createServiceClient();
    const saved = await upsertPrices(supabase, rows);

    return jsonResponse({
      status: "success",
      source: "truncgil",
      total_saved: saved.length,
      data: saved,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
