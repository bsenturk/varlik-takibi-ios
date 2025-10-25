//
//  RatesResponse.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

import Foundation

struct RatesResponse: Decodable {
    let updateDate: String
    let usd: CommonRateDto
    let eur: CommonRateDto
    let gbp: CommonRateDto
    let gra: CommonRateDto
    let silver: CommonRateDto
    let has: CommonRateDto
    let quarterGold: CommonRateDto
    let halfGold: CommonRateDto
    let fullGold: CommonRateDto
    let republicGold: CommonRateDto
    let ataGold: CommonRateDto
    let fourteenRateGold: CommonRateDto
    let eighteenRateGold: CommonRateDto
    let twoAndHalfRateGold: CommonRateDto
    let fiveRateGold: CommonRateDto
    let gremseGold: CommonRateDto
    let resatGold: CommonRateDto
    let hamitGold: CommonRateDto
    let twentyTwoRateBracelet: CommonRateDto

    enum CodingKeys: String, CodingKey {
        case updateDate = "Update_Date"
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case gra = "gram-altin"
        case silver = "gumus"
        case has = "gram-has-altin"
        case quarterGold = "ceyrek-altin"
        case halfGold = "yarim-altin"
        case fullGold = "tam-altin"
        case republicGold = "cumhuriyet-altini"
        case ataGold = "ata-altin"
        case fourteenRateGold = "14-ayar-altin"
        case eighteenRateGold = "18-ayar-altin"
        case twoAndHalfRateGold = "ikibucuk-altin"
        case fiveRateGold = "besli-altin"
        case gremseGold = "gremse-altin"
        case resatGold = "resat-altin"
        case hamitGold = "hamit-altin"
        case twentyTwoRateBracelet = "22-ayar-bilezik"
    }
}

struct CommonRateDto: Decodable {
    let type: String
    let change: String
    let buying: String
    let selling: String

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case change = "Change"
        case buying = "Buying"
        case selling = "Selling"
    }

    // Helper computed properties to convert string to double
    var buyingValue: Double {
        return buying.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces).toDouble() ?? 0.0
    }

    var sellingValue: Double {
        return selling.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces).toDouble() ?? 0.0
    }

    var changeValue: Double {
        let cleanedChange = change.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return cleanedChange.toDouble() ?? 0.0
    }
}

// Extension to convert String to Double
extension String {
    func toDouble() -> Double? {
        return Double(self)
    }
}
