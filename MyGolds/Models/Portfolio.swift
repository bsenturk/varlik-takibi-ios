//
//  Portfolio.swift
//  MyGolds
//
//  Multi-portfolio support (v3.0.0).
//

import SwiftData
import Foundation

@Model
final class Portfolio {
    var id: UUID = UUID()
    var name: String = ""
    /// Stored as a `PortfolioColor` raw value (hex). Drives the chip & balance-card gradient.
    var colorHex: String = PortfolioColor.blue.rawValue
    /// Ordering of the chips in the dashboard.
    var sortOrder: Int = 0
    /// The special, non-deletable "Genel" portfolio that aggregates every asset by category.
    var isGeneral: Bool = false
    /// Değer hedefi (TRY). 0 = hedef yok. Defaulted for SwiftData lightweight migration.
    var targetValue: Double = 0
    var createdAt: Date = Date()

    /// Assets that belong directly to this portfolio. `Genel` keeps this empty and
    /// is rendered as an aggregate of every asset in the app.
    @Relationship(deleteRule: .nullify, inverse: \Asset.portfolio)
    var assets: [Asset]? = []

    /// End-of-day valuation history used for charts. Cascade-deleted with the portfolio.
    @Relationship(deleteRule: .cascade, inverse: \PortfolioSnapshot.portfolio)
    var snapshots: [PortfolioSnapshot]? = []

    init(
        name: String,
        colorHex: String = PortfolioColor.blue.rawValue,
        sortOrder: Int = 0,
        isGeneral: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isGeneral = isGeneral
        self.createdAt = Date()
        self.assets = []
    }

    var color: PortfolioColor {
        PortfolioColor(rawValue: colorHex) ?? .blue
    }

    var hasTarget: Bool { targetValue > 0 }

    /// Hedefe ulaşma oranı (0...1+). Hedef yoksa 0.
    func progress(towards currentValue: Double) -> Double {
        guard targetValue > 0 else { return 0 }
        return max(0, currentValue / targetValue)
    }
}
