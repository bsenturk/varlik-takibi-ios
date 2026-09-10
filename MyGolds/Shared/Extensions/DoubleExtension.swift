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
    
    /// Biçimlendirme kuralı `Currency` içinde; burası yalnızca çağrı yeri
    /// kolaylığı için duruyor.
    func formatAsCurrency(currency: Currency = .TRY) -> String {
        currency.format(self)
    }
}

extension Double {
    /// Düzenlenebilir bir metin alanına yazılacak sayı gösterimi: Türkçe virgül,
    /// **binlik ayracı yok** (alan `parseToDouble` ile geri okunuyor) ve asla
    /// bilimsel gösterim yok — `String(format: "%g")` 1.000.000'dan sonra
    /// "3,74749e+06" üretiyordu.
    static func editableString(_ value: Double, maxDecimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

extension String {
    /// Portföyün gözü kapalıyken tutarın yerine geçen metin. Bayrağı
    /// `UserDefaultsManager.isPortfolioMasked(...)` ile hesaplayan ekranlar çağırır.
    func maskedIfNeeded(_ isMasked: Bool) -> String {
        isMasked ? "••••••" : self
    }
}
