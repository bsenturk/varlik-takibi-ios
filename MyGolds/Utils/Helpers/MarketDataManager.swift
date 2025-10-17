//
//  MarketDataManager.swift - Cancel Protection Fixed
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import Foundation
import SwiftUI
import Combine

class MarketDataManager: ObservableObject {
    static let shared = MarketDataManager()
    
    @Published var goldPrices: [AssetsPrice] = []
    @Published var currencyRates: [AssetsPrice] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    
    private let parser = Parser()
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 60
    private var timer: Timer?
    
    // Cancel protection
    private var currentRefreshTask: Task<Void, Never>?
    
    private init() {
        setupBindings()
        startAutoUpdate()
    }
    
    deinit {
        timer?.invalidate()
        currentRefreshTask?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Parser'dan gelen verileri dinle
        parser.$goldPrices
            .receive(on: DispatchQueue.main)
            .assign(to: \.goldPrices, on: self)
            .store(in: &cancellables)
        
        parser.$currencyRates
            .receive(on: DispatchQueue.main)
            .assign(to: \.currencyRates, on: self)
            .store(in: &cancellables)
        
        parser.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        parser.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func refreshData() async {
        // Cancel önceki task'ı
        currentRefreshTask?.cancel()
        
        // Yeni task başlat
        currentRefreshTask = Task {
            await performRefresh()
        }
        
        await currentRefreshTask?.value
    }
    
    @MainActor
    private func performRefresh() async {
        Logger.log("📊 MarketDataManager: Starting data refresh")
        
        // Cancel check
        guard !Task.isCancelled else {
            Logger.log("📊 MarketDataManager: Refresh cancelled before start")
            return
        }
        
        errorMessage = nil
        
        do {
            // Sequential loading to avoid conflicts
            try await fetchDataSequentially()
            lastUpdateTime = Date()
            Logger.log("📊 MarketDataManager: Refresh completed successfully")
        } catch {
            if !Task.isCancelled {
                errorMessage = "Veri güncellenirken hata oluştu: \(error.localizedDescription)"
                Logger.log("📊 MarketDataManager: Refresh error - \(error.localizedDescription)")
            } else {
                Logger.log("📊 MarketDataManager: Refresh was cancelled")
            }
        }
    }
    
    private func fetchDataSequentially() async throws {
        // Cancel check
        guard !Task.isCancelled else { return }
        
        // Önce döviz kurlarını çek
        Logger.log("📊 MarketDataManager: Fetching currency rates")
        let currencies = await parser.fetchCurrencyRates()
        
        // Cancel check
        guard !Task.isCancelled else { return }
        
        // Sonra altın fiyatlarını çek
        Logger.log("📊 MarketDataManager: Fetching gold prices")
        let gold = await parser.fetchGoldPrices()
        
        // Cancel check
        guard !Task.isCancelled else { return }
        
        // Update on main thread
        await MainActor.run {
            self.currencyRates = currencies
            self.goldPrices = gold
        }
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
    
    // MARK: - Helper Methods
    
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

// MARK: - Global Access Extension

extension MarketDataManager {
    // Static methods for easy access
    static var goldPrices: [AssetsPrice] {
        return shared.goldPrices
    }
    
    static var currencyRates: [AssetsPrice] {
        return shared.currencyRates
    }
    
    static var isLoading: Bool {
        return shared.isLoading
    }
    
    static var lastUpdateTime: Date? {
        return shared.lastUpdateTime
    }
    
    static func refreshData() async {
        await shared.refreshData()
    }
    
    static func getGoldPrice(by name: String) -> AssetsPrice? {
        return shared.getGoldPrice(by: name)
    }
    
    static func getCurrencyRate(by code: String) -> AssetsPrice? {
        return shared.getCurrencyRate(by: code)
    }
}
