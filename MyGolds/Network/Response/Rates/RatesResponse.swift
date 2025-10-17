//
//  RatesResponse.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 15.10.2025.
//

struct RatesResponse: Decodable {
    let rates: RatesDto
    
    enum CodingKeys: String, CodingKey {
        case rates = "Rates"
    }
}

struct RatesDto: Decodable {
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
        case usd = "USD"
        case eur = "EUR"
        case gbp = "GBP"
        case gra = "GRA"
        case silver = "GUMUS"
        case has = "HAS"
        case quarterGold = "CEYREKALTIN"
        case halfGold = "YARIMALTIN"
        case fullGold = "TAMALTIN"
        case republicGold = "CUMHURIYETALTINI"
        case ataGold = "ATAALTIN"
        case fourteenRateGold = "14AYARALTIN"
        case eighteenRateGold = "18AYARALTIN"
        case twoAndHalfRateGold = "IKIBUCUKALTIN"
        case fiveRateGold = "BESLIALTIN"
        case gremseGold = "GREMSEALTIN"
        case resatGold = "RESATALTIN"
        case hamitGold = "HAMITALTIN"
        case twentyTwoRateBracelet = "YIA"
    }
}

struct CommonRateDto: Decodable {
    let type: String
    let change: Double
    let name: String
    let buying: Double
    let selling: Double
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case change = "Change"
        case name = "Name"
        case buying = "Buying"
        case selling = "Selling"
    }
}
