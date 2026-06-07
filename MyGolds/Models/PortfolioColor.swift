//
//  PortfolioColor.swift
//  MyGolds
//
//  The fixed palette users pick from when creating / editing a portfolio.
//

import SwiftUI

enum PortfolioColor: String, CaseIterable, Identifiable {
    case blue   = "#007AFF"
    case purple = "#AF52DE"
    case pink   = "#FF2D55"
    case green  = "#34C759"
    case orange = "#FF9500"
    case red    = "#FF3B30"

    var id: String { rawValue }

    var color: Color { Color(hex: rawValue) }

    /// Gradient used for the selected chip and the balance card.
    var gradient: [Color] {
        switch self {
        case .blue:   return [Color(hex: "#0A84FF"), Color(hex: "#5E5CE6")]
        case .purple: return [Color(hex: "#AF52DE"), Color(hex: "#BF5AF2")]
        case .pink:   return [Color(hex: "#FF2D55"), Color(hex: "#FF375F")]
        case .green:  return [Color(hex: "#34C759"), Color(hex: "#30D158")]
        case .orange: return [Color(hex: "#FF9F0A"), Color(hex: "#FF9500")]
        case .red:    return [Color(hex: "#FF3B30"), Color(hex: "#FF453A")]
        }
    }
}

extension Color {
    /// Initializes a color from a `#RRGGBB` (or `RRGGBB`) hex string.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        case 3: // RGB shorthand
            (r, g, b) = ((int >> 8 & 0xF) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        default:
            (r, g, b) = (0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
