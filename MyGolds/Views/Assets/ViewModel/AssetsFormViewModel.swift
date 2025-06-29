//
//  AssetsFormViewModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI

class AssetsFormViewModel: ObservableObject {
    @Published var rates: [AssetsPrice] = []
    
    init() {
        rates.append(contentsOf: MarketDataManager.shared.currencyRates)
        rates.append(contentsOf: MarketDataManager.shared.goldPrices)
    }
    
    func getSelectedAsset(from name: String) -> AssetsPrice? {
        switch name {
        case "Dolar":
            return MarketDataManager.shared.currencyRates.first { $0.code?.uppercased() == "USD" }
        case "Euro":
            return MarketDataManager.shared.currencyRates.first { $0.code?.uppercased() == "EUR" }
        case "Sterlin":
            return MarketDataManager.shared.currencyRates.first { $0.code?.uppercased() == "GBP" }
        case "Türk Lirası":
            return AssetsPrice(name: "Türk Lirası", code: "TRY", buyPrice: "1", sellPrice: "1", change: "", changePercent: "", lastUpdate: Date())
        default:
            return MarketDataManager.shared.goldPrices.first { $0.name.lowercased().contains(name.lowercased()) }
        }
    }
    
    func convertSelectedAssetRateToDouble(from name: String) -> Double {
        guard let rate = getSelectedAsset(from: name) else { return 0.0 }
        let clearRate = rate.sellPrice.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(clearRate) ?? 0.0
    }
}
