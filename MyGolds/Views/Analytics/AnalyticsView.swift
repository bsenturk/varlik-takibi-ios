//
//  AnalyticsView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(\.colorScheme) var colorScheme
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
               abs(portfolioManager.profitLoss) > 0.01
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
                    
                    // Düzeltilmiş yüzde gösterimi
                    Text(formatProfitLossPercentage(portfolioManager.profitLossPercentage, profitLoss: portfolioManager.profitLoss))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    
                    Text("(\(portfolioManager.profitLoss >= 0 ? "+" : "")\(portfolioManager.profitLoss.formatAsCurrency()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                    radius: colorScheme == .dark ? 8 : 8,
                    x: 0,
                    y: 2
                )
        )
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
                Spacer()
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
                        
                        // Düzeltilmiş getiri oranı gösterimi
                        Text(formatProfitLossPercentage(portfolioManager.profitLossPercentage, profitLoss: portfolioManager.profitLoss))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(portfolioManager.profitLoss >= 0 ? .green : .red)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                    radius: colorScheme == .dark ? 8 : 8,
                    x: 0,
                    y: 2
                )
        )
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.15),
                    radius: colorScheme == .dark ? 8 : 8,
                    x: 0,
                    y: 2
                )
        )
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
            
            // Düzeltilmiş yüzde gösterimi
            Text(formatDistributionPercentage(percentage))
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
    
    // Kar/zarar yüzdesi formatlama
    private func formatProfitLossPercentage(_ percentage: Double, profitLoss: Double) -> String {
        let absPercentage = abs(percentage)
        
        if absPercentage < 0.01 && profitLoss != 0 {
            return "\(profitLoss >= 0 ? "+" : "")<0,01%"
        } else {
            let sign = profitLoss >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.2f", percentage))%"
        }
    }
    
    // Varlık dağılım yüzdesi formatlama - düzeltilmiş
    private func formatDistributionPercentage(_ percentage: Double) -> String {
        if percentage < 0.01 && percentage > 0 {
            return "<0,01%"
        } else if percentage >= 99.99 && percentage < 100 {
            return "99,99%"
        } else {
            return "\(String(format: "%.2f", percentage))%"
        }
    }
    
    private func getAssetDistribution() -> [AssetDistribution] {
        let totalValue = portfolioManager.currentTotalValue
        
        // Toplam değer 0 veya negatifse, empty array döndür
        guard totalValue > 0 else {
            Logger.log("⚠️ Total portfolio value is zero or negative: \(totalValue)")
            return []
        }
        
        // Varlıkları type'a göre grupla
        let groupedAssets = Dictionary(grouping: assets) { $0.type }
        
        Logger.log("📊 Calculating asset distribution:")
        Logger.log("📊 Total portfolio value: \(totalValue)")
        Logger.log("📊 Number of asset groups: \(groupedAssets.count)")
        
        var distributions: [AssetDistribution] = []
        
        // Her varlık türü için hesaplama yap
        for (type, assetsOfType) in groupedAssets {
            // Bu type'daki tüm varlıkların toplam değeri
            let totalValueForType = assetsOfType.reduce(0) { partialResult, asset in
                let assetValue = asset.totalValue
                Logger.log("📊 Asset: \(asset.name), Amount: \(asset.amount), Price: \(asset.currentPrice), Total: \(assetValue)")
                return partialResult + assetValue
            }
            
            // Değer 0 veya negatifse skip et
            guard totalValueForType > 0 else {
                Logger.log("⚠️ Skipping \(type.displayName) - zero or negative value: \(totalValueForType)")
                continue
            }
            
            // TAM HASSAS yüzde hesaplama - Double precision kullan
            let exactPercentage = (totalValueForType / totalValue) * 100.0
            
            Logger.log("📊 \(type.displayName): Value=\(totalValueForType), TotalValue=\(totalValue), ExactPercentage=\(exactPercentage)%")
            
            let distribution = AssetDistribution(
                name: type.displayName,
                value: totalValueForType,
                percentage: exactPercentage,
                color: type.color
            )
            
            distributions.append(distribution)
        }
        
        // Değere göre büyükten küçüğe sırala
        distributions.sort { $0.value > $1.value }
        
        // Validation - toplam yüzde kontrolü
        let totalCalculatedPercentage = distributions.reduce(0) { $0 + $1.percentage }
        Logger.log("📊 Total calculated percentage: \(totalCalculatedPercentage)%")
        
        // Eğer sadece 2 varlık varsa ve toplam 100'e yakınsa, hassas düzeltme yap
        if distributions.count == 2 && abs(totalCalculatedPercentage - 100.0) < 0.1 {
            Logger.log("📊 Applying precise adjustment for 2 assets")
            
            let largestAsset = distributions[0]
            let smallestAsset = distributions[1]
            
            // Küçük varlığın gerçek yüzdesini hesapla
            let smallPercentage = (smallestAsset.value / totalValue) * 100.0
            let largePercentage = 100.0 - smallPercentage
            
            distributions = [
                AssetDistribution(
                    name: largestAsset.name,
                    value: largestAsset.value,
                    percentage: largePercentage,
                    color: largestAsset.color
                ),
                AssetDistribution(
                    name: smallestAsset.name,
                    value: smallestAsset.value,
                    percentage: smallPercentage,
                    color: smallestAsset.color
                )
            ]
            
            Logger.log("📊 Adjusted percentages:")
            Logger.log("📊 \(largestAsset.name): \(largePercentage)%")
            Logger.log("📊 \(smallestAsset.name): \(smallPercentage)%")
        }
        // Genel normalizasyon (3+ varlık için)
        else if abs(totalCalculatedPercentage - 100.0) > 0.01 && !distributions.isEmpty {
            Logger.log("📊 Normalizing percentages to total 100%...")
            
            let normalizationFactor = 100.0 / totalCalculatedPercentage
            distributions = distributions.map { distribution in
                let normalizedPercentage = distribution.percentage * normalizationFactor
                Logger.log("📊 \(distribution.name): \(distribution.percentage)% -> \(normalizedPercentage)%")
                return AssetDistribution(
                    name: distribution.name,
                    value: distribution.value,
                    percentage: normalizedPercentage,
                    color: distribution.color
                )
            }
        }
        
        // Final verification
        let finalTotal = distributions.reduce(0) { $0 + $1.percentage }
        Logger.log("📊 Final total percentage: \(finalTotal)%")
        
        return distributions
    }
}

struct AssetDistribution {
    let name: String
    let value: Double
    let percentage: Double
    let color: String
}
