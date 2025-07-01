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
    var name: String
    var amount: Double
    var unit: String
    var dateAdded: Date
    var lastUpdated: Date
    var currentRate: Double
    var currentPrice: Double
    
    init(type: AssetType, amount: Double, currentRate: Double = 0.0, currentPrice: Double) {
        self.id = UUID()
        self.type = type
        self.name = type.displayName
        self.amount = amount
        self.unit = type.unit
        self.dateAdded = Date()
        self.lastUpdated = Date()
        self.currentRate = currentRate
        self.currentPrice = currentPrice
        
        Logger.log("💰 Asset created: \(name), Amount: \(amount), Price: \(currentPrice)")
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
