//
//  CurrencyRow.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 1.05.2024.
//

import SwiftUI

struct CurrencyRow: View {
    
    let currencyModel: CurrencyModel
    
    var body: some View {
        HStack {
            Image(getCurrencyIcon())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 45, height: 45)
                .foregroundStyle(Color.white)
                .padding(.leading, 10)
            Spacer()
            VStack {
                Text("\(currencyModel.symbol)")
                    .font(.workSansBold(size: 14))
                    .foregroundStyle(Color.white)
                Text("\(currencyModel.name)")
                    .font(.workSansSemiBold(size: 12))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 70)
                Spacer()
            Text("\(currencyModel.buyingPrice)")
                    .font(.workSansBold(size: 14))
                    .foregroundStyle(Color.white)
                Spacer()
            Text("\(currencyModel.sellingPrice)")
                    .font(.workSansBold(size: 14))
                    .foregroundStyle(Color.white)
                Spacer()
            Text("\(currencyModel.exchangeRate)")
                    .font(.workSansBold(size: 14))
                    .foregroundStyle(isExchangeRateNegative() ? Color.red : Color.green)
                Spacer()
        }
        .frame(height: 50)
        .background(Color.primaryBrown)
    }
    
    private func isExchangeRateNegative() -> Bool {
        let exchangeRate = currencyModel.exchangeRate
        let isContainMinusSign = exchangeRate.contains { $0 == "-" }
        return isContainMinusSign
    }
    
    private func getCurrencyIcon() -> String {
        let symbol = currencyModel.symbol.lowercased()
        guard let currrency = CurrenciesMarket(rawValue: symbol) else { return "" }
        return currrency.imageName
    }
}

#Preview {
    CurrencyRow(currencyModel: .init(symbol: "", name: "", buyingPrice: "", sellingPrice: "", exchangeRate: ""))
}
