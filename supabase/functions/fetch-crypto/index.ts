import { createServiceClient, upsertPrices, type AssetPrice } from "../_shared/prices.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

// CoinGecko id -> display symbol. Add/remove coins here.
//
// `name` kolonu bu id'yi taşıyor ve price-chart / sync-crypto-logos onu
// CoinGecko id'si olarak kullanıyor — görünen ad istemcide türetiliyor.
// id'ler /simple/price ile doğrulandı (yanlış id sessizce düşer). Tablonun
// anahtarı (symbol, currency): yeni bir sembolün mevcut bir fon/hisse koduyla
// çakışmadığını kontrol et, yoksa onun satırını ezer.
const COINS: Record<string, string> = {
  bitcoin: "BTC",
  ethereum: "ETH",
  tether: "USDT",
  binancecoin: "BNB",
  solana: "SOL",
  ripple: "XRP",
  "usd-coin": "USDC",
  dogecoin: "DOGE",
  cardano: "ADA",
  tron: "TRX",
  "avalanche-2": "AVAX",
  "shiba-inu": "SHIB",
  polkadot: "DOT",
  chainlink: "LINK",
  "the-open-network": "TON",
  "bitcoin-cash": "BCH",
  litecoin: "LTC",
  near: "NEAR",
  uniswap: "UNI",
  stellar: "XLM",
  "internet-computer": "ICP",
  aptos: "APT",
  "ethereum-classic": "ETC",
  cosmos: "ATOM",
  pepe: "PEPE",
  sui: "SUI",
  "render-token": "RENDER",
  arbitrum: "ARB",
  optimism: "OP",
  filecoin: "FIL",
  "hedera-hashgraph": "HBAR",
  "injective-protocol": "INJ",
  algorand: "ALGO",
  aave: "AAVE",
  "the-sandbox": "SAND",
  decentraland: "MANA",
  "axie-infinity": "AXS",
  "fetch-ai": "FET",
  bonk: "BONK",
  floki: "FLOKI",
  "polygon-ecosystem-token": "POL",
  hyperliquid: "HYPE",
  mantle: "MNT",
  "ondo-finance": "ONDO",
  "worldcoin-wld": "WLD",
  "jupiter-exchange-solana": "JUP",
  "sei-network": "SEI",
  kaspa: "KAS",
  monero: "XMR",
  vechain: "VET",
  gala: "GALA",
  chiliz: "CHZ",
};

type CoinGeckoPrice = Record<
  string,
  {
    usd?: number;
    try?: number;
    usd_24h_change?: number;
    try_24h_change?: number;
  }
>;

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const ids = Object.keys(COINS).join(",");
    const url =
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids}` +
      `&vs_currencies=usd,try&include_24hr_change=true`;

    const res = await fetch(url, {
      headers: { Accept: "application/json" },
    });
    if (!res.ok) {
      throw new Error(`CoinGecko HTTP ${res.status}: ${await res.text()}`);
    }
    const data = (await res.json()) as CoinGeckoPrice;

    // One row per (symbol, currency): both USD and TRY prices.
    const rows: AssetPrice[] = [];
    for (const [id, symbol] of Object.entries(COINS)) {
      const entry = data[id];
      if (!entry) continue;

      if (typeof entry.usd === "number") {
        rows.push({
          symbol,
          name: id,
          asset_type: "crypto",
          price: entry.usd,
          currency: "USD",
          change_percent: entry.usd_24h_change ?? null,
          source: "coingecko",
        });
      }
      if (typeof entry.try === "number") {
        rows.push({
          symbol,
          name: id,
          asset_type: "crypto",
          price: entry.try,
          currency: "TRY",
          change_percent: entry.try_24h_change ?? null,
          source: "coingecko",
        });
      }
    }

    const supabase = createServiceClient();
    const saved = await upsertPrices(supabase, rows);

    return jsonResponse({
      status: "success",
      source: "coingecko",
      total_saved: saved.length,
      data: saved,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
