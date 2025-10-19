//
//  AssetHistoryManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 19.10.2025.
//

import SwiftData
import Foundation

class AssetHistoryManager {
    static let shared = AssetHistoryManager()
    
    private init() {}
    
    // MARK: - Snapshot Oluştur/Güncelle
    
    /// Kullanıcının tüm varlıkları için bugünün snapshot'ını oluştur/güncelle
    func createOrUpdateDailySnapshots(assets: [Asset], modelContext: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        
        Logger.log("📸 AssetHistoryManager: Creating/updating snapshots for \(assets.count) assets")
        
        for asset in assets {
            // Bugün için bu varlık türünde snapshot var mı?
            let assetType = asset.type
            let descriptor = FetchDescriptor<AssetPriceHistory>(
                predicate: #Predicate<AssetPriceHistory> { history in
                    history.date == today
                }
            )
            
            // Filtre manuel olarak yap
            let todayHistories = (try? modelContext.fetch(descriptor)) ?? []
            let existingHistory = todayHistories.first { $0.assetType == assetType }
            
            if let existingHistory = existingHistory {
                // Güncelle
                existingHistory.price = asset.currentPrice
                existingHistory.amount = asset.amount
                existingHistory.totalValue = asset.currentPrice * asset.amount
                existingHistory.createdAt = Date()
                
                Logger.log("📸 Updated snapshot for \(asset.name): ₺\(asset.currentPrice)")
            } else {
                // Yeni oluştur
                let history = AssetPriceHistory(
                    assetType: asset.type,
                    date: today,
                    price: asset.currentPrice,
                    amount: asset.amount
                )
                modelContext.insert(history)
                
                Logger.log("📸 Created new snapshot for \(asset.name): ₺\(asset.currentPrice)")
            }
        }
        
        do {
            try modelContext.save()
            Logger.log("✅ AssetHistoryManager: All snapshots saved successfully")
        } catch {
            Logger.log("❌ AssetHistoryManager: Failed to save snapshots - \(error)")
        }
    }
    
    // MARK: - Geçmiş Veriye Erişim
    
    /// Belirli bir varlık türü için tüm geçmiş kayıtları getir
    func getHistory(for assetType: AssetType, modelContext: ModelContext) -> [AssetPriceHistory] {
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let allHistory = (try? modelContext.fetch(descriptor)) ?? []
        return allHistory.filter { $0.assetType == assetType }
    }
    
    /// Belirli bir tarih aralığı için kayıtları getir
    func getHistory(
        for assetType: AssetType,
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext
    ) -> [AssetPriceHistory] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.date >= start && history.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let allHistory = (try? modelContext.fetch(descriptor)) ?? []
        return allHistory.filter { $0.assetType == assetType }
    }
    
    // MARK: - Değişim Hesaplamaları
    
    /// Günlük değişim hesapla
    func getDailyChange(for assetType: AssetType, modelContext: ModelContext) -> PriceChangeData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        return calculateChange(
            for: assetType,
            currentDate: today,
            previousDate: yesterday,
            period: .daily,
            modelContext: modelContext
        )
    }
    
    /// Haftalık değişim hesapla
    func getWeeklyChange(for assetType: AssetType, modelContext: ModelContext) -> PriceChangeData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        
        return calculateChange(
            for: assetType,
            currentDate: today,
            previousDate: lastWeek,
            period: .weekly,
            modelContext: modelContext
        )
    }
    
    /// Aylık değişim hesapla
    func getMonthlyChange(for assetType: AssetType, modelContext: ModelContext) -> PriceChangeData? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
        
        return calculateChange(
            for: assetType,
            currentDate: today,
            previousDate: lastMonth,
            period: .monthly,
            modelContext: modelContext
        )
    }
    
    private func calculateChange(
        for assetType: AssetType,
        currentDate: Date,
        previousDate: Date,
        period: PriceChangeData.Period,
        modelContext: ModelContext
    ) -> PriceChangeData? {
        let currentSnapshot = getSnapshot(for: assetType, date: currentDate, context: modelContext)
        let previousSnapshot = getSnapshot(for: assetType, date: previousDate, context: modelContext)
        
        guard let current = currentSnapshot, let previous = previousSnapshot else {
            Logger.log("⚠️ Cannot calculate \(period.displayName) change: Missing snapshot")
            return nil
        }
        
        let change = current.totalValue - previous.totalValue
        let changePercentage = previous.totalValue > 0
            ? (change / previous.totalValue) * 100
            : 0
        
        Logger.log("📊 \(period.displayName) change for \(assetType.displayName): \(change) (\(changePercentage)%)")
        
        return PriceChangeData(
            currentValue: current.totalValue,
            previousValue: previous.totalValue,
            change: change,
            changePercentage: changePercentage,
            period: period
        )
    }
    
    private func getSnapshot(for assetType: AssetType, date: Date, context: ModelContext) -> AssetPriceHistory? {
        let targetDate = Calendar.current.startOfDay(for: date)
        
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.date == targetDate
            }
        )
        
        let histories = (try? context.fetch(descriptor)) ?? []
        return histories.first { $0.assetType == assetType }
    }
    
    // MARK: - Grafik Verisi
    
    /// Son N günün verilerini getir (grafik için)
    func getChartData(
        for assetType: AssetType,
        days: Int,
        modelContext: ModelContext
    ) -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: today)!
        
        let history = getHistory(
            for: assetType,
            from: startDate,
            to: today,
            modelContext: modelContext
        )
        
        return history.map { ($0.date, $0.totalValue) }
    }
    
    // MARK: - Temizlik
    
    /// Eski kayıtları temizle (örneğin 1 yıldan eski)
    func cleanupOldHistory(olderThan days: Int = 365, modelContext: ModelContext) {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { $0.date < cutoffDate }
        )
        
        if let oldRecords = try? modelContext.fetch(descriptor) {
            Logger.log("🗑️ Cleaning up \(oldRecords.count) old history records")
            oldRecords.forEach { modelContext.delete($0) }
            try? modelContext.save()
        }
    }
}
