//
//  AssetHistoryManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 19.10.2025.
//
//  Price/transaction history is keyed by `symbol` (matching `assets_prices` and
//  `Asset.symbol`) so that crypto/stock instruments — which all share a generic
//  `AssetType` — keep separate histories.
//

import SwiftData
import Foundation

class AssetHistoryManager {
    static let shared = AssetHistoryManager()

    // Keep ~13 months of daily price history so longer analysis ranges (3A/1Y)
    // can accumulate. One row per asset per day is cheap in local SwiftData.
    private let maxHistoryCount = 400
    private let maxTransactionHistoryCount = 50

    private init() {}

    // MARK: - Daily Snapshot Management

    /// Create or update today's price snapshot for an asset.
    func recordDailySnapshot(for asset: Asset, modelContext: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        Logger.log("📸 Recording snapshot for \(asset.name)")

        if let todaySnapshot = getTodaySnapshot(for: asset.symbol, context: modelContext) {
            todaySnapshot.price = asset.currentPrice
            todaySnapshot.amount = asset.amount
            todaySnapshot.totalValue = asset.totalValue
            todaySnapshot.createdAt = Date()
            Logger.log("📸 Updated today's snapshot for \(asset.name): ₺\(asset.currentPrice)")
        } else {
            createNewSnapshot(for: asset, date: today, context: modelContext)
            enforceHistoryLimit(for: asset.symbol, context: modelContext)
        }

        saveContext(modelContext)
    }

    /// Initial snapshot when an asset is first added.
    func createInitialSnapshot(for asset: Asset, purchasePrice: Double, modelContext: ModelContext) {
        let today = Calendar.current.startOfDay(for: asset.dateAdded)
        let snapshot = AssetPriceHistory(
            assetType: asset.type,
            symbol: asset.symbol,
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
            symbol: asset.symbol,
            date: date,
            price: asset.currentPrice,
            amount: asset.amount
        )
        context.insert(snapshot)
        Logger.log("📸 Created new snapshot for \(asset.name): ₺\(asset.currentPrice)")
    }

