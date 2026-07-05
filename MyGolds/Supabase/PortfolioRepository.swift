//
//  PortfolioRepository.swift
//  MyGolds
//
//  SwiftData abstraction for local user data (Portfolio + Asset). View models
//  depend on `PortfolioRepositoryProtocol` and never touch `ModelContext` directly,
//  keeping persistence decoupled from the UI.
//

import Foundation
import SwiftData

/// CRUD abstraction over the locally-persisted `Portfolio` / `Asset` models.
@MainActor
protocol PortfolioRepositoryProtocol {
    // Portfolios
    func fetchPortfolios() throws -> [Portfolio]
    @discardableResult
    func createPortfolio(name: String, colorHex: String, isGeneral: Bool) throws -> Portfolio
    func updatePortfolio(_ portfolio: Portfolio, name: String?, colorHex: String?) throws
    func deletePortfolio(_ portfolio: Portfolio) throws

    // Assets
    func assets(in portfolio: Portfolio) -> [Asset]
    @discardableResult
    func addAsset(type: AssetType, amount: Double, averageBuyPrice: Double, to portfolio: Portfolio) throws -> Asset
    func updateAsset(_ asset: Asset, amount: Double) throws
    func deleteAsset(_ asset: Asset) throws

    // Snapshots (historical valuation)
    func snapshots(for portfolio: Portfolio) -> [PortfolioSnapshot]
    func latestSnapshotDate(for portfolio: Portfolio) -> Date?
    @discardableResult
    func addSnapshot(date: Date, totalValue: Double, to portfolio: Portfolio) throws -> PortfolioSnapshot
}

@MainActor
final class PortfolioRepository: PortfolioRepositoryProtocol {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Portfolios

    func fetchPortfolios() throws -> [Portfolio] {
        do {
            let descriptor = FetchDescriptor<Portfolio>(
                sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
            )
            return try context.fetch(descriptor)
        } catch {
            throw AppError.persistence(underlying: error)
        }
    }

    @discardableResult
    func createPortfolio(name: String,
                         colorHex: String = PortfolioColor.blue.rawValue,
                         isGeneral: Bool = false) throws -> Portfolio {
        let existing = (try? fetchPortfolios()) ?? []
        let nextOrder = (existing.map(\.sortOrder).max() ?? 0) + 1
        let portfolio = Portfolio(name: name, colorHex: colorHex, sortOrder: nextOrder, isGeneral: isGeneral)
        context.insert(portfolio)
        try saveOrThrow()
        return portfolio
    }

    func updatePortfolio(_ portfolio: Portfolio, name: String? = nil, colorHex: String? = nil) throws {
        if let name { portfolio.name = name }
        if let colorHex { portfolio.colorHex = colorHex }
        try saveOrThrow()
    }

    func deletePortfolio(_ portfolio: Portfolio) throws {
        // Cascade-delete the portfolio's assets so none are orphaned.
        for asset in portfolio.assets ?? [] {
            context.delete(asset)
        }
        context.delete(portfolio)
        try saveOrThrow()
    }

    // MARK: - Assets

    func assets(in portfolio: Portfolio) -> [Asset] {
        (portfolio.assets ?? []).sorted { $0.dateAdded < $1.dateAdded }
    }

    @discardableResult
    func addAsset(type: AssetType,
                  amount: Double,
                  averageBuyPrice: Double,
                  to portfolio: Portfolio) throws -> Asset {
        // `currentPrice` is seeded with the buy price; live prices from
        // `MarketDataService` update it afterwards.
        let asset = Asset(type: type, amount: amount, currentRate: 0, currentPrice: averageBuyPrice)
        asset.portfolio = portfolio
        context.insert(asset)
        try saveOrThrow()
        return asset
    }

    func updateAsset(_ asset: Asset, amount: Double) throws {
        asset.amount = amount
        asset.lastUpdated = Date()
        try saveOrThrow()
    }

    func deleteAsset(_ asset: Asset) throws {
        context.delete(asset)
        try saveOrThrow()
    }

    // MARK: - Snapshots

    func snapshots(for portfolio: Portfolio) -> [PortfolioSnapshot] {
        (portfolio.snapshots ?? []).sorted { $0.date < $1.date }
    }

    func latestSnapshotDate(for portfolio: Portfolio) -> Date? {
        (portfolio.snapshots ?? []).map(\.date).max()
    }

    @discardableResult
    func addSnapshot(date: Date, totalValue: Double, to portfolio: Portfolio) throws -> PortfolioSnapshot {
        let snapshot = PortfolioSnapshot(date: date, totalValue: totalValue, portfolio: portfolio)
        context.insert(snapshot)
        try saveOrThrow()
        return snapshot
    }

    // MARK: - Helpers

    private func saveOrThrow() throws {
        do {
            try context.save()
        } catch {
            throw AppError.persistence(underlying: error)
        }
    }
}
