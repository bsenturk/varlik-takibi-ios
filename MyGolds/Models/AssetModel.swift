//
//  AssetModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftData
import Foundation

@Model
final class Asset {
    var id: UUID
    var type: AssetType
    /// Canonical price/history key — matches `assets_prices.symbol`. For legacy
    /// gold/FX this equals `type.supabaseSymbol`; for crypto/stocks it's the
    /// instrument symbol (e.g. "BTC", "THYAO.IS", "AAPL"). Defaulted for
    /// SwiftData lightweight migration; backfilled on launch for old rows.
    var symbol: String = ""
    var name: String
    var amount: Double
    var unit: String
    var dateAdded: Date
    var lastUpdated: Date
    var currentRate: Double
    var currentPrice: Double

    /// The portfolio this asset belongs to. Optional for backward compatibility with
    /// pre-v3.0.0 data; the launch migration assigns every orphan asset to "Portföyüm".
    var portfolio: Portfolio?

    /// Legacy gold/FX initializer — identity comes from the closed `AssetType`.
    init(type: AssetType, amount: Double, currentRate: Double = 0.0, currentPrice: Double) {
        self.id = UUID()
        self.type = type
        self.symbol = type.supabaseSymbol
        self.name = type.displayName
        self.amount = amount
        self.unit = type.unit
        self.dateAdded = Date()
        self.lastUpdated = Date()
        self.currentRate = currentRate
        self.currentPrice = currentPrice

        Logger.log("💰 Asset created: \(name), Amount: \(amount), Price: \(currentPrice)")
    }

    /// Dynamic market initializer — crypto / BIST / US instruments identified by `symbol`.
    init(type: AssetType, symbol: String, name: String, unit: String,
         amount: Double, currentRate: Double = 0.0, currentPrice: Double) {
        self.id = UUID()
        self.type = type
        self.symbol = symbol
        self.name = name
        self.amount = amount
        self.unit = unit
        self.dateAdded = Date()
        self.lastUpdated = Date()
        self.currentRate = currentRate
        self.currentPrice = currentPrice

        Logger.log("💰 Asset created: \(name) [\(symbol)], Amount: \(amount), Price: \(currentPrice)")
    }
    
    var totalValue: Double {
        let calculatedValue = amount * currentPrice
        
        // Debug logging
        if calculatedValue <= 0 {
            Logger.log("⚠️ Asset \(name) has zero or negative value: amount=\(amount), price=\(currentPrice), total=\(calculatedValue)")
        } else {
            Logger.log("💎 Asset \(name) value: amount=\(amount), price=\(currentPrice), total=\(calculatedValue)")
        }
        
        return max(0, calculatedValue) // Negatif değerleri önle
    }
    
    // Debugging helper
    var debugDescription: String {
        return """
        Asset Debug Info:
        - Name: \(name)
        - Type: \(type.displayName)
        - Amount: \(amount)
        - Current Price: \(currentPrice)
        - Total Value: \(totalValue)
        - Last Updated: \(lastUpdated)
        """
    }
}
