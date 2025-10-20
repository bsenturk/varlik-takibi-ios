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
        
        let rates = response.rates
        
        currencies.append(AssetsPrice(
            name: "Dolar",
            code: "USD",
            buyPrice: formatPrice(rates.usd.buying),
            sellPrice: formatPrice(rates.usd.selling),
            change: "",
            changePercent: formatChange(rates.usd.change),
            lastUpdate: Date()
        ))
        
        currencies.append(AssetsPrice(
            name: "Euro",
            code: "EUR",
            buyPrice: formatPrice(rates.eur.buying),
            sellPrice: formatPrice(rates.eur.selling),
            change: "",
            changePercent: formatChange(rates.eur.change),
            lastUpdate: Date()
        ))
        
        currencies.append(AssetsPrice(
            name: "Sterlin",
            code: "GBP",
            buyPrice: formatPrice(rates.gbp.buying),
            sellPrice: formatPrice(rates.gbp.selling),
            change: "",
            changePercent: formatChange(rates.gbp.change),
            lastUpdate: Date()
        ))
        
        return currencies
    }
    
    private func mapGoldData(from response: RatesResponse) -> [AssetsPrice] {
        var goldPrices: [AssetsPrice] = []
        
        let rates = response.rates
        
        goldPrices.append(AssetsPrice(
            name: "Gram Altın",
            code: "GRA",
            buyPrice: formatPrice(rates.gra.buying),
            sellPrice: formatPrice(rates.gra.selling),
            change: "",
            changePercent: formatChange(rates.gra.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Çeyrek Altın",
            code: "CEYREK",
            buyPrice: formatPrice(rates.quarterGold.buying),
            sellPrice: formatPrice(rates.quarterGold.selling),
            change: "",
            changePercent: formatChange(rates.quarterGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Yarım Altın",
            code: "YARIM",
            buyPrice: formatPrice(rates.halfGold.buying),
            sellPrice: formatPrice(rates.halfGold.selling),
            change: "",
            changePercent: formatChange(rates.halfGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Tam Altın",
            code: "TAM",
            buyPrice: formatPrice(rates.fullGold.buying),
            sellPrice: formatPrice(rates.fullGold.selling),
            change: "",
            changePercent: formatChange(rates.fullGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Cumhuriyet Altını",
            code: "HAS",
            buyPrice: formatPrice(rates.republicGold.buying),
            sellPrice: formatPrice(rates.republicGold.selling),
            change: "",
            changePercent: formatChange(rates.republicGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Ata Altın",
            code: "ATA",
            buyPrice: formatPrice(rates.ataGold.buying),
            sellPrice: formatPrice(rates.ataGold.selling),
            change: "",
            changePercent: formatChange(rates.ataGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Reşat Altın",
            code: "RESAT",
            buyPrice: formatPrice(rates.resatGold.buying),
            sellPrice: formatPrice(rates.resatGold.selling),
            change: "",
            changePercent: formatChange(rates.resatGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Hamit Altın",
            code: "HAMIT",
            buyPrice: formatPrice(rates.hamitGold.buying),
            sellPrice: formatPrice(rates.hamitGold.selling),
            change: "",
            changePercent: formatChange(rates.hamitGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(AssetsPrice(
            name: "Beşli Altın",
            code: "BESLI",
            buyPrice: formatPrice(rates.fiveRateGold.buying),
            sellPrice: formatPrice(rates.fiveRateGold.selling),
            change: "",
            changePercent: formatChange(rates.fiveRateGold.change),
            lastUpdate: Date()
        ))
        
        goldPrices.append(
            AssetsPrice(
                name: "Gremse Altın",
                code: "GREMSE",
                buyPrice: formatPrice(rates.gremseGold.buying),
                sellPrice: formatPrice(rates.gremseGold.selling),
                change: "",
                changePercent: formatChange(rates.gremseGold.change),
                lastUpdate: Date()
            )
        )
        
        goldPrices.append(
            AssetsPrice(
                name: "14 Ayar Altın",
                code: "14AYAR",
                buyPrice: formatPrice(rates.fourteenRateGold.buying),
                sellPrice: formatPrice(rates.fourteenRateGold.selling),
                change: "",
                changePercent: formatChange(rates.fourteenRateGold.change),
                lastUpdate: Date()
            )
        )
        
        goldPrices.append(
            AssetsPrice(
                name: "18 Ayar Altın",
                code: "18AYAR",
                buyPrice: formatPrice(rates.eighteenRateGold.buying),
                sellPrice: formatPrice(rates.eighteenRateGold.selling),
                change: "",
                changePercent: formatChange(rates.eighteenRateGold.change),
                lastUpdate: Date()
            )
        )
        
        goldPrices.append(
            AssetsPrice(
                name: "İki Buçuk Altın",
                code: "IKIBUCUK",
                buyPrice: formatPrice(rates.twoAndHalfRateGold.buying),
                sellPrice: formatPrice(rates.twoAndHalfRateGold.selling),
                change: "",
                changePercent: formatChange(rates.twoAndHalfRateGold.change),
                lastUpdate: Date()
            )
        )
        
        goldPrices.append(
            AssetsPrice(
                name: "22 Ayar Bilezik",
                code: "22AYARBILEZIK",
                buyPrice: formatPrice(rates.twentyTwoRateBracelet.buying),
                sellPrice: formatPrice(rates.twentyTwoRateBracelet.selling),
                change: "",
                changePercent: formatChange(rates.twentyTwoRateBracelet.change),
                lastUpdate: Date()
            )
        )
        
        goldPrices.append(AssetsPrice(
            name: "Gram Gümüş",
            code: "GUMUS",
            buyPrice: formatPrice(rates.silver.buying),
            sellPrice: formatPrice(rates.silver.selling),
            change: "",
            changePercent: formatChange(rates.silver.change),
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
