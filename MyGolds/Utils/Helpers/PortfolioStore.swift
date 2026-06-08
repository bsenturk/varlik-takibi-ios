//
//  PortfolioStore.swift
//  MyGolds
//
//  Creation, migration and CRUD for the multi-portfolio model (v3.0.0).
//

import Foundation
import SwiftData

enum PortfolioStore {

    static let generalName = "Genel"
    static let defaultUserPortfolioName = "Portföyüm"

    // MARK: - First-launch migration

    /// Ensures the "Genel" aggregate and a default "Portföyüm" exist, and migrates any
    /// pre-v3.0.0 assets (which have no portfolio) into "Portföyüm". Safe to call on every launch.
    @MainActor
    static func ensureDefaults(context: ModelContext) {
        let portfolios = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []

        // 1. Guarantee the special "Genel" portfolio exists.
        var general = portfolios.first(where: { $0.isGeneral })
        if general == nil {
            let g = Portfolio(
                name: generalName,
                colorHex: PortfolioColor.blue.rawValue,
                sortOrder: 0,
                isGeneral: true
            )
            context.insert(g)
            general = g
        }

        // 2. Guarantee at least one real portfolio exists ("Portföyüm" on first run).
        var realPortfolios = portfolios.filter { !$0.isGeneral }
        if realPortfolios.isEmpty {
            let mine = Portfolio(
                name: defaultUserPortfolioName,
                colorHex: PortfolioColor.purple.rawValue,
                sortOrder: 1,
                isGeneral: false
            )
            context.insert(mine)
            realPortfolios = [mine]
        }

        // 3. Migrate orphan assets (pre-v3.0.0 data) into the first real portfolio.
        let defaultTarget = realPortfolios.sorted { $0.sortOrder < $1.sortOrder }.first
        if let target = defaultTarget {
            let orphans = (try? context.fetch(FetchDescriptor<Asset>()))?.filter { $0.portfolio == nil } ?? []
            for asset in orphans {
                asset.portfolio = target
            }
        }

        try? context.save()
        UserDefaultsManager.shared.setValue(value: true, key: .didCreateDefaultPortfolios)
    }

    // MARK: - Queries

    @MainActor
    static func allPortfolios(context: ModelContext) -> [Portfolio] {
        let portfolios = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []
        return portfolios.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The default real portfolio new assets are added to when none is chosen.
    @MainActor
    static func defaultRealPortfolio(context: ModelContext) -> Portfolio? {
        allPortfolios(context: context).first(where: { !$0.isGeneral })
    }

    // MARK: - CRUD

    @MainActor
    @discardableResult
    static func create(name: String, color: PortfolioColor, context: ModelContext) -> Portfolio {
        let maxOrder = allPortfolios(context: context).map(\.sortOrder).max() ?? 0
        let portfolio = Portfolio(
            name: name,
            colorHex: color.rawValue,
            sortOrder: maxOrder + 1,
            isGeneral: false
        )
        context.insert(portfolio)
        try? context.save()
        return portfolio
    }

    @MainActor
    static func update(_ portfolio: Portfolio, name: String, color: PortfolioColor, context: ModelContext) {
        portfolio.name = name
        portfolio.colorHex = color.rawValue
        try? context.save()
    }

    /// Deletes a non-general portfolio along with every asset it contains (and their history).
    @MainActor
    static func delete(_ portfolio: Portfolio, context: ModelContext) {
        guard !portfolio.isGeneral else { return }

        for asset in portfolio.assets ?? [] {
            PortfolioManager.shared.removePurchasePrice(for: asset.id)
            AssetHistoryManager.shared.deleteAllHistory(for: asset.symbol, context: context)
            AssetHistoryManager.shared.deleteAllTransactionHistory(for: asset.symbol, context: context)
            context.delete(asset)
        }
        context.delete(portfolio)
        try? context.save()
    }
}
