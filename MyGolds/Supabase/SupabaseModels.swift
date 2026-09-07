//
//  SupabaseModels.swift
//  MyGolds
//
//  Remote (Codable) models. In the hybrid architecture, Supabase is used ONLY to
//  read live market prices — user portfolios/assets live locally in SwiftData and
//  are never written to the backend.
//

import Foundation

/// A single live price row from the `assets_prices` table.
///
/// The table is keyed by `(symbol, currency)` so the same asset can appear in
/// more than one currency (e.g. crypto in both USD and TRY). For the Turkish
/// gold/FX rows the app consumes today, each symbol has exactly one (TRY) row.
struct AssetPrice: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(symbol)_\(currency)" }

    let symbol: String
    let currency: String
    let name: String?
    /// Backend category: "crypto", "currency", "gold", "bist", "us_stock", "fund".
    let assetType: String
    let price: Double
    let changePercent: Double?
    let source: String?
    /// Enstrümanın kendi logosu (kendi Storage'ımızdan). nil = logo yok,
    /// istemci kategori ikonuna düşer.
    let logoUrl: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case symbol
        case currency
        case name
        case price
        case source
        case assetType     = "asset_type"
        case changePercent = "change_percent"
        case logoUrl       = "logo_url"
        case updatedAt      = "updated_at"
    }
}
