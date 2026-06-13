//
//  AssetType.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

/// High-level grouping used by the "Genel" aggregate portfolio.
enum AssetCategory: String, CaseIterable, Identifiable {
    case gold = "Altın"
    case silver = "Gümüş"
    case currency = "Döviz"
    case crypto = "Kripto"
    case bistStock = "Borsa İstanbul"
    case usStock = "ABD Borsası"
    case fund = "Fon"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// SF Symbol shown on the category tile / grid.
    var iconName: String {
        switch self {
        case .gold: return "circle.hexagongrid.fill"
        case .silver: return "circle.grid.2x2.fill"
        case .currency: return "banknote.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .bistStock: return "chart.line.uptrend.xyaxis"
        case .usStock: return "building.columns.fill"
        case .fund: return "chart.pie.fill"
        }
    }

    /// Accent color for the category icon tile.
    var tintHex: String {
        switch self {
        case .gold: return "#FFB300"
        case .silver: return "#9E9E9E"
        case .currency: return "#34C759"
        case .crypto: return "#F7931A"
        case .bistStock: return "#E63946"
        case .usStock: return "#2A9D8F"
        case .fund: return "#5856D6"
        }
    }

    /// Dynamic categories are populated live from the `assets_prices` catalog
    /// (crypto / stocks / funds) instead of from fixed `AssetType` cases.
    var isDynamic: Bool {
        switch self {
        case .crypto, .bistStock, .usStock, .fund: return true
        case .gold, .silver, .currency: return false
        }
    }

    /// Categories that require an active "Varlık Pro" subscription to add from.
    var isPremium: Bool {
        self == .fund
    }

    /// The backend `asset_type` value in `assets_prices` for dynamic categories.
    var backendAssetType: String? {
        switch self {
        case .crypto: return "crypto"
        case .bistStock: return "bist"
        case .usStock: return "us_stock"
        case .fund: return "fund"
        case .gold, .silver, .currency: return nil
        }
    }

    /// The generic `AssetType` used to tag holdings in a dynamic category.
    var dynamicAssetType: AssetType? {
        switch self {
        case .crypto: return .crypto
        case .bistStock: return .bistStock
        case .usStock: return .usStock
        case .fund: return .fund
        case .gold, .silver, .currency: return nil
        }
    }

    /// Asset types that belong to this category, in display order. Empty for
    /// dynamic categories (their instruments come from the live catalog).
    var assetTypes: [AssetType] {
        guard !isDynamic else { return [] }
        return AssetType.allCases.filter { $0.category == self }
    }
}

enum AssetType: String, CaseIterable, Codable {
    case gold = "gold"
    case goldQuarter = "gold_quarter"
    case goldHalf = "gold_half"
    case goldFull = "gold_full"
    case goldRepublic = "gold_republic"
    case goldAta = "gold_ata"
    case goldResat = "gold_resat"
    case goldHamit = "gold_hamit"
    case goldFive = "gold_five"
    case goldGremse = "gold_gremse"
    case goldFourteen = "gold_fourteen"
    case goldEighteen = "gold_eighteen"
    case goldTwoAndHalf = "gold_twoandhalf"
    case goldTwentyTwoBracelet = "gold_twentytwo_bracelet"
    case silver = "silver"
    case tl = "tl"
    case usd = "usd"
    case eur = "eur"
    case gbp = "gbp"
    // Dynamic market instruments. The specific instrument is identified by
    // `Asset.symbol`; these generic cases only carry category/icon metadata.
    case crypto = "crypto"
    case bistStock = "bist_stock"
    case usStock = "us_stock"
    case fund = "fund"

    /// Whether this is a generic, symbol-driven market type (crypto / stocks / funds).
    var isDynamic: Bool {
        switch self {
        case .crypto, .bistStock, .usStock, .fund: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .gold: return "Gram Altın"
        case .goldQuarter: return "Çeyrek Altın"
        case .goldHalf: return "Yarım Altın"
        case .goldFull: return "Tam Altın"
        case .goldRepublic: return "Cumhuriyet Altını"
        case .goldAta: return "Ata Altın"
        case .goldResat: return "Reşat Altın"
        case .goldHamit: return "Hamit Altın"
        case .goldFive: return "Beşli Altın"
        case .goldGremse: return "Gremse Altın"
        case .silver: return "Gram Gümüş"
        case .goldFourteen: return "14 Ayar Altın"
        case .goldEighteen: return "18 Ayar Altın"
        case .goldTwoAndHalf: return "İki Buçuk Altın"
        case .goldTwentyTwoBracelet: return "22 Ayar Bilezik"
        case .tl: return "Türk Lirası"
        case .usd: return "Dolar"
        case .eur: return "Euro"
        case .gbp: return "Sterlin"
        case .crypto: return "Kripto Para"
        case .bistStock: return "BIST Hisse"
        case .usStock: return "ABD Hisse"
        case .fund: return "Yatırım Fonu"
        }
    }

