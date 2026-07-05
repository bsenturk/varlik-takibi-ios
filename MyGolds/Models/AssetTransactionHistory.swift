//
//  AssetTransactionHistory.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 21.10.2025.
//

import SwiftData
import Foundation

@Model
final class AssetTransactionHistory {
    var id: UUID
    var assetType: AssetType
    /// Canonical key matching `Asset.symbol`. Defaulted for migration.
    var symbol: String = ""
    var date: Date
    var transactionType: TransactionType
    var amount: Double
    var totalAmount: Double
    var price: Double
    var totalValue: Double
    var createdAt: Date
    
    enum TransactionType: String, Codable {
        case initial = "initial" // İlk ekleme
        case add = "add" // Miktar artışı
        case remove = "remove" // Miktar azalışı
        case edit = "edit" // Düzenleme
        
        var displayName: String {
            switch self {
            case .initial: return "İlk Ekleme"
            case .add: return "Ekleme"
            case .remove: return "Çıkarma"
            case .edit: return "Güncelleme"
            }
        }
        
        var icon: String {
            switch self {
            case .initial: return "star.fill"
            case .add: return "plus.circle.fill"
            case .remove: return "minus.circle.fill"
            case .edit: return "pencil.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .initial: return "blue"
            case .add: return "green"
            case .remove: return "red"
            case .edit: return "orange"
            }
        }
    }
    
    init(
        assetType: AssetType,
        symbol: String? = nil,
        date: Date,
        transactionType: TransactionType,
        amount: Double,
        totalAmount: Double,
        price: Double
    ) {
        self.id = UUID()
        self.assetType = assetType
        self.symbol = symbol ?? assetType.supabaseSymbol
        self.date = Calendar.current.startOfDay(for: date)
        self.transactionType = transactionType
        self.amount = amount
        self.totalAmount = totalAmount
        self.price = price
        self.totalValue = totalAmount * price
        self.createdAt = Date()
    }
    
    // Formatting helpers
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date).uppercased(with: Locale(identifier: "tr_TR"))
    }
    
    var formattedAmount: String {
        let sign = transactionType == .add ? "+" : (transactionType == .remove ? "-" : "")
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(sign)\(String(format: "%.0f", abs(amount)))"
        } else {
            return "\(sign)\(String(format: "%.2f", abs(amount)))"
        }
    }
    
    var debugDescription: String {
        return """
        📝 \(transactionType.displayName):
        - Date: \(formattedDate)
        - Amount Change: \(formattedAmount)
        - Total Amount: \(totalAmount)
        - Price: ₺\(String(format: "%.2f", price))
        - Total Value: ₺\(String(format: "%.2f", totalValue))
        """
    }
}
