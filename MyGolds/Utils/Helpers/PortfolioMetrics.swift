//
//  PortfolioMetrics.swift
//  MyGolds
//
//  Lightweight value/daily-change calculations for a set of assets, used by the
//  dashboard balance card and asset rows.
//

import Foundation
import SwiftData

struct PortfolioMetrics {
    let totalValue: Double
    /// Absolute change since the previous recorded day (in TRY).
    let dayChangeValue: Double
    /// Percentage change since the previous recorded day.
    let dayChangePercent: Double

    var hasDayChange: Bool { abs(dayChangeValue) > 0.01 }
    var isPositive: Bool { dayChangeValue >= 0 }

    static let zero = PortfolioMetrics(totalValue: 0, dayChangeValue: 0, dayChangePercent: 0)

    /// Computes the total value and the day-over-day change for the given assets.
    @MainActor
    static func compute(for assets: [Asset], context: ModelContext) -> PortfolioMetrics {
        guard !assets.isEmpty else { return .zero }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var currentTotal = 0.0
        var previousTotal = 0.0

        for asset in assets {
            let current = asset.totalValue
            currentTotal += current

            // Find the most recent snapshot strictly before today to use as the baseline.
            let history = AssetHistoryManager.shared.getHistory(for: asset.type, context: context)
            let previousPrice = history
                .filter { calendar.startOfDay(for: $0.date) < today }
                .sorted { $0.date < $1.date }
                .last?
                .price

            if let prev = previousPrice {
                previousTotal += asset.amount * prev
            } else {
                // No prior snapshot → treat as unchanged for the day.
                previousTotal += current
            }
        }

        let change = currentTotal - previousTotal
        let percent = previousTotal > 0 ? (change / previousTotal) * 100.0 : 0.0
        return PortfolioMetrics(totalValue: currentTotal, dayChangeValue: change, dayChangePercent: percent)
    }
}