    var unit: String {
        switch self {
        case .gold, .silver: return "gram"
        case .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive, .goldGremse, .goldFourteen, .goldEighteen, .goldTwoAndHalf, .goldTwentyTwoBracelet:
            return "adet"
        case .usd: return "USD"
        case .eur: return "EUR"
        case .gbp: return "GBP"
        case .tl: return "TRY"
        case .crypto: return "adet"
        case .bistStock, .usStock: return "lot"
        case .fund: return "adet"
        }
    }

    var iconName: String {
        switch self {
        case .gold, .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive, .goldGremse, .goldFourteen, .goldEighteen, .goldTwoAndHalf, .goldTwentyTwoBracelet:
            return "circle.hexagongrid.circle"
        case .silver:
            return "soccerball.circle"
        case .usd: return "dollarsign.circle"
        case .eur: return "eurosign.circle"
        case .gbp: return "sterlingsign.circle"
        case .tl: return "turkishlirasign.circle"
        case .crypto: return "bitcoinsign.circle"
        case .bistStock: return "chart.line.uptrend.xyaxis"
        case .usStock: return "building.columns"
        case .fund: return "chart.pie"
        }
    }

    var color: String {
        switch self {
        case .gold, .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive, .goldGremse, .goldFourteen, .goldEighteen, .goldTwoAndHalf, .goldTwentyTwoBracelet:
            return "yellow"
        case .silver: return "gray"
        case .usd: return "green"
        case .eur: return "blue"
        case .gbp: return "purple"
        case .tl: return "red"
        case .crypto: return "orange"
        case .bistStock: return "red"
        case .usStock: return "teal"
        case .fund: return "indigo"
        }
    }

    /// Filled SF Symbol used on the redesigned asset/category tile.
    var tileIcon: String {
        switch self {
        case .silver: return "circle.grid.2x2.fill"
        case .usd: return "dollarsign.circle.fill"
        case .eur: return "eurosign.circle.fill"
        case .gbp: return "sterlingsign.circle.fill"
        case .tl: return "turkishlirasign.circle.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .bistStock: return "chart.line.uptrend.xyaxis"
        case .usStock: return "building.columns.fill"
        case .fund: return "chart.pie.fill"
        default: return "circle.hexagongrid.fill"
        }
    }

    /// Accent color (hex) for the asset tile glyph.
    var tileTintHex: String {
        switch self {
        case .silver: return "#9E9E9E"
        case .usd: return "#34C759"
        case .eur: return "#0A84FF"
        case .gbp: return "#AF52DE"
        case .tl: return "#FF3B30"
        case .crypto: return "#F7931A"
        case .bistStock: return "#E63946"
        case .usStock: return "#2A9D8F"
        case .fund: return "#5856D6"
        default: return "#FFB300"
        }
    }

    /// Symbol used to look this type up in the Supabase `assets_prices` table.
    /// NOTE: these must match the symbols the backend Edge Functions write.
    var supabaseSymbol: String {
        switch self {
        case .gold: return "GRAM_ALTIN"
        case .goldQuarter: return "CEYREK_ALTIN"
        case .goldHalf: return "YARIM_ALTIN"
        case .goldFull: return "TAM_ALTIN"
        case .goldRepublic: return "CUMHURIYET_ALTIN"
        case .goldAta: return "ATA_ALTIN"
        case .goldResat: return "RESAT_ALTIN"
        case .goldHamit: return "HAMIT_ALTIN"
        case .goldFive: return "BESLI_ALTIN"
        case .goldGremse: return "GREMSE_ALTIN"
        case .goldFourteen: return "14_AYAR_ALTIN"
        case .goldEighteen: return "18_AYAR_ALTIN"
        case .goldTwoAndHalf: return "IKIBUCUK_ALTIN"
        case .goldTwentyTwoBracelet: return "22_AYAR_BILEZIK"
        case .silver: return "GRAM_GUMUS"
        case .usd: return "USD"
        case .eur: return "EUR"
        case .gbp: return "GBP"
        case .tl: return "TRY"
        // Dynamic types have no fixed symbol — `Asset.symbol` is the lookup key.
        case .crypto, .bistStock, .usStock, .fund: return ""
        }
    }

    /// The high-level category this type rolls up into for the "Genel" portfolio.
    var category: AssetCategory {
        switch self {
        case .silver:
            return .silver
        case .usd, .eur, .gbp, .tl:
            return .currency
        case .crypto:
            return .crypto
        case .bistStock:
            return .bistStock
        case .usStock:
            return .usStock
        case .fund:
            return .fund
        default:
            return .gold
        }
    }
}
