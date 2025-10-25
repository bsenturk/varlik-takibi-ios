//
//  MarketDataManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import Foundation
import SwiftUI
import Combine

final class MarketDataManager: ObservableObject {
    static let shared = MarketDataManager()
    
    @Published var goldPrices: [AssetsPrice] = []
    @Published var currencyRates: [AssetsPrice] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    
    private let repository: RatesRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60
    private var timer: Timer?
    private var currentRefreshTask: Task<Void, Never>?
    
    private init() {
        self.repository = RatesRepository(client: APIClient())
        startAutoUpdate()
    }
    
    // For dependency injection in tests or different configurations
    init(repository: RatesRepositoryProtocol) {
        self.repository = repository
        startAutoUpdate()
    }
    
    deinit {
        timer?.invalidate()
        currentRefreshTask?.cancel()
    }
    
    func refreshData() async {
        currentRefreshTask?.cancel()
        
        currentRefreshTask = Task {
            await performRefresh()
        }
        
        await currentRefreshTask?.value
    }
    
    @MainActor
    private func performRefresh() async {
        guard !Task.isCancelled else {
            return
        }
        
        errorMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            let response = try await repository.today(with: RatesRequest.today)
            
            guard !Task.isCancelled else {
                return
            }
            
            let currencies = mapCurrencyData(from: response)
            let gold = mapGoldData(from: response)
            
            guard !Task.isCancelled else {
                Logger.log("📊 MarketDataManager: Refresh cancelled after mapping")
                return
            }
            
            self.currencyRates = currencies
            self.goldPrices = gold
            self.lastUpdateTime = Date()
            
        } catch {
            if !Task.isCancelled {
                errorMessage = "Veriler alınırken hata oluştu: \(error.localizedDescription)"
            }
        }
    }
    
    private func mapCurrencyData(from response: RatesResponse) -> [AssetsPrice] {
        var currencies: [AssetsPrice] = []

        currencies.append(AssetsPrice(
            name: "Dolar",
            code: "USD",
            buyPrice: formatPrice(response.usd.buyingValue),
            sellPrice: formatPrice(response.usd.sellingValue),
            change: "",
            changePercent: formatChange(response.usd.changeValue),
            lastUpdate: Date()
        ))

        currencies.append(AssetsPrice(
            name: "Euro",
            code: "EUR",
            buyPrice: formatPrice(response.eur.buyingValue),
            sellPrice: formatPrice(response.eur.sellingValue),
            change: "",
            changePercent: formatChange(response.eur.changeValue),
            lastUpdate: Date()
        ))

        currencies.append(AssetsPrice(
            name: "Sterlin",
            code: "GBP",
            buyPrice: formatPrice(response.gbp.buyingValue),
            sellPrice: formatPrice(response.gbp.sellingValue),
            change: "",
            changePercent: formatChange(response.gbp.changeValue),
            lastUpdate: Date()
        ))

        return currencies
    }
    
    private func mapGoldData(from response: RatesResponse) -> [AssetsPrice] {
        var goldPrices: [AssetsPrice] = []

        goldPrices.append(AssetsPrice(
            name: "Gram Altın",
            code: "GRA",
            buyPrice: formatPrice(response.gra.buyingValue),
            sellPrice: formatPrice(response.gra.sellingValue),
            change: "",
            changePercent: formatChange(response.gra.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Çeyrek Altın",
            code: "CEYREK",
            buyPrice: formatPrice(response.quarterGold.buyingValue),
            sellPrice: formatPrice(response.quarterGold.sellingValue),
            change: "",
            changePercent: formatChange(response.quarterGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Yarım Altın",
            code: "YARIM",
            buyPrice: formatPrice(response.halfGold.buyingValue),
            sellPrice: formatPrice(response.halfGold.sellingValue),
            change: "",
            changePercent: formatChange(response.halfGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Tam Altın",
            code: "TAM",
            buyPrice: formatPrice(response.fullGold.buyingValue),
            sellPrice: formatPrice(response.fullGold.sellingValue),
            change: "",
            changePercent: formatChange(response.fullGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Cumhuriyet Altını",
            code: "HAS",
            buyPrice: formatPrice(response.republicGold.buyingValue),
            sellPrice: formatPrice(response.republicGold.sellingValue),
            change: "",
            changePercent: formatChange(response.republicGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Ata Altın",
            code: "ATA",
            buyPrice: formatPrice(response.ataGold.buyingValue),
            sellPrice: formatPrice(response.ataGold.sellingValue),
            change: "",
            changePercent: formatChange(response.ataGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Reşat Altın",
            code: "RESAT",
            buyPrice: formatPrice(response.resatGold.buyingValue),
            sellPrice: formatPrice(response.resatGold.sellingValue),
            change: "",
            changePercent: formatChange(response.resatGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Hamit Altın",
            code: "HAMIT",
            buyPrice: formatPrice(response.hamitGold.buyingValue),
            sellPrice: formatPrice(response.hamitGold.sellingValue),
            change: "",
            changePercent: formatChange(response.hamitGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(AssetsPrice(
            name: "Beşli Altın",
            code: "BESLI",
            buyPrice: formatPrice(response.fiveRateGold.buyingValue),
            sellPrice: formatPrice(response.fiveRateGold.sellingValue),
            change: "",
            changePercent: formatChange(response.fiveRateGold.changeValue),
            lastUpdate: Date()
        ))

        goldPrices.append(
            AssetsPrice(
                name: "Gremse Altın",
                code: "GREMSE",
                buyPrice: formatPrice(response.gremseGold.buyingValue),
                sellPrice: formatPrice(response.gremseGold.sellingValue),
                change: "",
                changePercent: formatChange(response.gremseGold.changeValue),
                lastUpdate: Date()
            )
        )

        goldPrices.append(
            AssetsPrice(
                name: "14 Ayar Altın",
                code: "14AYAR",
                buyPrice: formatPrice(response.fourteenRateGold.buyingValue),
                sellPrice: formatPrice(response.fourteenRateGold.sellingValue),
                change: "",
                changePercent: formatChange(response.fourteenRateGold.changeValue),
                lastUpdate: Date()
            )
        )

        goldPrices.append(
            AssetsPrice(
                name: "18 Ayar Altın",
                code: "18AYAR",
                buyPrice: formatPrice(response.eighteenRateGold.buyingValue),
                sellPrice: formatPrice(response.eighteenRateGold.sellingValue),
                change: "",
                changePercent: formatChange(response.eighteenRateGold.changeValue),
                lastUpdate: Date()
            )
        )

        goldPrices.append(
            AssetsPrice(
                name: "İki Buçuk Altın",
                code: "IKIBUCUK",
                buyPrice: formatPrice(response.twoAndHalfRateGold.buyingValue),
                sellPrice: formatPrice(response.twoAndHalfRateGold.sellingValue),
                change: "",
                changePercent: formatChange(response.twoAndHalfRateGold.changeValue),
                lastUpdate: Date()
            )
        )

        goldPrices.append(
            AssetsPrice(
                name: "22 Ayar Bilezik",
                code: "22AYARBILEZIK",
                buyPrice: formatPrice(response.twentyTwoRateBracelet.buyingValue),
                sellPrice: formatPrice(response.twentyTwoRateBracelet.sellingValue),
                change: "",
                changePercent: formatChange(response.twentyTwoRateBracelet.changeValue),
                lastUpdate: Date()
            )
        )

        goldPrices.append(AssetsPrice(
            name: "Gram Gümüş",
            code: "GUMUS",
            buyPrice: formatPrice(response.silver.buyingValue),
            sellPrice: formatPrice(response.silver.sellingValue),
            change: "",
            changePercent: formatChange(response.silver.changeValue),
            lastUpdate: Date()
        ))

        return goldPrices
    }
    
    // Helper functions
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: price)) ?? "0,00"
    }
    
    private func formatChange(_ change: Double) -> String {
        return String(change)
    }
    
    func startAutoUpdate() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task {
                await self.refreshData()
            }
        }
    }
    
    func stopAutoUpdate() {
        timer?.invalidate()
        timer = nil
        currentRefreshTask?.cancel()
    }
    
    func getGoldPrice(by name: String) -> AssetsPrice? {
        return goldPrices.first { $0.name.lowercased().contains(name.lowercased()) }
    }
    
    func getCurrencyRate(by code: String) -> AssetsPrice? {
        return currencyRates.first { $0.code?.uppercased() == code.uppercased() }
    }
    
    func getAllGoldPrices() -> [AssetsPrice] {
        return goldPrices
    }
    
    func getAllCurrencyRates() -> [AssetsPrice] {
        return currencyRates
    }
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
