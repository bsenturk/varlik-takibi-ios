import { createServiceClient, upsertPrices, type AssetPrice } from "../_shared/prices.ts";
import { fetchYahooQuote, mapWithConcurrency } from "../_shared/yahoo.ts";
import { errorResponse, handlePreflight, jsonResponse } from "../_shared/cors.ts";

// Full Borsa İstanbul equity universe (embedded fallback). Refreshed at runtime
// from bigpara when reachable, so newly listed tickers are picked up
// automatically. Yahoo symbols are these codes + ".IS".
const BIST_FALLBACK: string[] = [
  "A1CAP", "A1YEN", "AAGYO", "ACSEL", "ADEL", "ADESE", "ADGYO", "AEFES",
  "AFYON", "AGESA", "AGHOL", "AGROT", "AGYO", "AHGAZ", "AHSGY", "AKBNK",
  "AKCNS", "AKENR", "AKFGY", "AKFIS", "AKFYE", "AKGRT", "AKHAN", "AKMGY",
  "AKSA", "AKSEN", "AKSGY", "AKSUE", "AKYHO", "ALARK", "ALBRK", "ALCAR",
  "ALCTL", "ALFAS", "ALGYO", "ALKA", "ALKIM", "ALKLC", "ALTNY", "ALVES",
  "ANELE", "ANGEN", "ANHYT", "ANSGR", "APBDL", "APGLD", "APLIB", "APMDL",
  "APX30", "ARASE", "ARCLK", "ARDYZ", "ARENA", "ARFYE", "ARMGD", "ARSAN",
  "ARTMS", "ARZUM", "ASELS", "ASGYO", "ASTOR", "ASUZU", "ATAGY", "ATAKP",
  "ATATP", "ATATR", "ATEKS", "ATLAS", "ATSYH", "AVGYO", "AVHOL", "AVOD",
  "AVPGY", "AVTUR", "AYCES", "AYDEM", "AYEN", "AYES", "AYGAZ", "AZTEK",
  "BAGFS", "BAHKM", "BAKAB", "BALAT", "BALSU", "BANVT", "BARMA", "BASCM",
  "BASGZ", "BAYRK", "BEGYO", "BERA", "BESLR", "BESTE", "BEYAZ", "BFREN",
  "BIENY", "BIGCH", "BIGEN", "BIGTK", "BIMAS", "BINBN", "BINHO", "BIOEN",
  "BIZIM", "BJKAS", "BLCYT", "BLUME", "BMSCH", "BMSTL", "BNTAS", "BOBET",
  "BORLS", "BORSK", "BOSSA", "BRISA", "BRKO", "BRKSN", "BRKVY", "BRLSM",
  "BRMEN", "BRSAN", "BRYAT", "BSOKE", "BTCIM", "BUCIM", "BULGS", "BURCE",
  "BURVA", "BVSAN", "BYDNR", "CANTE", "CATES", "CCOLA", "CELHA", "CEMAS",
  "CEMTS", "CEMZY", "CEOEM", "CGCAM", "CIMSA", "CLEBI", "CMBTN", "CMENT",
  "CONSE", "COSMO", "CRDFA", "CRFSA", "CUSAN", "CVKMD", "CWENE", "DAGI",
  "DAPGM", "DARDL", "DCTTR", "DENGE", "DERHL", "DERIM", "DESA", "DESPC",
  "DEVA", "DGATE", "DGGYO", "DGNMO", "DIRIT", "DITAS", "DMRGD", "DMSAS",
  "DNISI", "DOAS", "DOCO", "DOFER", "DOFRB", "DOGUB", "DOHOL", "DOKTA",
  "DSTKF", "DUNYH", "DURDO", "DURKN", "DYOBY", "DZGYO", "EBEBK", "ECILC",
  "ECOGR", "ECZYT", "EDATA", "EDIP", "EFOR", "EGEEN", "EGEGY", "EGEPO",
  "EGGUB", "EGPRO", "EGSER", "EKDMR", "EKGYO", "EKIZ", "EKOS", "EKSUN",
  "ELITE", "EMKEL", "EMNIS", "EMPAE", "ENDAE", "ENERY", "ENJSA", "ENKAI",
  "ENPRA", "ENRYA", "ENSRI", "ENTRA", "EPLAS", "ERBOS", "ERCB", "EREGL",
  "ERSU", "ESCAR", "ESCOM", "ESEN", "ETILR", "ETYAT", "EUHOL", "EUKYO",
  "EUPWR", "EUREN", "EUYO", "EYGYO", "FADE", "FENER", "FLAP", "FMIZP",
  "FONET", "FORMT", "FORTE", "FRIGO", "FRMPL", "FROTO", "FZLGY", "GARAN",
  "GARFA", "GATEG", "GEDIK", "GEDZA", "GENIL", "GENKM", "GENTS", "GEREL",
  "GESAN", "GIPTA", "GLBMD", "GLCVY", "GLDTR", "GLRMK", "GLRYH", "GLYHO",
  "GMSTR", "GMSTRF", "GMTAS", "GOKNR", "GOLTS", "GOODY", "GOZDE", "GRNYO",
  "GRSEL", "GRTHO", "GSDDE", "GSDHO", "GSRAY", "GUBRF", "GUNDG", "GWIND",
  "GZNMI", "HALKB", "HATEK", "HATSN", "HDFGS", "HEDEF", "HEKTS", "HKTM",
  "HLGYO", "HOROZ", "HRKET", "HTTBT", "HUBVC", "HUNER", "HURGZ", "ICBCT",
  "ICUGS", "IDGYO", "IEYHO", "IHAAS", "IHEVA", "IHGZT", "IHLAS", "IHLGM",
  "IHYAY", "IMASM", "INDES", "INFO", "INGRM", "INTEK", "INTEM", "INVEO",
  "INVES", "ISATR", "ISBIR", "ISBTR", "ISCTR", "ISDMR", "ISFIN", "ISGLK",
  "ISGSY", "ISGYO", "ISKPL", "ISKUR", "ISMEN", "ISSEN", "ISYAT", "IZENR",
  "IZFAS", "IZINV", "IZMDC", "JANTS", "KAPLM", "KAREL", "KARSN", "KARTN",
  "KATMR", "KAYSE", "KBORU", "KCAER", "KCHOL", "KENT", "KERVN", "KFEIN",
  "KGYO", "KIMMR", "KLGYO", "KLKIM", "KLMSN", "KLNMA", "KLRHO", "KLSER",
  "KLSYN", "KLYPV", "KMPUR", "KNFRT", "KOCMT", "KONKA", "KONTR", "KONYA",
  "KOPOL", "KORDS", "KOTON", "KRDMA", "KRDMB", "KRDMD", "KRGYO", "KRONT",
  "KRPLS", "KRSTL", "KRTEK", "KRVGD", "KSTUR", "KTLEV", "KTSKR", "KUTPO",
  "KUVVA", "KUYAS", "KZBGY", "KZGYO", "LIDER", "LIDFA", "LILAK", "LINK",
  "LKMNH", "LMKDC", "LOGO", "LRSHO", "LUKSK", "LXGYO", "LYDHO", "LYDIA",
  "LYDYE", "MAALT", "MACKO", "MAGEN", "MAKIM", "MAKTK", "MANAS", "MARBL",
  "MARKA", "MARMR", "MARTI", "MAVI", "MCARD", "MEDTR", "MEGAP", "MEGMT",
  "MEKAG", "MEPET", "MERCN", "MERIT", "MERKO", "METRO", "MEYSU", "MGROS",
  "MHRGY", "MIATK", "MMCAS", "MNDRS", "MNDTR", "MOBTL", "MOGAN", "MOPAS",
  "MPARK", "MRGYO", "MRSHL", "MSGYO", "MTRKS", "MTRYO", "MZHLD", "NATEN",
  "NETAS", "NETCD", "NIBAS", "NPTLR", "NTGAZ", "NTHOL", "NUGYO", "NUHCM",
  "OBAMS", "OBASE", "ODAS", "ODINE", "OFSYM", "ONCSM", "ONRYT", "OPK30",
  "OPT25", "OPTGY", "OPTLR", "OPX30", "ORCAY", "ORGE", "ORMA", "OSMEN",
  "OSTIM", "OTKAR", "OTTO", "OYAKC", "OYAYO", "OYLUM", "OYYAT", "OZATD",
  "OZGYO", "OZKGY", "OZRDN", "OZSUB", "OZYSR", "PAGYO", "PAHOL", "PAMEL",
  "PAPIL", "PARSN", "PASEU", "PATEK", "PCILT", "PEKGY", "PENGD", "PENTA",
  "PETKM", "PETUN", "PGSUS", "PINSU", "PKART", "PKENT", "PLTUR", "PNLSN",
  "PNSUT", "POLHO", "POLTK", "PRDGS", "PRKAB", "PRKME", "PRZMA", "PSDTC",
  "PSGYO", "QNBFK", "QNBTR", "QTEMZ", "QUAGR", "RALYH", "RAYSG", "REEDR",
  "RGYAS", "RNPOL", "RODRG", "RTALB", "RUBNS", "RUZYE", "RYGYO", "RYSAS",
  "SAFKR", "SAHOL", "SAMAT", "SANEL", "SANFM", "SANKO", "SARKY", "SASA",
  "SAYAS", "SDTTR", "SEGMN", "SEGYO", "SEKFK", "SEKUR", "SELEC", "SELVA",
  "SERNT", "SEYKM", "SILVR", "SISE", "SKBNK", "SKTAS", "SKYLP", "SKYMD",
  "SMART", "SMRTG", "SMRVA", "SNGYO", "SNICA", "SNPAM", "SODSN", "SOKE",
  "SOKM", "SONME", "SRVGY", "SUMAS", "SUNTK", "SURGY", "SUWEN", "SVGYO",
  "TABGD", "TARKM", "TATEN", "TATGD", "TAVHL", "TBORG", "TCELL", "TCKRC",
  "TDGYO", "TEHOL", "TEKTU", "TERA", "TEZOL", "TGSAS", "THYAO", "TKFEN",
  "TKNSA", "TLMAN", "TMPOL", "TMSN", "TNZTP", "TOASO", "TRALT", "TRCAS",
  "TRENJ", "TRGYO", "TRHOL", "TRILC", "TRMET", "TSGYO", "TSKB", "TSPOR",
  "TTKOM", "TTRAK", "TUCLK", "TUKAS", "TUPRS", "TUREX", "TURGG", "TURSG",
  "UCAYM", "UFUK", "ULAS", "ULKER", "ULUFA", "ULUSE", "ULUUN", "UMPAS",
  "UNLU", "USAK", "USDTR", "USDTRF", "VAKBN", "VAKFA", "VAKFN", "VAKKO",
  "VANGD", "VBTYZ", "VERTU", "VERUS", "VESBE", "VESTL", "VKFYO", "VKGYO",
  "VKING", "VRGYO", "VSNMD", "YAPRK", "YATAS", "YAYLA", "YBTAS", "YEOTK",
  "YESIL", "YGGYO", "YIGIT", "YKBNK", "YKSLN", "YONGA", "YUNSA", "YYAPI",
  "YYLGD", "Z30EA", "Z30KE", "Z30KP", "ZEDUR", "ZELOT", "ZERGY", "ZGOLD",
  "ZGOLDF", "ZGYO", "ZOREN", "ZPBDL", "ZPLIB", "ZPT10", "ZPX30", "ZRE20",
  "ZRGYO", "ZSR25", "ZTLRF", "ZTLRK", "ZTM25",
];

