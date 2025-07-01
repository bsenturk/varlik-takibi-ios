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
    private var assetPurchasePrices: [UUID: Double] = [:]
    private let userDefaults = UserDefaults.standard
    private let assetPurchasePricesKey = "assetPurchasePrices"
    
    private init() {
        loadStoredValues()
    }
    
    func updatePortfolio(with assets: [Asset]) {
        Logger.log("📊 PortfolioManager: Starting portfolio update with \(assets.count) assets")
        
        // If no assets, reset everything
        if assets.isEmpty {
            Logger.log("📊 PortfolioManager: No assets found, resetting portfolio")
            resetPortfolio()
            return
        }
        
        // Calculate current market value using totalValue computed property
        currentTotalValue = assets.reduce(0) { total, asset in
            let assetValue = asset.totalValue
            Logger.log("📊 PortfolioManager: Adding asset \(asset.name) with value \(assetValue)")
            return total + assetValue
        }
        
        Logger.log("📊 PortfolioManager: Total portfolio value calculated: \(currentTotalValue)")
        
        // Calculate total investment using stored purchase prices
        totalInvestment = assets.reduce(0) { total, asset in
            let purchasePrice = assetPurchasePrices[asset.id] ?? asset.currentPrice
            let investmentValue = purchasePrice * asset.amount
            Logger.log("📊 PortfolioManager: Asset \(asset.name) investment: purchase_price=\(purchasePrice), amount=\(asset.amount), investment=\(investmentValue)")
            return total + investmentValue
        }
        
        Logger.log("📊 PortfolioManager: Total investment calculated: \(totalInvestment)")
        
        // Calculate profit/loss based on cost basis vs current value
        calculateProfitLoss()
        
        Logger.log("📊 PortfolioManager: Portfolio update completed")
        Logger.log("📊 PortfolioManager: Current Value: \(currentTotalValue)")
        Logger.log("📊 PortfolioManager: Total Investment: \(totalInvestment)")
        Logger.log("📊 PortfolioManager: Profit/Loss: \(profitLoss)")
        Logger.log("📊 PortfolioManager: Profit/Loss %: \(profitLossPercentage)")
    }
    
    // Store purchase price when asset is first created
    func storePurchasePrice(for assetId: UUID, price: Double) {
        Logger.log("💰 PortfolioManager: Storing purchase price \(price) for asset \(assetId)")
        assetPurchasePrices[assetId] = price
        saveAssetPurchasePrices()
    }
    
    // Update purchase price when asset amount changes (weighted average)
    func updatePurchasePrice(for assetId: UUID, oldAmount: Double, newAmount: Double, newPrice: Double) {
        guard let oldPrice = assetPurchasePrices[assetId] else {
            Logger.log("💰 PortfolioManager: No old price found, using current price \(newPrice)")
            assetPurchasePrices[assetId] = newPrice
            saveAssetPurchasePrices()
            return
        }
        
        // Calculate weighted average price
        let oldInvestment = oldPrice * oldAmount
        let newInvestment = newPrice * (newAmount - oldAmount)
        let totalInvestment = oldInvestment + newInvestment
        let weightedAveragePrice = totalInvestment / newAmount
        
        Logger.log("💰 PortfolioManager: Calculating weighted average:")
        Logger.log("💰 PortfolioManager: Old: price=\(oldPrice), amount=\(oldAmount), investment=\(oldInvestment)")
        Logger.log("💰 PortfolioManager: New: price=\(newPrice), additional_amount=\(newAmount - oldAmount), investment=\(newInvestment)")
        Logger.log("💰 PortfolioManager: Weighted average price: \(weightedAveragePrice)")
        
        assetPurchasePrices[assetId] = weightedAveragePrice
        saveAssetPurchasePrices()
    }
    
    // Remove purchase price when asset is deleted
    func removePurchasePrice(for assetId: UUID) {
        Logger.log("💰 PortfolioManager: Removing purchase price for asset \(assetId)")
        assetPurchasePrices.removeValue(forKey: assetId)
        saveAssetPurchasePrices()
    }
    
    private func calculateProfitLoss() {
        // Hassas kar/zarar hesaplama
        if totalInvestment > 0 {
            profitLoss = currentTotalValue - totalInvestment
            
            // Çok hassas yüzde hesaplama - Double precision kullan
            profitLossPercentage = (profitLoss / totalInvestment) * 100.0
            
            Logger.log("💹 PortfolioManager: Detailed Profit/Loss calculation:")
            Logger.log("💹 PortfolioManager: Current Value: \(currentTotalValue)")
            Logger.log("💹 PortfolioManager: Total Investment: \(totalInvestment)")
            Logger.log("💹 PortfolioManager: Profit/Loss Amount: \(profitLoss)")
            Logger.log("💹 PortfolioManager: Profit/Loss Percentage (exact): \(profitLossPercentage)")
            Logger.log("💹 PortfolioManager: Abs Percentage: \(abs(profitLossPercentage))")
            
            // Çok küçük değerler için özel kontrol
            if abs(profitLossPercentage) < 0.01 && profitLoss != 0 {
                Logger.log("💹 PortfolioManager: Very small percentage detected: \(profitLossPercentage)% should show as <0,01%")
            }
            
        } else {
            profitLoss = 0.0
            profitLossPercentage = 0.0
            Logger.log("💹 PortfolioManager: No investment found, setting profit/loss to zero")
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
        Logger.log("🔄 PortfolioManager: Resetting portfolio")
        currentTotalValue = 0.0
        totalInvestment = 0.0
        profitLoss = 0.0
        profitLossPercentage = 0.0
        assetPurchasePrices.removeAll()
        
        // Clear stored values
        userDefaults.removeObject(forKey: assetPurchasePricesKey)
        Logger.log("🔄 PortfolioManager: Portfolio reset completed")
    }
    
    // Force update method
    func forceUpdate(with assets: [Asset]) {
        Logger.log("🔄 PortfolioManager: Force update requested")
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
    
    // Debug method
    func debugPortfolioInfo() {
        Logger.log("🐛 PortfolioManager Debug Info:")
        Logger.log("🐛 Current Total Value: \(currentTotalValue)")
        Logger.log("🐛 Total Investment: \(totalInvestment)")
        Logger.log("🐛 Profit/Loss: \(profitLoss)")
        Logger.log("🐛 Profit/Loss %: \(profitLossPercentage)")
        Logger.log("🐛 Formatted Profit/Loss %: \(getFormattedProfitLossPercentage())")
        Logger.log("🐛 Stored Purchase Prices: \(assetPurchasePrices)")
    }
}
