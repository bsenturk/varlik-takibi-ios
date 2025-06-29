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
    }
    
    var totalValue: Double {
        amount * currentPrice
    }
}
