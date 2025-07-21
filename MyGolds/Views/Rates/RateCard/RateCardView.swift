//
//  RateCardView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RateCardView: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let iconName: String
    let iconColor: Color
    let buyRate: String
    let sellRate: String
    let change: String
    let isChangeRatePositive: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Currency Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            // Currency Info
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Text("Alış: ₺\(buyRate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Satış: ₺\(sellRate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Change Indicator
            HStack(spacing: 4) {
                Image(systemName: isChangeRatePositive ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(isChangeRatePositive ? .green : .red)
                
                Text("\(change)%")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isChangeRatePositive ? .green : .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                    radius: colorScheme == .dark ? 4 : 2,
                    x: 0,
                    y: 1
                )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}
