//
//  AnalyticsView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var assets: [Asset]
    @StateObject private var portfolioManager = PortfolioManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Real Total Portfolio Value
                    totalPortfolioCard
                    
                    // Comparison Chart (Only show if there's profit/loss data)
                    if hasProfitLossData {
                        comparisonChart
                    }
                    
                    // Real Portfolio Distribution
                    portfolioDistribution
                }
                .padding()
            }
            .navigationTitle("Varlık Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                }
            }
        }
        .onAppear {
            portfolioManager.updatePortfolio(with: assets)
        }
    }
    
    // Check if there's meaningful profit/loss data to show
    private var hasProfitLossData: Bool {
        return portfolioManager.totalInvestment > 0 &&
               portfolioManager.currentTotalValue > 0 &&
               abs(portfolioManager.profitLoss) > 0.01 // Small threshold to avoid showing tiny differences
    }
    
    private var totalPortfolioCard: some View {
        VStack(spacing: 16) {
            Text("Toplam Portföy Değeri")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(portfolioManager.currentTotalValue.formatAsCurrency())
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            // Only show profit/loss if there's meaningful data
            if hasProfitLossData {
                HStack(spacing: 4) {
                    Image(systemName: portfolioManager.profitLoss >= 0 ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    
                    Text("\(portfolioManager.profitLoss >= 0 ? "+" : "")\(abs(portfolioManager.profitLossPercentage), specifier: "%.2f")%")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    
                    Text("(\(portfolioManager.profitLoss >= 0 ? "+" : "")\(portfolioManager.profitLoss.formatAsCurrency()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maliyet vs Güncel Değer")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(alignment: .bottom, spacing: 30) {
                // Investment Cost Bar (Maliyet)
                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.8), .blue.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: 80)
                            .cornerRadius(6)
                        
                        Text("Maliyet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(portfolioManager.totalInvestment.formatAsCurrency())
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Current Value Bar (Güncel Değer)
                VStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: portfolioManager.profitLoss >= 0 ?
                                [.green.opacity(0.8), .green.opacity(0.3)] :
                                [.red.opacity(0.8), .red.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(height: calculateCurrentValueBarHeight())
                            .cornerRadius(6)
                        
                        Text("Güncel Değer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(portfolioManager.currentTotalValue.formatAsCurrency())
                            .font(.caption2.weight(.medium))
                            .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .frame(height: 140)
            
            // Investment Summary
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Toplam Yatırım")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(portfolioManager.totalInvestment.formatAsCurrency())
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Güncel Değer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(portfolioManager.currentTotalValue.formatAsCurrency())
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kar/Zarar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(portfolioManager.profitLoss >= 0 ? "+" : "")\(portfolioManager.profitLoss.formatAsCurrency())")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Getiri Oranı")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(portfolioManager.profitLoss >= 0 ? "+" : "")\(portfolioManager.profitLossPercentage, specifier: "%.2f")%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    private var portfolioDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Varlık Dağılımı")
                .font(.headline)
                .foregroundColor(.primary)
            
            if assets.isEmpty {
                Text("Henüz varlık bulunmuyor")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(getAssetDistribution(), id: \.name) { distribution in
                        distributionItem(
                            name: distribution.name,
                            amount: distribution.value.formatAsCurrency(),
                            percentage: distribution.percentage,
                            color: Color(distribution.color)
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    private func distributionItem(name: String, amount: String, percentage: Double, color: Color) -> some View {
        HStack {
            // Icon
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(color)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(amount)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Percentage
            Text("%\(percentage, specifier: "%.1f")")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateCurrentValueBarHeight() -> CGFloat {
        let investmentValue = portfolioManager.totalInvestment
        let currentValue = portfolioManager.currentTotalValue
        
        guard investmentValue > 0 else { return 80 }
        
        let ratio = currentValue / investmentValue
        let height = ratio * 80 // Base height of investment bar
        
        return max(40, min(120, height)) // Min 40, Max 120
    }
    
    private func getAssetDistribution() -> [AssetDistribution] {
        let totalValue = portfolioManager.currentTotalValue
        guard totalValue > 0 else { return [] }
        
        let groupedAssets = Dictionary(grouping: assets) { $0.type }
        
        return groupedAssets.map { (type, assets) in
            let totalValueForType = assets.reduce(0) { $0 + $1.totalValue }
            let percentage = (totalValueForType / totalValue) * 100
            
            return AssetDistribution(
                name: type.displayName,
                value: totalValueForType,
                percentage: percentage,
                color: type.color
            )
        }.sorted { $0.value > $1.value }
    }
}

struct AssetDistribution {
    let name: String
    let value: Double
    let percentage: Double
    let color: String
}