// US market — mega-cap & popular names.
const US_SYMBOLS = [
  "AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "META", "TSLA", "NFLX",
  "AMD", "INTC", "TSM", "AVGO",
  "V", "MA", "JPM", "BAC",
  "WMT", "COST", "KO", "PEP", "MCD", "NKE",
  "JNJ", "UNH", "LLY", "PFE", "MRK",
  "F", "GM", "BA", "XOM", "CVX",
  "T", "VZ", "DIS",
];

// US ETFs (Pro). Ayrı `asset_type` ("us_etf") ile yazılıyor ki uygulama
// onları premium bir kategori olarak listeleyebilsin. Hacim/popülerliğe göre
// seçildi: geniş endeks, temettü, sektör, tahvil, emtia, spot bitcoin.
const US_ETFS: Record<string, string> = {
  SPY: "SPDR S&P 500",
  VOO: "Vanguard S&P 500",
  IVV: "iShares Core S&P 500",
  QQQ: "Invesco QQQ (Nasdaq-100)",
  VTI: "Vanguard Total Stock Market",
  VT: "Vanguard Total World Stock",
  DIA: "SPDR Dow Jones",
  IWM: "iShares Russell 2000",
  VEA: "Vanguard Developed Markets",
  VWO: "Vanguard Emerging Markets",
  SCHD: "Schwab US Dividend Equity",
  VYM: "Vanguard High Dividend Yield",
  JEPI: "JPMorgan Equity Premium Income",
  VGT: "Vanguard Information Technology",
  XLK: "Technology Select Sector SPDR",
  XLF: "Financial Select Sector SPDR",
  XLE: "Energy Select Sector SPDR",
  XLV: "Health Care Select Sector SPDR",
  SMH: "VanEck Semiconductor",
  SOXX: "iShares Semiconductor",
  ARKK: "ARK Innovation",
  TLT: "iShares 20+ Year Treasury Bond",
  BND: "Vanguard Total Bond Market",
  AGG: "iShares Core US Aggregate Bond",
  GLD: "SPDR Gold Shares",
  SLV: "iShares Silver Trust",
  IBIT: "iShares Bitcoin Trust",
};

