//
//  DoubleExtension.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import Foundation

extension Double {
    func formatAsProfitLossPercentage(profitLoss: Double) -> String {
         let absPercentage = abs(self)
         
         if absPercentage < 0.01 && profitLoss != 0 {
             return "\(profitLoss >= 0 ? "+" : "")<0,01%"
         } else {
             let formatter = NumberFormatter()
             formatter.numberStyle = .decimal
             formatter.minimumFractionDigits = 2
             formatter.maximumFractionDigits = 2
             
             let formattedNumber = formatter.string(from: NSNumber(value: abs(self))) ?? "0.00"
             let sign = profitLoss >= 0 ? "+" : (profitLoss < 0 ? "-" : "")
             
             return "\(sign)\(formattedNumber)%"
         }
     }
     
     /// Varlık dağılım yüzdesi formatlar
     func formatAsDistributionPercentage() -> String {
         if self < 0.1 && self > 0 {
             return "<0,1%"
         } else {
             let formatter = NumberFormatter()
             formatter.numberStyle = .decimal
             formatter.minimumFractionDigits = 1
             formatter.maximumFractionDigits = 1
             
             let formattedNumber = formatter.string(from: NSNumber(value: self)) ?? "0.0"
             return "\(formattedNumber)%"
         }
     }

     func formatAsCurrency() -> String {
         let formatter = NumberFormatter()
         formatter.numberStyle = .currency
         formatter.currencySymbol = "₺"
         formatter.minimumFractionDigits = 2
         formatter.maximumFractionDigits = 2
         formatter.locale = Locale(identifier: "tr_TR")
         
         return formatter.string(from: NSNumber(value: self)) ?? "₺0,00"
     }
}
