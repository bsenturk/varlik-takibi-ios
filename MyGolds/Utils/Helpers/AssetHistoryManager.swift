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
    
    private let maxHistoryCount = 30
    private let maxTransactionHistoryCount = 10
    
    private init() {}
    
    // MARK: - Daily Snapshot Management
    
    /// Her asset için günlük snapshot oluştur veya güncelle
    func recordDailySnapshot(for asset: Asset, modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        Logger.log("📸 Recording snapshot for \(asset.name)")
        
        // Bugün için kayıt var mı kontrol et
        if let todaySnapshot = getTodaySnapshot(for: asset.id, assetType: asset.type, context: modelContext) {
            // Aynı gün içinde - sadece kuru güncelle
            todaySnapshot.price = asset.currentPrice
            todaySnapshot.amount = asset.amount
            todaySnapshot.totalValue = asset.totalValue
            todaySnapshot.createdAt = Date()
            
            Logger.log("📸 Updated today's snapshot for \(asset.name): ₺\(asset.currentPrice)")
        } else {
            // Yeni gün - yeni kayıt oluştur
            createNewSnapshot(for: asset, date: today, context: modelContext)
            
            // 30 kayıt limitini kontrol et
            enforceHistoryLimit(for: asset.id, assetType: asset.type, context: modelContext)
        }
        
        saveContext(modelContext)
    }
    
    /// İlk kez varlık eklendiğinde initial snapshot oluştur
    func createInitialSnapshot(for asset: Asset, purchasePrice: Double, modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: asset.dateAdded)
        
        // Initial snapshot oluştur
        let snapshot = AssetPriceHistory(
            assetType: asset.type,
            date: today,
            price: purchasePrice,
            amount: asset.amount
        )
        
        modelContext.insert(snapshot)
        Logger.log("📸 Created initial snapshot for \(asset.name): ₺\(purchasePrice)")
        
        saveContext(modelContext)
    }
    
    // MARK: - Snapshot Operations
    
    private func createNewSnapshot(for asset: Asset, date: Date, context: ModelContext) {
        let snapshot = AssetPriceHistory(
            assetType: asset.type,
            date: date,
            price: asset.currentPrice,
            amount: asset.amount
        )
        
        context.insert(snapshot)
        Logger.log("📸 Created new snapshot for \(asset.name): ₺\(asset.currentPrice)")
    }
    
    private func getTodaySnapshot(for assetId: UUID, assetType: AssetType, context: ModelContext) -> AssetPriceHistory? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.date == today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let allToday = (try? context.fetch(descriptor)) ?? []
        return allToday.first { $0.assetType == assetType }
    }
    
    // MARK: - History Limit Management
    
    /// 30 kayıt limitini kontrol et ve gerekirse eski kayıtları sil
    private func enforceHistoryLimit(for assetId: UUID, assetType: AssetType, context: ModelContext) {
        let allHistory = getHistory(for: assetType, context: context)
        
        guard allHistory.count > maxHistoryCount else {
            Logger.log("📸 History count (\(allHistory.count)) within limit for \(assetType.displayName)")
            return
        }
        
        // İlk kayıt hariç, en eski kayıtları sil
        let sortedHistory = allHistory.sorted { $0.date < $1.date }
        let initialSnapshot = sortedHistory.first
        
        // İlk kayıt + son 29 kayıt = 30 kayıt
        let recordsToKeep = maxHistoryCount - 1 // İlk kayıt için 1 yer ayır
        let recentRecords = Array(sortedHistory.suffix(recordsToKeep))
        
        // Silinecek kayıtları belirle (ilk kayıt hariç)
        var recordsToDelete: [AssetPriceHistory] = []
        for record in sortedHistory {
            if record.id != initialSnapshot?.id && !recentRecords.contains(where: { $0.id == record.id }) {
                recordsToDelete.append(record)
            }
        }
        
        // Kayıtları sil
        recordsToDelete.forEach { context.delete($0) }
        Logger.log("📸 Deleted \(recordsToDelete.count) old records for \(assetType.displayName), keeping initial + recent \(recordsToKeep)")
        
        saveContext(context)
    }
    
    // MARK: - History Retrieval
    
    /// Belirli bir asset type için tüm geçmiş kayıtları getir
    func getHistory(for assetType: AssetType, context: ModelContext) -> [AssetPriceHistory] {
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let allHistory = (try? context.fetch(descriptor)) ?? []
        return allHistory.filter { $0.assetType == assetType }
    }
    
    /// Belirli bir tarih aralığı için kayıtları getir
    func getHistory(
        for assetType: AssetType,
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) -> [AssetPriceHistory] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.date >= start && history.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        let allHistory = (try? context.fetch(descriptor)) ?? []
        return allHistory.filter { $0.assetType == assetType }
    }
    
    // MARK: - Cleanup
    
    /// Varlık silindiğinde ilgili tüm kayıtları temizle
    func deleteAllHistory(for assetType: AssetType, context: ModelContext) {
        let allHistory = getHistory(for: assetType, context: context)
        
        allHistory.forEach { context.delete($0) }
        Logger.log("🗑️ Deleted \(allHistory.count) history records for \(assetType.displayName)")
        
        saveContext(context)
    }
    
    /// Varlık silindiğinde tüm işlem geçmişini temizle
    func deleteAllTransactionHistory(for assetType: AssetType, context: ModelContext) {
        let allTransactions = getTransactionHistory(for: assetType, context: context)
        
        allTransactions.forEach { context.delete($0) }
        Logger.log("🗑️ Deleted \(allTransactions.count) transaction records for \(assetType.displayName)")
        
        saveContext(context)
    }
    
    /// Tüm history kayıtlarını temizle (factory reset için)
    func deleteAllHistory(context: ModelContext) {
        let descriptor = FetchDescriptor<AssetPriceHistory>()
        let allHistory = (try? context.fetch(descriptor)) ?? []
        
        allHistory.forEach { context.delete($0) }
        Logger.log("🗑️ Deleted all \(allHistory.count) history records")
        
        saveContext(context)
    }
    
    // MARK: - Helper Methods
    
    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Logger.log("❌ AssetHistoryManager: Failed to save - \(error)")
        }
    }
    
    // MARK: - Chart Data
    
    /// Grafik için veri hazırla
    func getChartData(
        for assetType: AssetType,
        days: Int,
        context: ModelContext
    ) -> [(date: Date, price: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: today)!
        
        let history = getHistory(for: assetType, from: startDate, to: today, context: context)
        
        return history.map { ($0.date, $0.price) }
    }
    
    // MARK: - Transaction History Management
    
    /// Varlık işlem geçmişi oluştur (ekleme, çıkarma, düzenleme)
    func recordTransaction(
        assetType: AssetType,
        transactionType: AssetTransactionHistory.TransactionType,
        amount: Double,
        totalAmount: Double,
        price: Double,
        date: Date? = nil,
        context: ModelContext
    ) {
        let transaction = AssetTransactionHistory(
            assetType: assetType,
            date: date ?? Date(), // Custom date veya bugün
            transactionType: transactionType,
            amount: amount,
            totalAmount: totalAmount,
            price: price
        )
        
        context.insert(transaction)
        Logger.log("📝 Created transaction: \(transactionType.displayName) - \(amount) of \(assetType.displayName) on \(date ?? Date())")
        
        // 10 kayıt limitini kontrol et
        enforceTransactionHistoryLimit(for: assetType, context: context)
        
        saveContext(context)
    }
    
    /// İşlem geçmişi limitini kontrol et
    private func enforceTransactionHistoryLimit(for assetType: AssetType, context: ModelContext) {
        let allTransactions = getTransactionHistory(for: assetType, context: context)
        
        guard allTransactions.count > maxTransactionHistoryCount else {
            Logger.log("📝 Transaction count (\(allTransactions.count)) within limit for \(assetType.displayName)")
            return
        }
        
        // İlk kayıt hariç, en eski kayıtları sil
        let sortedTransactions = allTransactions.sorted { $0.date < $1.date }
        let initialTransaction = sortedTransactions.first { $0.transactionType == .initial }
        
        // İlk kayıt + son 9 kayıt = 10 kayıt
        let recordsToKeep = maxTransactionHistoryCount - (initialTransaction != nil ? 1 : 0)
        let recentRecords = Array(sortedTransactions.suffix(recordsToKeep))
        
        // Silinecek kayıtları belirle (ilk kayıt hariç)
        var recordsToDelete: [AssetTransactionHistory] = []
        for record in sortedTransactions {
            if record.id != initialTransaction?.id && !recentRecords.contains(where: { $0.id == record.id }) {
                recordsToDelete.append(record)
            }
        }
        
        // Kayıtları sil
        recordsToDelete.forEach { context.delete($0) }
        Logger.log("📝 Deleted \(recordsToDelete.count) old transactions for \(assetType.displayName)")
        
        saveContext(context)
    }
    
    /// Belirli bir asset type için tüm işlem geçmişini getir
    func getTransactionHistory(for assetType: AssetType, context: ModelContext) -> [AssetTransactionHistory] {
        let descriptor = FetchDescriptor<AssetTransactionHistory>(
            sortBy: [SortDescriptor(\.date, order: .forward)]  // En eski üstte, en yeni altta
        )

        let allTransactions = (try? context.fetch(descriptor)) ?? []
        return allTransactions.filter { $0.assetType == assetType }
    }
}
