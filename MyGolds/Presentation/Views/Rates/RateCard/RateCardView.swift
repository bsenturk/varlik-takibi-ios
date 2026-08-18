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

    private var changeColor: Color { isChangeRatePositive ? Color(hex: "#34C759") : Color(hex: "#FF3B30") }

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconColor.opacity(0.16))
                .frame(width: 52, height: 52)
                .overlay(AssetGlyph(icon: iconName, color: iconColor, size: 24))

            // Name + buy/sell
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(alignment: .top, spacing: 18) {
                    priceColumn("Alış", buyRate)
                    priceColumn("Satış", sellRate)
                }
            }

            Spacer(minLength: 6)

            // Change pill + sparkline
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: isChangeRatePositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(isChangeRatePositive ? "+" : "−")\(formattedPercent)")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(changeColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(changeColor.opacity(0.15))
                .clipShape(Capsule())

                SparklineView(values: sparkValues, lineColor: changeColor)
                    .frame(width: 70, height: 26)
            }
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
        }
    }

    private var formattedPercent: String {
        let raw = change.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "%", with: "")
        let value = abs(Double(raw) ?? 0)
        return "%" + String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Directional, deterministic sparkline (trend matches the real daily change sign).
    private var sparkValues: [Double] {
        var seed = UInt64(abs(title.utf8.reduce(0) { $0 &+ Int($1) }) + 7)
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 33) & 0xFFFF) / 65535.0
        }
        let drift = isChangeRatePositive ? 1.5 : -1.5
        var v = 50.0
        var values: [Double] = []
        for _ in 0..<14 {
            v += drift + (next() - 0.5) * 4.0
            values.append(v)
        }
        return values
    }
}
