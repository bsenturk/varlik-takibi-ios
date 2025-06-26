//
//  SettingsRow.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 5.05.2024.
//

import SwiftUI

struct SettingsRow: View {
    let model: SettingsRowModel
    
    var body: some View {
        HStack {
            Image(systemName: model.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundStyle(Color.white)
            Text("\(model.title)")
                .font(.workSansRegular(size: 12))
                .foregroundStyle(Color.white)
            Spacer()
        }
        .frame(height: 40)
        .background(Color.secondaryBrown)
    }
}

#Preview {
    SettingsRow(model: .init(image: "", title: ""))
}
