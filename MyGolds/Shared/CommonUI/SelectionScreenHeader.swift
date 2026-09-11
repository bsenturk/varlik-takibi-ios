//
//  SelectionScreenHeader.swift
//  MyGolds
//
//  Tam ekran seçim ekranlarının ortak başlığı (Para Birimi, Görünüm).
//
//  İki ekranda birebir aynı olduğu için tek yerde duruyor: "uygulama standardı"
//  kopyalanarak değil paylaşılarak korunur. Satır düzenleri paylaşılmıyor —
//  biri bayrak emojisi, diğeri SF Symbol kullanıyor.
//

import SwiftUI

struct SelectionScreenHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Circle())
                    // Görsel daire 30pt, dokunma hedefi Apple'ın 44pt sınırında.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .offset(x: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}
