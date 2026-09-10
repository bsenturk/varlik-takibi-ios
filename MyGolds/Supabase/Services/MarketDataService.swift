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
    /// Searches TEFAS for funds matching `query` (code or name) via the
    /// `search-tefas` Edge Function. The backend fetches the funds live, upserts
    /// them into `assets_prices`, and returns the matching rows.
    func searchFunds(query: String) async throws -> [AssetPrice]
    /// Bir enstrümanın geçmiş fiyat serisini `price-chart` Edge Function'dan alır.
    /// Yalnızca kripto / BIST / ABD / fon destekleniyor (altın ve dövizin geçmiş
    /// kaynağı yok); desteklenmeyen sembollerde `AppError` fırlatır.
    func fetchPriceSeries(symbol: String, range: ChartRange) async throws -> PriceSeries
}

/// Envelope returned by the `search-tefas` Edge Function.
private struct FundSearchResponse: Decodable {
    let data: [AssetPrice]
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

    func searchFunds(query: String) async throws -> [AssetPrice] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        do {
            let response: FundSearchResponse = try await client.functions.invoke(
                "search-tefas",
                options: FunctionInvokeOptions(body: ["q": trimmed])
            ) { data, _ in
                try Self.functionDecoder.decode(FundSearchResponse.self, from: data)
            }
            return response.data
        } catch {
            throw AppError.map(error)
        }
    }

    func fetchPriceSeries(symbol: String, range: ChartRange) async throws -> PriceSeries {
        do {
            return try await client.functions.invoke(
                "price-chart",
                options: FunctionInvokeOptions(body: ["symbol": symbol, "range": range.rawValue])
            ) { data, _ in
                try Self.functionDecoder.decode(PriceSeries.self, from: data)
            }
        } catch {
            throw AppError.map(error)
        }
    }

    /// Decoder for Edge Function payloads. Mirrors `SupabaseManager`'s decoder so
    /// `updated_at` (ISO8601 with or without fractional seconds) decodes cleanly.
    private static let functionDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = withFractional.date(from: raw) ?? plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(raw)"
            )
        }
        return decoder
    }()
}