    private func getTodaySnapshot(for symbol: String, context: ModelContext) -> AssetPriceHistory? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.date == today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let allToday = (try? context.fetch(descriptor)) ?? []
        return allToday.first { $0.symbol == symbol }
    }

    // MARK: - History Limit Management

    private func enforceHistoryLimit(for symbol: String, context: ModelContext) {
        let allHistory = getHistory(for: symbol, context: context)

        guard allHistory.count > maxHistoryCount else {
            Logger.log("📸 History count (\(allHistory.count)) within limit for \(symbol)")
            return
        }

        let sortedHistory = allHistory.sorted { $0.date < $1.date }
        let initialSnapshot = sortedHistory.first
        let recordsToKeep = maxHistoryCount - 1
        let recentRecords = Array(sortedHistory.suffix(recordsToKeep))

        var recordsToDelete: [AssetPriceHistory] = []
        for record in sortedHistory {
            if record.id != initialSnapshot?.id && !recentRecords.contains(where: { $0.id == record.id }) {
                recordsToDelete.append(record)
            }
        }

        recordsToDelete.forEach { context.delete($0) }
        Logger.log("📸 Deleted \(recordsToDelete.count) old records for \(symbol)")
        saveContext(context)
    }

    // MARK: - History Retrieval

    /// All price history for a symbol.
    /// Sembol filtresi predicate'te: bellekte filtrelemek tüm geçmiş tablosunu
    /// her çağrıda materyalize ediyordu ve bu fonksiyon dashboard'da varlık
    /// başına, analizde sıralama karşılaştırıcısının içinde çağrılıyor.
    func getHistory(for symbol: String, context: ModelContext) -> [AssetPriceHistory] {
        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { $0.symbol == symbol },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Price history within a date range.
    func getHistory(
        for symbol: String,
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) -> [AssetPriceHistory] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        let descriptor = FetchDescriptor<AssetPriceHistory>(
            predicate: #Predicate { history in
                history.symbol == symbol && history.date >= start && history.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Cleanup

    func deleteAllHistory(for symbol: String, context: ModelContext) {
        let allHistory = getHistory(for: symbol, context: context)
        allHistory.forEach { context.delete($0) }
        Logger.log("🗑️ Deleted \(allHistory.count) history records for \(symbol)")
        saveContext(context)
    }

    /// Yalnızca bu varlığın işlemlerini siler — aynı sembol başka bir
    /// portföyde tutuluyorsa onun geçmişi kalır.
    func deleteAllTransactionHistory(for asset: Asset, context: ModelContext) {
        let allTransactions = getTransactionHistory(for: asset, context: context)
        allTransactions.forEach { context.delete($0) }
        Logger.log("🗑️ Deleted \(allTransactions.count) transaction records for \(asset.name)")
        saveContext(context)
    }

    /// Delete all price history (factory reset).
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

    func getChartData(
        for symbol: String,
        days: Int,
        context: ModelContext
    ) -> [(date: Date, price: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: today)!
        let history = getHistory(for: symbol, from: startDate, to: today, context: context)
        return history.map { ($0.date, $0.price) }
    }

    // MARK: - Transaction History Management

    /// Record a transaction (add / remove / edit / initial).
    func recordTransaction(
        for asset: Asset,
        transactionType: AssetTransactionHistory.TransactionType,
        amount: Double,
        totalAmount: Double,
        price: Double,
        date: Date? = nil,
        context: ModelContext
    ) {
        let transaction = AssetTransactionHistory(
            assetType: asset.type,
            symbol: asset.symbol,
            assetID: asset.id,
            date: date ?? Date(),
            transactionType: transactionType,
            amount: amount,
            totalAmount: totalAmount,
            price: price
        )

        context.insert(transaction)
        Logger.log("📝 Created transaction: \(transactionType.displayName) - \(amount) of \(asset.symbol) on \(date ?? Date())")

        enforceTransactionHistoryLimit(for: asset, context: context)
        saveContext(context)
    }

    private func enforceTransactionHistoryLimit(for asset: Asset, context: ModelContext) {
        let allTransactions = getTransactionHistory(for: asset, context: context)

        guard allTransactions.count > maxTransactionHistoryCount else {
            Logger.log("📝 Transaction count (\(allTransactions.count)) within limit for \(asset.symbol)")
            return
        }

        let sortedTransactions = allTransactions.sorted { $0.date < $1.date }
        let initialTransaction = sortedTransactions.first { $0.transactionType == .initial }
        let recordsToKeep = maxTransactionHistoryCount - (initialTransaction != nil ? 1 : 0)
        let recentRecords = Array(sortedTransactions.suffix(recordsToKeep))

        var recordsToDelete: [AssetTransactionHistory] = []
        for record in sortedTransactions {
            if record.id != initialTransaction?.id && !recentRecords.contains(where: { $0.id == record.id }) {
                recordsToDelete.append(record)
            }
        }

        recordsToDelete.forEach { context.delete($0) }
        Logger.log("📝 Deleted \(recordsToDelete.count) old transactions for \(asset.symbol)")
        saveContext(context)
    }

    /// Bir varlığın işlem geçmişi, eskiden yeniye. Sembolle ön-filtre
    /// predicate'te; eski (assetID'siz) kayıtların eşleşmesi `belongs(to:)`'da.
    func getTransactionHistory(for asset: Asset, context: ModelContext) -> [AssetTransactionHistory] {
        let symbol = asset.symbol
        let descriptor = FetchDescriptor<AssetTransactionHistory>(
            predicate: #Predicate { $0.symbol == symbol },
            sortBy: [SortDescriptor(\.date, order: .forward), SortDescriptor(\.createdAt, order: .forward)]
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.belongs(to: asset) }
    }

    /// v3.2.0 öncesi kayıtlarda `assetID` yok. Sembolü tek bir varlıkta
    /// duranlar o varlığa atanır; birden fazla portföyde tutulan sembollerin
    /// eski kayıtları belirsiz olduğu için sembolle eşleşmeye devam eder.
    /// Her açılışta çağrılması güvenli (atanacak kayıt kalmayınca no-op).
    func backfillTransactionAssetIDs(context: ModelContext) {
        let legacy = ((try? context.fetch(FetchDescriptor<AssetTransactionHistory>())) ?? [])
            .filter { $0.assetID == nil }
        guard !legacy.isEmpty else { return }
        let bySymbol = Dictionary(grouping: (try? context.fetch(FetchDescriptor<Asset>())) ?? [], by: \.symbol)
        var changed = 0
        for row in legacy {
            guard let owners = bySymbol[row.symbol], owners.count == 1 else { continue }
            row.assetID = owners[0].id
            changed += 1
        }
        if changed > 0 {
            saveContext(context)
            Logger.log("📝 Backfilled assetID on \(changed) legacy transactions")
        }
    }
}
