//
//  PortfolioCalculatorService.swift
//  MyGolds
//
//  The "Time Machine": silently reconstructs missing daily `PortfolioSnapshot`
//  records on launch so historical charts render without chronological gaps.
//
//  Algorithm (per portfolio):
//   1. Gap detection      — find calendar dates missing since the last snapshot.
//   2. Transaction replay  — historical asset amounts from transaction history.
//   3. Fetch prices        — historical closing prices for those dates/symbols.
//   4. Valuation           — amount × price, summed per day.
//   5. Save snapshots      — persist a PortfolioSnapshot per reconstructed day.
//

import Foundation
import SwiftData

@MainActor
protocol PortfolioCalculatorServiceProtocol {
    /// Reconstructs missing snapshots for every real (non-aggregate) portfolio.
    func reconstructAllPortfolios() async
    /// Reconstructs missing snapshots for a single portfolio.
    func reconstructSnapshots(for portfolio: Portfolio) async throws
}

@MainActor
final class PortfolioCalculatorService: PortfolioCalculatorServiceProtocol {

    private let context: ModelContext
    private let repository: PortfolioRepositoryProtocol
    private let marketData: MarketDataServiceProtocol
    private let history: AssetHistoryManager
    private let calendar: Calendar

    init(context: ModelContext,
         repository: PortfolioRepositoryProtocol,
         marketData: MarketDataServiceProtocol,
         history: AssetHistoryManager = .shared,
         calendar: Calendar = .current) {
        self.context = context
        self.repository = repository
        self.marketData = marketData
        self.history = history
        self.calendar = calendar
    }

    // MARK: - Public

    func reconstructAllPortfolios() async {
        let portfolios = (try? repository.fetchPortfolios()) ?? []
        for portfolio in portfolios where !portfolio.isGeneral {
            do {
                try await reconstructSnapshots(for: portfolio)
            } catch {
                // Best-effort: a failure for one portfolio must not block the others
                // or crash launch (e.g. offline / placeholder credentials).
                Logger.log("⏳ TimeMachine: skipped \(portfolio.name) — \(error.localizedDescription)")
            }
        }
    }

    func reconstructSnapshots(for portfolio: Portfolio) async throws {
        let assets = portfolio.assets ?? []
        guard !assets.isEmpty else { return }

        // ── Step 1: Gap detection ────────────────────────────────────────────
        let today = calendar.startOfDay(for: Date())
        let startDate = nextDay(after: firstMissingAnchor(for: portfolio, assets: assets))
        let missingDates = dates(from: startDate, to: today)
        guard !missingDates.isEmpty else { return }

        // ── Step 3: Fetch historical prices (once, for the whole range) ───────
        let symbols = Array(Set(assets.map { $0.symbol }))
        let priceRows = try await marketData.fetchHistoricalPrices(
            symbols: symbols,
            from: missingDates.first!,
            to: missingDates.last!
        )
        let priceSeries = makePriceSeries(from: priceRows)

        // ── Steps 2 + 4 + 5: replay, value and persist each missing day ──────
        var persisted = 0
        for day in missingDates {
            var total = 0.0
            for asset in assets {
                let amount = historicalAmount(of: asset, on: day)          // Step 2
                guard amount > 0 else { continue }
                let price = price(for: asset.symbol, on: day, in: priceSeries)
                total += amount * price                                     // Step 4
            }
            // Skip days we couldn't value (historical prices unavailable → total 0):
            // persisting a 0 plots a false flat-at-baseline line and breaks the range
            // % on the Analiz chart. Leaving a gap is harmless — the day is retried on a
            // later launch once prices become available.
            guard total > 0 else { continue }
            _ = try repository.addSnapshot(date: day, totalValue: total, to: portfolio) // Step 5
            persisted += 1
        }

        Logger.log("⏳ TimeMachine: reconstructed \(persisted)/\(missingDates.count) day(s) for \(portfolio.name)")
    }

    // MARK: - Step 1 helpers

    /// The anchor day *before* the first day we need to reconstruct: the last
    /// existing snapshot, or (on first run) the earliest relevant history date.
    private func firstMissingAnchor(for portfolio: Portfolio, assets: [Asset]) -> Date {
        if let last = repository.latestSnapshotDate(for: portfolio) {
            return calendar.startOfDay(for: last)
        }
        // First run: start from the earliest asset/transaction date so the whole
        // history is rebuilt. Anchor is the day *before* that earliest date.
        let earliestAsset = assets.map { calendar.startOfDay(for: $0.dateAdded) }.min()
        let earliest = earliestAsset ?? calendar.startOfDay(for: Date())
        return previousDay(before: earliest)
    }

    /// Inclusive list of start-of-day dates in `[from, to]`.
    private func dates(from: Date, to: Date) -> [Date] {
        guard from <= to else { return [] }
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        while cursor <= end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func nextDay(after date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }

    private func previousDay(before date: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
    }

    // MARK: - Step 2: transaction replay

    /// The amount of `asset` held at the end of `day`, reconstructed from its
    /// transaction history (the running `totalAmount` of the latest transaction
    /// on or before `day`). Falls back to the current amount when no transaction
    /// history exists and the asset already existed on `day`.
    private func historicalAmount(of asset: Asset, on day: Date) -> Double {
        let transactions = history
            .getTransactionHistory(for: asset.symbol, context: context)
            .filter { calendar.startOfDay(for: $0.date) <= day }
            .sorted { $0.date < $1.date }

        if let last = transactions.last {
            return max(0, last.totalAmount)
        }
        // No transactions recorded: assume the current amount has been held since
        // the asset was added.
        return calendar.startOfDay(for: asset.dateAdded) <= day ? asset.amount : 0
    }

    // MARK: - Step 3/4: price lookup

    /// `symbol -> [(day, price)]` sorted ascending, for carry-forward lookups.
    private func makePriceSeries(from rows: [AssetPrice]) -> [String: [(day: Date, price: Double)]] {
        var series: [String: [(day: Date, price: Double)]] = [:]
        for row in rows {
            let day = calendar.startOfDay(for: row.updatedAt)
            series[row.symbol, default: []].append((day, row.price))
        }
        for key in series.keys {
            series[key]?.sort { $0.day < $1.day }
        }
        return series
    }

    /// Closing price for `symbol` on `day`. Markets are closed on weekends/holidays,
    /// so we carry forward the most recent price at or before `day`.
    private func price(for symbol: String,
                       on day: Date,
                       in series: [String: [(day: Date, price: Double)]]) -> Double {
        guard let points = series[symbol], !points.isEmpty else { return 0 }
        var result = 0.0
        for point in points {
            if point.day <= day { result = point.price } else { break }
        }
        // If `day` precedes the first known price, fall back to the earliest one.
        return result == 0 ? (points.first?.price ?? 0) : result
    }
}
