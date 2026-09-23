//
//  RateCardView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RateCardView: View {
    let title: String
    let iconName: String
    let iconColor: Color
    let buyRate: String
    let sellRate: String
    let change: String
    let isChangeRatePositive: Bool
    var logoURL: URL? = nil
    var tintHex: String = "#8E8E93"

    private var changeColor: Color { isChangeRatePositive ? Color(hex: "#34C759") : Color(hex: "#FF3B30") }

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile — kripto/hissede enstrümanın kendi logosu.
            if let logoURL {
                AssetIconTile(icon: iconName, tintHex: tintHex, size: 52, logoURL: logoURL)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay(AssetGlyph(icon: iconName, color: iconColor, size: 24))
            }

            // Name + buy/sell
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                // Kaynak makas yayımlıyorsa iki sütun; yayımlamıyorsa tek "Fiyat"
                // sütunu. Daha önce alış sütununa da satış fiyatı yazılıyordu,
                // yani her kalemde sıfır makas gösteriliyordu.
                HStack(alignment: .top, spacing: 14) {
                    if buyRate.isEmpty {
                        priceColumn("Fiyat", sellRate)
                    } else {
                        priceColumn("Alış", buyRate)
                        priceColumn("Satış", sellRate)
                    }
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            // Günlük değişim
            HStack(spacing: 3) {
                Image(systemName: isChangeRatePositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text("\(isChangeRatePositive ? "+" : "−")\(formattedPercent)")
                    .font(.system(size: 13, weight: .bold))
            }
            .fixedSize()   // fiyat bloğu genişlik önceliğini aldı; rozet sarmamalı
            .foregroundColor(changeColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(changeColor.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func priceColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("₺\(value)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                // Tam/Cumhuriyet altını gibi altı haneli tutarlar kırpılmasın.
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedPercent: String {
        let raw = change.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "%", with: "")
        let value = abs(Double(raw) ?? 0)
        return "%" + String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }
}