// How many symbols to fetch from Yahoo at once.
const CONCURRENCY = 8;

/** Current BIST equity codes — live from bigpara, falling back to the embedded set. */
async function fetchBistCodes(): Promise<string[]> {
  try {
    const res = await fetch("https://bigpara.hurriyet.com.tr/api/v1/hisse/list", {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
      },
    });
    if (!res.ok) return BIST_FALLBACK;
    const json = await res.json();
    const codes: string[] = (json?.data ?? [])
      .filter((x: { tip?: string; kod?: string }) => x?.tip === "Hisse" && typeof x?.kod === "string")
      .map((x: { kod: string }) => x.kod);
    // Sanity check: only trust a clearly-populated list.
    return codes.length >= 100 ? codes : BIST_FALLBACK;
  } catch {
    return BIST_FALLBACK;
  }
}

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const bistCodes = await fetchBistCodes();
    const bistSymbols = bistCodes.map((c) => `${c}.IS`);
    const etfSymbols = Object.keys(US_ETFS);
    const etfSet = new Set(etfSymbols);
    const allSymbols = [...bistSymbols, ...US_SYMBOLS, ...etfSymbols];

    const settled = await mapWithConcurrency(allSymbols, CONCURRENCY, fetchYahooQuote);

    const rows: AssetPrice[] = [];
    let failed = 0;
    const sampleFailures: string[] = [];
    settled.forEach((result, i) => {
      const symbol = allSymbols[i];
      if (result.status === "rejected" || !result.value) {
        failed++;
        if (sampleFailures.length < 15) sampleFailures.push(symbol);
        return;
      }
      const q = result.value;
      const isBist = symbol.endsWith(".IS");
      const isEtf = etfSet.has(symbol);
      rows.push({
        symbol: q.symbol,
        name: isEtf ? US_ETFS[symbol] : null,
        asset_type: isBist ? "bist" : isEtf ? "us_etf" : "us_stock",
        price: q.price,
        currency: q.currency ?? (isBist ? "TRY" : "USD"),
        change_percent: q.changePercent,
        source: "yahoo-finance",
      });
    });

    const supabase = createServiceClient();
    // ETF'ler ayrı bir upsert'te: yeni bir asset_type'ın reddi (ör. sütunda
    // bir kısıt) tüm toplu yazmayı düşürüp BIST/ABD fiyatlarını dondurmasın.
    const saved = await upsertPrices(supabase, rows.filter((r) => r.asset_type !== "us_etf"));
    let etfSaved = 0;
    let etfError: string | null = null;
    try {
      etfSaved = (await upsertPrices(supabase, rows.filter((r) => r.asset_type === "us_etf"))).length;
    } catch (e) {
      etfError = e instanceof Error ? e.message : String(e);
    }

    const bistSaved = saved.filter((r) => r.asset_type === "bist").length;
    const usSaved = saved.filter((r) => r.asset_type === "us_stock").length;

    // Summary only — full rows are in assets_prices (returning ~600 would be huge).
    return jsonResponse({
      status: "success",
      source: "yahoo-finance",
      bist_requested: bistSymbols.length,
      bist_saved: bistSaved,
      us_saved: usSaved,
      etf_saved: etfSaved,
      etf_error: etfError,
      total_saved: saved.length + etfSaved,
      failed,
      sample_failures: sampleFailures,
    });
  } catch (err) {
    return errorResponse(err);
  }
});
