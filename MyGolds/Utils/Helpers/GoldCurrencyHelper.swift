//
//  GoldCurrencyHelper.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 14.03.2024.
//

final class GoldCurrencyHelper {
    enum GoldType: String {
        case gram = "GRAM ALTIN"
        case quarter = "ÇEYREK ALTIN"
        case half = "YARIM ALTIN"
        case full = "TAM ALTIN"
        case republic = "CUMHURIYET ALTINI"
        
        var multiplier: Double {
            switch self {
            case .gram: return 1
            case .quarter: return 1.75
            case .half: return 3.5
            case .full: return 7
            case .republic: return 7.216
            }
        }
    }
    
    static func getGoldValueFromGramGold(goldType: String, gramGoldPrice: Double, quantity: Int) -> Double {
        guard let gold = GoldType(rawValue: goldType) else { return .zero }
        
        let goldPrice = gramGoldPrice * Double(quantity) * gold.multiplier 
        
        return goldPrice
    }
}
