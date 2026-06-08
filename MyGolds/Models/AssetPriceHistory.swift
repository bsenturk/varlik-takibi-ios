//
//  AssetPriceHistory.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 19.10.2025.
//

import SwiftData
import Foundation

@Model
final class AssetPriceHistory {
    var id: UUID
    var assetType: AssetType
    /// Canonical key matching `Asset.symbol` (supports crypto/stocks where many
    /// instruments share one generic `assetType`). Defaulted for migration.
    var symbol: String = ""
    var date: Date
    var price: Double
    var amount: Double
    var totalValue: Double
    var createdAt: Date

    init(assetType: AssetType, symbol: String? = nil, date: Date, price: Double, amount: Double) {
        self.id = UUID()
        self.assetType = assetType
        self.symbol = symbol ?? assetType.supabaseSymbol
        self.date = Calendar.current.startOfDay(for: date)
        self.price = price
        self.amount = amount
        self.totalValue = price * amount
        self.createdAt = Date()
    }
    
    // Debugging
    var debugDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return """
        📊 \(assetType.displayName):
        - Date: \(formatter.string(from: date))
        - Price: ₺\(String(format: "%.2f", price))
        - Amount: \(amount) \(assetType.unit)
        - Total: ₺\(String(format: "%.2f", totalValue))
        """
    }
}

struct PriceChangeData {
    let currentValue: Double
    let previousValue: Double
    let change: Double
    let changePercentage: Double
    let period: Period
    
    enum Period {
        case daily, weekly, monthly
        
        var displayName: String {
            switch self {
            case .daily: return "Günlük"
            case .weekly: return "Haftalık"
            case .monthly: return "Aylık"
            }
        }
    }
    
    var isPositive: Bool {
        return change >= 0
    }
    
    var formattedChange: String {
        let sign = isPositive ? "+" : ""
        return "\(sign)₺\(String(format: "%.2f", change))"
    }
    
    var formattedPercentage: String {
        let sign = isPositive ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercentage))%"
    }
}
