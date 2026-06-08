//
//  MarketDataService.swift
//  MyGolds
//
//  Read-only access to live market prices from the `assets_prices` table.
//  All prices (stocks, crypto, gold, FX, funds) are produced by backend Edge
//  Functions — the iOS app never scrapes or calls third-party price APIs.
//

import Foundation
import Supabase

/// Abstraction over market prices so view models / services can be mocked/tested.
protocol MarketDataServiceProtocol: Sendable {
    /// Fetches every current price row from `assets_prices`.
    func fetchLivePrices() async throws -> [AssetPrice]
    /// Convenience: live prices keyed by symbol for O(1) lookup.
    func fetchPriceMap() async throws -> [String: AssetPrice]
    /// Fetches historical closing prices for the given symbols within a date range
    /// (inclusive). Used by the "Time Machine" to reconstruct missing snapshots.
    func fetchHistoricalPrices(symbols: [String], from: Date, to: Date) async throws -> [AssetPrice]
}

final class MarketDataService: MarketDataServiceProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    private let table = "assets_prices"

    func fetchLivePrices() async throws -> [AssetPrice] {
        do {
            return try await client
                .from(table)
                .select()
                .execute()
                .value
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchPriceMap() async throws -> [String: AssetPrice] {
        let prices = try await fetchLivePrices()
        return Dictionary(prices.map { ($0.symbol, $0) }, uniquingKeysWith: { _, last in last })
    }

    func fetchHistoricalPrices(symbols: [String], from: Date, to: Date) async throws -> [AssetPrice] {
        guard !symbols.isEmpty else { return [] }
        let iso = ISO8601DateFormatter()
        do {
            return try await client
                .from(table)
                .select()
                .in("symbol", values: symbols)
                .gte("updated_at", value: iso.string(from: from))
                .lte("updated_at", value: iso.string(from: to))
                .order("updated_at", ascending: true)
                .execute()
                .value
        } catch {
            throw AppError.map(error)
        }
    }
}
