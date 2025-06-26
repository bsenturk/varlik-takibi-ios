//
//  CurrencyHeaderSectionView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 1.05.2024.
//

import SwiftUI

struct CurrencyHeaderSectionView: View {
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 65, height: 50)
                .foregroundStyle(Color.clear)
            Spacer()
            Text("Kurlar")
                .font(.workSansBold(size: 16))
                .foregroundStyle(Color.white)
            Rectangle()
                .frame(width: 15, height: 50)
                .foregroundStyle(Color.clear)
            Spacer()
            Text("Alış")
                .font(.workSansBold(size: 16))
                .foregroundStyle(Color.white)
            Rectangle()
                .frame(width: 10, height: 50)
                .foregroundStyle(Color.clear)
            Spacer()
            Text("Satış")
                .font(.workSansBold(size: 16))
                .foregroundStyle(Color.white)
            Spacer()
            Text("Değişim")
                .font(.workSansBold(size: 16))
                .foregroundStyle(Color.white)
            Spacer()
        }
        .frame(height: 50)
        .background(Color.secondaryBrown)
    }
}

#Preview {
    CurrencyHeaderSectionView()
}
