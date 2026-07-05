//
//  PortfolioSnapshot.swift
//  MyGolds
//
//  End-of-day total valuation of a portfolio. Used to draw continuous historical
//  charts even when the app wasn't opened for several days (reconstructed by the
//  "Time Machine" — see PortfolioCalculatorService).
//

import SwiftData
import Foundation

@Model
final class PortfolioSnapshot {
    var id: UUID = UUID()
    /// Start-of-day date this snapshot represents.
    var date: Date = Date()
    /// Total portfolio value (in TRY) at the end of `date`.
    var totalValue: Double = 0

    /// Owning portfolio. Nullified (not cascaded) if the snapshot is removed; the
    /// inverse relationship on `Portfolio` cascades snapshots when a portfolio is deleted.
    @Relationship(deleteRule: .nullify)
    var portfolio: Portfolio?

    init(date: Date, totalValue: Double, portfolio: Portfolio? = nil) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.totalValue = totalValue
        self.portfolio = portfolio
    }
}
