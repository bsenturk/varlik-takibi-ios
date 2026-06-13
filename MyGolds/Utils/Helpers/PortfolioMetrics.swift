//
//  PortfolioMetrics.swift
//  MyGolds
//
//  Total value + profit/loss (vs the weighted average cost basis) for a set of
//  assets. Used by the dashboard balance card.
//

import Foundation
import SwiftData

struct PortfolioMetrics {
    let totalValue: Double
    /// Profit/loss against the cost basis (in TRY): currentValue − totalCost.
    let profitLoss: Double
    /// Profit/loss as a percentage of the cost basis.
    let profitLossPercent: Double

    var hasProfitLoss: Bool { abs(profitLoss) > 0.01 }
    var isPositive: Bool { profitLoss >= 0 }

    static let zero = PortfolioMetrics(totalValue: 0, profitLoss: 0, profitLossPercent: 0)

    /// Computes total value and profit/loss vs the cost basis for the given assets.
    @MainActor
    static func compute(for assets: [Asset], context: ModelContext) -> PortfolioMetrics {
        guard !assets.isEmpty else { return .zero }

        var currentTotal = 0.0
        var costBasis = 0.0

        for asset in assets {
            currentTotal += asset.totalValue
            // Weighted average cost per unit; falls back to current price if unknown
            // (so an asset with no recorded cost contributes zero P/L).
            let cost = PortfolioManager.shared.assetPurchasePrices[asset.id] ?? asset.currentPrice
            costBasis += cost * asset.amount
        }

        let profitLoss = currentTotal - costBasis
        let percent = costBasis > 0 ? (profitLoss / costBasis) * 100.0 : 0.0
        return PortfolioMetrics(totalValue: currentTotal, profitLoss: profitLoss, profitLossPercent: percent)
    }
}
