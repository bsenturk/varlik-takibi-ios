//
//  MarketDataManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
//  Live market prices come exclusively from the Supabase backend
//  (`assets_prices`, populated by Edge Functions). Exposes gold/FX as before
//  plus crypto / BIST / US stock instruments, and a TRY-price lookup used for
//  portfolio valuation (USD-priced instruments are converted via the USD rate).
//

import Foundation
import SwiftUI
import Combine

final class MarketDataManager: ObservableObject {
    static let shared = MarketDataManager()

    /// Raw rows from `assets_prices` (all asset types & currencies).
    @Published var allPrices: [AssetPrice] = []

    @Published var goldPrices: [AssetsPrice] = []
    @Published var currencyRates: [AssetsPrice] = []
    @Published var cryptoPrices: [AssetsPrice] = []
    @Published var bistPrices: [AssetsPrice] = []
    @Published var usPrices: [AssetsPrice] = []
    @Published var fundPrices: [AssetsPrice] = []   // TEFAS funds (premium)

    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?

    private let marketData: MarketDataServiceProtocol
    private let updateInterval: TimeInterval = 60
    private var timer: Timer?
    private var currentRefreshTask: Task<Void, Never>?

    /// Currency symbols surfaced in the FX rates list — uygulamanın desteklediği
    /// tüm dövizler (TRY hariç; 1 TRY = 1 TRY satırının kur listesinde işi yok).
    private static let displayedCurrencies: Set<String> =
        Set(AssetType.fx.values.map(\.symbol)).subtracting(["TRY"])

    private init() {
        self.marketData = MarketDataService()
        startAutoUpdate()
    }

    init(marketData: MarketDataServiceProtocol) {
        self.marketData = marketData
        startAutoUpdate()
    }

    deinit {
        timer?.invalidate()
        currentRefreshTask?.cancel()
    }

    func refreshData() async {
        currentRefreshTask?.cancel()
        currentRefreshTask = Task { await performRefresh() }
        await currentRefreshTask?.value
    }

