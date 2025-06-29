//
//  MarketDataManager.swift
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
    
    private init() {
        setupBindings()
        startAutoUpdate()
    }
    
    deinit {
        timer?.invalidate()
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
        await parser.fetchAllData()
        await MainActor.run {
            self.lastUpdateTime = Date()
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
