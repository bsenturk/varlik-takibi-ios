//
//  PortfolioManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import SwiftUI
import SwiftData

class PortfolioManager: ObservableObject {
    static let shared = PortfolioManager()
    
    @Published var currentTotalValue: Double = 0.0
    @Published var totalInvestment: Double = 0.0
    @Published var profitLoss: Double = 0.0
    @Published var profitLossPercentage: Double = 0.0
    
    // Store purchase prices for each asset to calculate cost basis
    var assetPurchasePrices: [UUID: Double] = [:]
    private let userDefaults = UserDefaults.standard
    private let assetPurchasePricesKey = "assetPurchasePrices"
    
    private init() {
        loadStoredValues()
    }
    
    func updatePortfolio(with assets: [Asset]) {
        // If no assets, reset everything
        if assets.isEmpty {
            resetPortfolio()
            return
        }
        
        // Calculate current market value using totalValue computed property
        currentTotalValue = assets.reduce(0) { total, asset in
            let assetValue = asset.totalValue
            return total + assetValue
        }
        
        // Calculate total investment using stored purchase prices
        totalInvestment = assets.reduce(0) { total, asset in
            let purchasePrice = assetPurchasePrices[asset.id] ?? asset.currentPrice
            let investmentValue = purchasePrice * asset.amount
            return total + investmentValue
        }
        
        // Calculate profit/loss based on cost basis vs current value
        calculateProfitLoss()
    }
    
    // Store purchase price when asset is first created
    func storePurchasePrice(for assetId: UUID, price: Double) {
        assetPurchasePrices[assetId] = price
        saveAssetPurchasePrices()
    }
    
    // Update purchase price when asset amount changes (weighted average)
    func updatePurchasePrice(for assetId: UUID, oldAmount: Double, newAmount: Double, newPrice: Double) {
        guard let oldPrice = assetPurchasePrices[assetId] else {
            assetPurchasePrices[assetId] = newPrice
            saveAssetPurchasePrices()
            return
        }
        
        // Calculate weighted average price
        let oldInvestment = oldPrice * oldAmount
        let newInvestment = newPrice * (newAmount - oldAmount)
        let totalInvestment = oldInvestment + newInvestment
        let weightedAveragePrice = totalInvestment / newAmount
        
        assetPurchasePrices[assetId] = weightedAveragePrice
        saveAssetPurchasePrices()
    }
    
    // Remove purchase price when asset is deleted
    func removePurchasePrice(for assetId: UUID) {
        assetPurchasePrices.removeValue(forKey: assetId)
        saveAssetPurchasePrices()
    }
    
    private func calculateProfitLoss() {
        // Hassas kar/zarar hesaplama
        if totalInvestment > 0 {
            profitLoss = currentTotalValue - totalInvestment
            
            // Çok hassas yüzde hesaplama - Double precision kullan
            profitLossPercentage = (profitLoss / totalInvestment) * 100.0
            
            // Çok küçük değerler için özel kontrol
            if abs(profitLossPercentage) < 0.01 && profitLoss != 0 {
            }
            
        } else {
            profitLoss = 0.0
            profitLossPercentage = 0.0
        }
    }
    
    private func saveAssetPurchasePrices() {
        let data = assetPurchasePrices.mapValues { $0 }
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: assetPurchasePricesKey)
            Logger.log("💾 PortfolioManager: Purchase prices saved to UserDefaults")
        } else {
            Logger.log("❌ PortfolioManager: Failed to encode purchase prices")
        }
    }
    
    private func loadStoredValues() {
        if let data = userDefaults.data(forKey: assetPurchasePricesKey),
           let decoded = try? JSONDecoder().decode([UUID: Double].self, from: data) {
            assetPurchasePrices = decoded
            Logger.log("💾 PortfolioManager: Loaded \(assetPurchasePrices.count) purchase prices from UserDefaults")
        } else {
            Logger.log("💾 PortfolioManager: No stored purchase prices found")
        }
    }
    
    func resetPortfolio() {
        currentTotalValue = 0.0
        totalInvestment = 0.0
        profitLoss = 0.0
        profitLossPercentage = 0.0
        assetPurchasePrices.removeAll()
        
        // Clear stored values
        userDefaults.removeObject(forKey: assetPurchasePricesKey)
    }
    
    // Force update method
    func forceUpdate(with assets: [Asset]) {
        DispatchQueue.main.async {
            self.updatePortfolio(with: assets)
        }
    }
    
    // Helper method to get formatted profit/loss percentage
    func getFormattedProfitLossPercentage() -> String {
        let absPercentage = abs(profitLossPercentage)
        
        if absPercentage < 0.01 && profitLoss != 0 {
            return "\(profitLoss >= 0 ? "+" : "")<0,01%"
        } else {
            let sign = profitLoss >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", profitLossPercentage))%"
        }
    }
    
    /// TRY tutarını hedef para birimine çevirir.
    ///
    /// Kur, koda göre aranıyor: yeni bir para birimi eklendiğinde burada
    /// değişiklik gerekmiyor (eskiden her birim için ayrı bir `case` vardı).
    ///
    /// Kaynak bilerek `tryPrice(forSymbol:)`, `currencyRates` değil: ikincisi
    /// ekranda göstermek için üretilmiş bir görünüm modeli ve fiyatı iki
    /// ondalıklı bir *metne* çevirip geri okuyor. Dolarda sapma binde iki
    /// olduğu için fark edilmiyordu; Japon Yeni'nde (0,3144 → 0,31) toplam
    /// %1,4 kayıyordu.
    func convertToTargetCurrency(_ amount: Double, targetCurrency: Currency) -> Double {
        guard targetCurrency != .TRY else { return amount }
        guard let rate = MarketDataManager.shared.tryPrice(forSymbol: targetCurrency.rawValue),
              rate > 0
        else { return amount }
        return amount / rate
    }
}
