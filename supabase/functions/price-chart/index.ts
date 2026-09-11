// Geçmiş fiyat serisi — varlık ekleme ekranındaki grafiği besler.
//
// Fiyat geçmişini SAKLAMIYORUZ: `assets_prices` yalnızca güncel fiyatı tutuyor
// (upsert onConflict symbol,currency). Bunun yerine, canlı fiyat için zaten
// kullandığımız kaynakların ücretsiz geçmiş uçlarına burada proxy yapıyoruz.
// Kazanç: tablo/cron/migration yok ve 1 yıllık grafik ilk günden dolu geliyor.
//
// Altın ve döviz KAPSAM DIŞI: kaynağımız Truncgil geçmiş vermiyor, türetme
// (GC=F × USDTRY) yerel primi tutmuyor. `unsupported` dönüyoruz.

import { createServiceClient } from "../_shared/prices.ts";
import { fetchTefasFunds } from "../_shared/tefas.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

interface Point {
  t: number; // epoch saniye
  c: number; // kapanış
}

const RANGE_DAYS: Record<string, number> = { "1h": 7, "1a": 30, "3a": 90, "1y": 365 };
// Yahoo kendi aralık sözlüğünü kullanıyor; gün sayısı kabul etmiyor.
const YAHOO_RANGE: Record<string, string> = { "1h": "5d", "1a": "1mo", "3a": "3mo", "1y": "1y" };

// ponytail: izolasyon başına bellek içi cache. Tekrar eden isteklerin çoğunu
// keser (özellikle CoinGecko'nun dakikada ~30 çağrı limitine karşı). Yetmezse
// upgrade yolu: Postgres'te price_chart_cache tablosu.
const TTL_MS = 30 * 60 * 1000;
const cache = new Map<string, { at: number; body: unknown }>();

async function yahooSeries(symbol: string, range: string): Promise<Point[]> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}` +
    `?range=${YAHOO_RANGE[range]}&interval=1d`;
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
  if (!res.ok) throw new Error(`Yahoo HTTP ${res.status}`);
  const json = await res.json();
  const result = json?.chart?.result?.[0];
  if (!result) throw new Error(json?.chart?.error?.description ?? "Yahoo boş yanıt");

  const stamps: number[] = result.timestamp ?? [];
  const closes: (number | null)[] = result.indicators?.quote?.[0]?.close ?? [];
  const points: Point[] = [];
  for (let i = 0; i < stamps.length; i++) {
    const c = closes[i];
    // Tatil/kapalı günlerde Yahoo null gönderiyor; noktayı atlıyoruz.
    if (typeof c === "number" && Number.isFinite(c)) points.push({ t: stamps[i], c });
  }
  return points;
}

async function coingeckoSeries(coinId: string, range: string): Promise<Point[]> {
  const url = `https://api.coingecko.com/api/v3/coins/${encodeURIComponent(coinId)}/market_chart` +
    `?vs_currency=try&days=${RANGE_DAYS[range]}&interval=daily`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`CoinGecko HTTP ${res.status}`);
  const json = await res.json();
  const prices: [number, number][] = json?.prices ?? [];
  return prices
    .filter(([, p]) => Number.isFinite(p))
    .map(([ms, p]) => ({ t: Math.floor(ms / 1000), c: p }));
}

// TEFAS tek istekte en fazla ~30 günlük pencere döndürüyor (35 gün ve üzeri boş
// geliyor) ve art arda isteklerde ERR-224 "Throttling limit" 429 atıyor. Bu
// yüzden 3A/1Y fonlarda desteklenmiyor — parçalı çekim throttle'a takılıyor.
// ponytail: uzun aralık isteniyorsa upgrade yolu, tefas-sync'in her gece
// fiyatı küçük bir price_history tablosuna eklemesi (ileriye dönük birikir).
const TEFAS_MAX_DAYS = 30;

async function tefasSeries(code: string, range: string): Promise<Point[]> {
  const end = new Date();
  const start = new Date(end.getTime() - RANGE_DAYS[range] * 86_400_000);
  const rows = await fetchTefasFunds(code, start, end);
  return rows
    .filter((r) => r.fonKodu === code && Number.isFinite(Number(r.fiyat)))
    .map((r) => ({ t: Math.floor(new Date(r.tarih).getTime() / 1000), c: Number(r.fiyat) }))
    .sort((a, b) => a.t - b.t);
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const url = new URL(req.url);
    // GET (query string) ve POST (JSON gövde) ikisi de çalışsın; iOS SDK POST atıyor.
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const symbol = (body.symbol ?? url.searchParams.get("symbol") ?? "").toString().trim();
    const range = (body.range ?? url.searchParams.get("range") ?? "1a").toString().toLowerCase();

    if (!symbol) return jsonResponse({ status: "error", error: "symbol gerekli" }, 400);
    if (!RANGE_DAYS[range]) return jsonResponse({ status: "error", error: `geçersiz range: ${range}` }, 400);

    const cacheKey = `${symbol}|${range}`;
    const hit = cache.get(cacheKey);
    if (hit && Date.now() - hit.at < TTL_MS) return jsonResponse(hit.body);

    // Sembolün türünü (ve kripto için CoinGecko id'sini) katalogdan okuyoruz;
    // böylece istemci yalnızca sembolü bilmek zorunda.
    const supabase = createServiceClient();
    const { data: rows, error } = await supabase
      .from("assets_prices")
      .select("symbol, currency, name, asset_type")
      .eq("symbol", symbol);
    if (error) throw new Error("DB error: " + error.message);
    if (!rows || rows.length === 0) {
      return jsonResponse({ status: "error", error: `bilinmeyen sembol: ${symbol}` }, 404);
    }

    const row = rows[0];
    let points: Point[];
    let currency: string;

    switch (row.asset_type) {
      case "bist":
        points = await yahooSeries(symbol, range);
        currency = "TRY";
        break;
      case "us_stock":
        // ABD hisseleri kendi para biriminde (USD) çiziliyor: TRY'ye çevirmek
        // için tarihsel USDTRY serisi de gerekirdi, grafiğe değmez.
        points = await yahooSeries(symbol, range);
        currency = "USD";
        break;
      case "crypto":
        points = await coingeckoSeries(row.name ?? symbol.toLowerCase(), range);
        currency = "TRY";
        break;
      case "fund":
        if (RANGE_DAYS[range] > TEFAS_MAX_DAYS) {
          return jsonResponse(
            { status: "unsupported", error: "TEFAS en fazla 30 günlük geçmiş veriyor" },
            422,
          );
        }
        points = await tefasSeries(symbol, range);
        currency = "TRY";
        break;
      default:
        return jsonResponse(
          { status: "unsupported", error: `${row.asset_type} için geçmiş veri kaynağı yok` },
          422,
        );
    }

    const payload = {
      status: "success",
      symbol,
      currency,
      range,
      points,
    };
    cache.set(cacheKey, { at: Date.now(), body: payload });
    return jsonResponse(payload);
  } catch (err) {
    return errorResponse(err);
  }
});
