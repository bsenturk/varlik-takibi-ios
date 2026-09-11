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
    /// Satış fiyatı — değerleme her yerde bunun üzerinden.
    let price: Double
    /// Alış fiyatı. Yalnızca makas yayımlayan kaynaklarda (altın/döviz) dolu;
    /// kripto/hisse/fon satırlarında nil — o zaman tek fiyat gösterilir.
    let buyPrice: Double?
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
        case buyPrice      = "buy_price"
        case assetType     = "asset_type"
        case changePercent = "change_percent"
        case logoUrl       = "logo_url"
        case updatedAt      = "updated_at"
    }
}

/// Bir enstrümanın geçmiş fiyat serisi (`price-chart` Edge Function'dan).
///
/// Geçmişi kendi veritabanımızda tutmuyoruz; fonksiyon canlı fiyat için zaten
/// kullandığımız kaynaklara (Yahoo / CoinGecko / TEFAS) proxy yapıyor. Altın ve
/// döviz kapsam dışı — kaynağımız Truncgil geçmiş yayımlamıyor.
struct PriceSeries: Decodable, Sendable {
    let symbol: String
    /// Serinin para birimi. ABD hisseleri USD, diğerleri TRY.
    let currency: String
    let points: [PricePoint]
}

struct PricePoint: Decodable, Identifiable, Sendable {
    /// Epoch saniye.
    let t: Double
    /// Kapanış fiyatı.
    let c: Double

    var id: Double { t }
    var date: Date { Date(timeIntervalSince1970: t) }
}

/// Grafik zaman aralığı. `rawValue` backend'in beklediği anahtar, `label` UI etiketi.
enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case week = "1h", month = "1a", quarter = "3a", year = "1y"

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}
