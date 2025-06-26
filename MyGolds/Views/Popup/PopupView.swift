//
//  PopupView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 3.05.2024.
//

import SwiftUI

struct PopupView: View {
    let title: String
    let message: String
    let firstButtonTitle: String
    let secondButtonTitle: String?
    let firstAction: () -> Void
    let secondAction: () -> Void
    
    var body: some View {
        VStack {
            Text(title)
                .font(.workSansBold(size: 18))
                .foregroundStyle(Color.white)
                .padding(.top, 12)
            Text(message)
                .font(.workSansRegular(size: 14))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, 4)
            Spacer()
            VStack {
                getPopupButton(
                    title: firstButtonTitle, 
                    backgroundColor: .primaryOrange) {
                        firstAction()
                    }
                
                if let secondButtonTitle {
                    getPopupButton(
                        title: secondButtonTitle,
                        backgroundColor: .tertiaryBrown) {
                            secondAction()
                        }
                }
                Spacer()
                    .frame(height: 10)
            }
        }
        .frame(width: .infinity, height: 200)
        .background(Color.secondaryBrown)
        .clipShape(.rect(cornerRadius: 20))
        .shadow(radius: 10)
        .padding(.horizontal, 20)
    }
    
    func getPopupButton(title: String, backgroundColor: Color, action: @escaping () -> Void) -> some View {
        return Button(title) {
            action()
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 40)
        .font(.workSansBold(size: 14))
        .background(backgroundColor)
        .foregroundStyle(Color.primaryBrown)
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal, 20)
    }
}

#Preview {
    PopupView(
        title: "Uyarı",
        message: "Varlığınızı silmek üzeresiniz silmek istediğinizden emin misiniz?",
        firstButtonTitle: "Tamam",
        secondButtonTitle: "Vazgeç",
        firstAction: {},
        secondAction: {}
    )
}
