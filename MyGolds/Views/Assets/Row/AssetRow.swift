//
//  AssetRow.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 22.02.2024.
//

import SwiftUI

struct AssetRow: View {    
    @Binding var currency: String
    @Binding var assetName: String
    @Binding var assetQuantity: String
    @Binding var assetTotalValue: String
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .frame(width: 50, height: 50)
                    .foregroundStyle(Color.secondaryBrown)
                Image(systemName: Currencies(rawValue: currency)?.imageName ?? "")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)
                    .foregroundStyle(.white)
            }
            .padding(.leading, 5)
            VStack(alignment: .leading) {
                Text(assetName)
                    .font(.workSansMedium(size: 16))
                    .foregroundStyle(.white)
                Text(assetQuantity)
                    .padding(.top, -2)
                    .font(.workSansRegular(size: 14))
                    .foregroundStyle(Color.tertiaryBrown)
            }
            
            Spacer()
            Text(assetTotalValue)
                .font(.workSansRegular(size: 16))
                .foregroundStyle(.white)
                .padding(.trailing, 5)
        }
    }
}

#Preview {
    AssetRow(currency: Binding.constant(""), assetName: Binding.constant(""), assetQuantity: Binding.constant(""), assetTotalValue: Binding.constant(""))
}
