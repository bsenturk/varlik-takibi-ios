//
//  CurrencyModel.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 1.05.2024.
//

import Foundation

struct CurrencyModel: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let buyingPrice: String
    let sellingPrice: String
    let exchangeRate: String
}
