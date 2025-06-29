//
//  AssetCardView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct AssetCardView: View {
    let asset: Asset
    let onDelete: () -> Void
    @State private var showingFormSheet = false
    @State private var isDeleting = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(asset.type.color).opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: asset.type.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(asset.type.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                let formattedAmount: String = {
                    if asset.amount.truncatingRemainder(dividingBy: 1) == 0 {
                        return String(format: "%.0f", asset.amount)
                    } else {
                        return String(format: "%.3f", asset.amount).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
                    }
                }()
                
                Text("\(formattedAmount) \(asset.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text(asset.totalValue.formatAsCurrency())
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Button(action: { showingFormSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        .scaleEffect(isDeleting ? 0.95 : 1.0)
        .opacity(isDeleting ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isDeleting)
        .sheet(isPresented: $showingFormSheet) {
            AssetFormView(asset: asset)
        }
    }
}
