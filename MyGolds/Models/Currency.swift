//
//  Currency.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 19.10.2025.
//

import Foundation

enum Currency: String, CaseIterable {
    case TRY = "TRY"
    case USD = "USD"
    case EUR = "EUR"
    case GBP = "GBP"
    
    var flag: String {
        switch self {
        case .TRY: return "🇹🇷"
        case .USD: return "🇺🇸"
        case .EUR: return "🇪🇺"
        case .GBP: return "🇬🇧"
        }
    }
    
    var symbol: String {
        switch self {
        case .TRY: return "₺"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        }
    }
    
    var displayName: String {
        return "\(flag) \(rawValue)"
    }
}