    @MainActor
    private func performRefresh() async {
        guard !Task.isCancelled else { return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let prices = try await marketData.fetchLivePrices()
            guard !Task.isCancelled else { return }

            self.allPrices = prices

            self.goldPrices = prices
                .filter { $0.assetType == "gold" && $0.currency == "TRY" }
                .map(Self.makeAssetsPrice)

            self.currencyRates = prices
                .filter { $0.assetType == "currency" && Self.displayedCurrencies.contains($0.symbol) }
                .map(Self.makeAssetsPrice)

            // Dynamic market instruments, priced in TRY for a consistent portfolio.
            self.cryptoPrices = makeTRYInstruments(assetType: "crypto")
            self.bistPrices = makeTRYInstruments(assetType: "bist")
            self.usPrices = makeTRYInstruments(assetType: "us_stock")
            self.fundPrices = makeTRYInstruments(assetType: "fund")

            self.lastUpdateTime = Date()

        } catch {
            if !Task.isCancelled {
                errorMessage = "Veriler alınırken hata oluştu: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - TRY pricing

    /// 1 USD in TRY, from the live USD currency row.
    private var usdToTry: Double? {
        allPrices.first { $0.symbol == "USD" && $0.currency == "TRY" }?.price
    }

    /// Latest price of `symbol` expressed in TRY. Prefers a native TRY row;
    /// otherwise converts a USD row via the live USD rate. Used for valuation.
    func tryPrice(forSymbol symbol: String) -> Double? {
        let rows = allPrices.filter { $0.symbol == symbol }
        guard !rows.isEmpty else { return nil }
        if let tryRow = rows.first(where: { $0.currency == "TRY" }) {
            return tryRow.price
        }
        if let usdRow = rows.first(where: { $0.currency == "USD" }), let rate = usdToTry {
            return usdRow.price * rate
        }
        return rows.first?.price
    }

    /// `symbol`ün TRY cinsinden günlük değişimi (%), backend'in `change_percent`
    /// alanından. Yerel geçmişten hesaplamaya göre üstünlüğü: kullanıcı
    /// uygulamayı günlerce açmasa da doğru kalır (yerel anlık görüntüler yalnızca
    /// uygulama açıkken yazılıyor, taban bayatlıyordu).
    ///
    /// Backend'in TRY değişimi olmayan enstrümanlarda `nil` döner — çağıran taraf
    /// yerel geçmişe düşer. Bugün itibarıyla tek böyle sınıf TEFAS fonları
    /// (`change_percent` 172 satırın hepsinde boş).
    func dayChangePercent(forSymbol symbol: String) -> Double? {
        let rows = allPrices.filter { $0.symbol == symbol }

        // Altın, döviz, BIST ve kripto: backend TRY satırını zaten yayınlıyor.
        if let tryChange = rows.first(where: { $0.currency == "TRY" })?.changePercent {
            return tryChange
        }

        // Yalnızca USD satırı olanlar (ABD hisseleri): TRY karşılığı hem
        // enstrümanın hem kurun hareketini taşır, ikisi bileşiktir. Backend
        // kriptonun TRY satırını da aynı şekilde üretiyor; burada onu ABD
        // hisseleri için elde hesaplıyoruz ki sıralama tek bir para biriminde
        // (TRY) kalsın — USD değişimini TRY değişimiyle yan yana sıralamak
        // yanlış bir tablo verirdi.
        guard let usdChange = rows.first(where: { $0.currency == "USD" })?.changePercent,
              let fxChange = allPrices.first(where: { $0.symbol == "USD" && $0.currency == "TRY" })?.changePercent
        else { return nil }
        return ((1 + usdChange / 100) * (1 + fxChange / 100) - 1) * 100
    }

    /// Enstrümanın kendi logosu. Fiyattaki gibi TRY/USD satırı ayrımı yok:
    /// aynı sembolün bütün satırları aynı logoyu taşıyor.
    ///
    /// nil dönmesi normaldir (altın, döviz, fon ve logosu bulunamayan hisseler);
    /// çağıran taraf mevcut kategori ikonunda kalır.
    func logoURL(forSymbol symbol: String) -> URL? {
        guard let raw = allPrices.first(where: { $0.symbol == symbol && $0.logoUrl != nil })?.logoUrl
        else { return nil }
        return URL(string: raw)
    }

    /// Build display instruments (TRY-priced) for a backend asset_type, deduped by symbol.
    private func makeTRYInstruments(assetType: String) -> [AssetsPrice] {
        let rows = allPrices.filter { $0.assetType == assetType }
        let bySymbol = Dictionary(grouping: rows, by: { $0.symbol })
        return bySymbol.compactMap { (symbol, group) -> AssetsPrice? in
            guard let tryValue = tryPrice(forSymbol: symbol) else { return nil }
            let name = Self.displayName(symbol: symbol, rawName: group.first?.name, assetType: assetType)
            let change = (group.first { $0.currency == "TRY" } ?? group.first)?.changePercent
            let priceString = Self.formatPrice(tryValue)
            return AssetsPrice(
                name: name,
                code: symbol,
                buyPrice: priceString,
                sellPrice: priceString,
                change: "",
                changePercent: change.map { String($0) } ?? "",
                lastUpdate: Date()
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Human-friendly instrument name: strip the ".IS" suffix for BIST symbols,
    /// capitalize the CoinGecko id for crypto, and use the symbol for US stocks.
    private static func displayName(symbol: String, rawName: String?, assetType: String) -> String {
        switch assetType {
        case "bist":
            return symbol.replacingOccurrences(of: ".IS", with: "")
        case "us_stock":
            return symbol
        case "crypto":
            if let raw = rawName, !raw.isEmpty { return raw.capitalized }
            return symbol
        default:
            return rawName ?? symbol
        }
    }

    /// Live display instruments for a dynamic category (used by the add-asset catalog).
    func instruments(for category: AssetCategory) -> [AssetsPrice] {
        switch category {
        case .crypto: return cryptoPrices
        case .bistStock: return bistPrices
        case .usStock: return usPrices
        case .fund: return fundPrices
        default: return []
        }
    }

    /// Searches TEFAS for funds matching `query` via the backend, merges any
    /// matches into the live price set, and refreshes `fundPrices` so the search
    /// list updates. Returns the number of newly-discovered funds. The backend
    /// also upserts the funds into `assets_prices`, so they survive the next
    /// auto-refresh. Failures are swallowed (returns 0) — the local list still works.
    @MainActor
    @discardableResult
    func searchRemoteFunds(query: String) async -> Int {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return 0 }
        do {
            let results = try await marketData.searchFunds(query: trimmed)
            guard !Task.isCancelled, !results.isEmpty else { return 0 }

            // Merge into allPrices, keyed by (symbol, currency); newest wins.
            var merged = Dictionary(
                allPrices.map { ("\($0.symbol)_\($0.currency)", $0) },
                uniquingKeysWith: { _, last in last }
            )
            var added = 0
            for row in results {
                let key = "\(row.symbol)_\(row.currency)"
                if merged[key] == nil { added += 1 }
                merged[key] = row
            }
            self.allPrices = Array(merged.values)
            self.fundPrices = makeTRYInstruments(assetType: "fund")
            return added
        } catch {
            return 0
        }
    }

    // MARK: - Mapping

    private static func makeAssetsPrice(_ p: AssetPrice) -> AssetsPrice {
        let priceString = formatPrice(p.price)
        return AssetsPrice(
            name: p.name ?? p.symbol,
            code: p.symbol,
            buyPrice: priceString,
            sellPrice: priceString,
            change: "",
            changePercent: p.changePercent.map { String($0) } ?? "",
            lastUpdate: p.updatedAt
        )
    }

    private static func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: price)) ?? "0,00"
    }

    // MARK: - Auto update

    func startAutoUpdate() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { await self.refreshData() }
        }
    }

    func stopAutoUpdate() {
        timer?.invalidate()
        timer = nil
        currentRefreshTask?.cancel()
    }

    // MARK: - Lookups

    func getGoldPrice(by name: String) -> AssetsPrice? {
        goldPrices.first { $0.name.lowercased().contains(name.lowercased()) }
    }

    func getCurrencyRate(by code: String) -> AssetsPrice? {
        currencyRates.first { $0.code?.uppercased() == code.uppercased() }
    }

    func getAllGoldPrices() -> [AssetsPrice] { goldPrices }
    func getAllCurrencyRates() -> [AssetsPrice] { currencyRates }
}

// MARK: - Environment Key
struct MarketDataManagerKey: EnvironmentKey {
    static let defaultValue = MarketDataManager.shared
}

extension EnvironmentValues {
    var marketDataManager: MarketDataManager {
        get { self[MarketDataManagerKey.self] }
        set { self[MarketDataManagerKey.self] = newValue }
    }
}
