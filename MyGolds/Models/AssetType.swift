//
//  AssetType.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

enum AssetType: String, CaseIterable, Codable {
    case gold = "gold"
    case goldQuarter = "gold_quarter"
    case goldHalf = "gold_half"
    case goldFull = "gold_full"
    case goldRepublic = "gold_republic"
    case goldAta = "gold_ata"
    case goldResat = "gold_resat"
    case goldHamit = "gold_hamit"
    case goldFive = "gold_five"
    case silver = "silver"
    case tl = "tl"
    case usd = "usd"
    case eur = "eur"
    case gbp = "gbp"
    
    var displayName: String {
        switch self {
        case .gold: return "Gram Altın"
        case .goldQuarter: return "Çeyrek Altın"
        case .goldHalf: return "Yarım Altın"
        case .goldFull: return "Tam Altın"
        case .goldRepublic: return "Cumhuriyet Altını"
        case .goldAta: return "Ata Altın"
        case .goldResat: return "Reşat Altın"
        case .goldHamit: return "Hamit Altın"
        case .goldFive: return "Beşli Altın"
        case .silver: return "Gram Gümüş"
        case .tl: return "Türk Lirası"
        case .usd: return "Dolar"
        case .eur: return "Euro"
        case .gbp: return "Sterlin"
        }
    }
    
    var unit: String {
        switch self {
        case .gold, .silver: return "gram"
        case .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive:
            return "adet"
        case .usd: return "USD"
        case .eur: return "EUR"
        case .gbp: return "GBP"
        case .tl: return "TRY"
        }
    }
    
    var iconName: String {
        switch self {
        case .gold, .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive:
            return "circle.hexagongrid.circle"
        case .silver:
            return "soccerball.circle"
        case .usd: return "dollarsign.circle"
        case .eur: return "eurosign.circle"
        case .gbp: return "sterlingsign.circle"
        case .tl: return "turkishlirasign.circle"
        }
    }
    
    var color: String {
        switch self {
        case .gold, .goldQuarter, .goldHalf, .goldFull, .goldRepublic, .goldAta, .goldResat, .goldHamit, .goldFive:
            return "yellow"
        case .silver: return "gray"
        case .usd: return "green"
        case .eur: return "blue"
        case .gbp: return "purple"
        case .tl: return "red"
        }
    }
}
