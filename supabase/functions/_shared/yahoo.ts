// Yahoo Finance via the public v8 chart endpoint. Yahoo's v7 `quote` endpoint
// now returns 401/429 for unauthenticated/datacenter callers, but the per-symbol
// chart endpoint still serves the latest price without a crumb.

const CHART_BASE = "https://query1.finance.yahoo.com/v8/finance/chart";

const BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Accept": "application/json",
};

export interface YahooQuote {
  symbol: string;
  price: number;
  currency?: string;
  changePercent: number | null;
}

interface ChartMeta {
  symbol?: string;
  currency?: string;
  regularMarketPrice?: number;
  previousClose?: number;
  chartPreviousClose?: number;
}

/** Fetch the latest price for one symbol. Returns null if no usable price. */
export async function fetchYahooQuote(symbol: string): Promise<YahooQuote | null> {
  const url = `${CHART_BASE}/${encodeURIComponent(symbol)}?range=1d&interval=1d`;
  const res = await fetch(url, { headers: BROWSER_HEADERS });
  if (!res.ok) {
    throw new Error(`Yahoo HTTP ${res.status} for ${symbol}`);
  }
  const json = await res.json();
  const meta: ChartMeta | undefined = json?.chart?.result?.[0]?.meta;
  if (!meta || typeof meta.regularMarketPrice !== "number") return null;

  const prev = meta.chartPreviousClose ?? meta.previousClose;
  const changePercent =
    typeof prev === "number" && prev !== 0
      ? ((meta.regularMarketPrice - prev) / prev) * 100
      : null;

  return {
    symbol: meta.symbol ?? symbol,
    price: meta.regularMarketPrice,
    currency: meta.currency,
    changePercent,
  };
}

/**
 * Run an async mapper over items with a bounded concurrency so we don't fire
 * 70 requests at Yahoo simultaneously. Never throws — returns settled results.
 */
export async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  fn: (item: T) => Promise<R>,
): Promise<PromiseSettledResult<R>[]> {
  const results: PromiseSettledResult<R>[] = new Array(items.length);
  let cursor = 0;

  async function worker(): Promise<void> {
    while (cursor < items.length) {
      const idx = cursor++;
      try {
        results[idx] = { status: "fulfilled", value: await fn(items[idx]) };
      } catch (reason) {
        results[idx] = { status: "rejected", reason } as PromiseRejectedResult;
      }
    }
  }

  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    () => worker(),
  );
  await Promise.all(workers);
  return results;
}
