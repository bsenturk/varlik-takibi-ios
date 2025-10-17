//
//  AssetsView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import SwiftData

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assets: [Asset]
    @StateObject private var viewModel = AssetsViewModel()
    @StateObject private var portfolioManager = PortfolioManager.shared
    @StateObject private var marketDataManager = MarketDataManager.shared
    @State private var showingAddAsset = false
    @State private var showingAnalytics = false
    @State private var showingDeletePopup = false
    @State private var assetToDelete: Asset?
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    if assets.isEmpty {
                        emptyStateView
                    } else {
                        totalValueHeader
                        assetsListView
                    }
                }
                .navigationBarHidden(true)
                
                if !assets.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Button(action: { showingAddAsset = true }) {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(.blue)
                                    .clipShape(Circle())
                                    .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 50)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                if showingDeletePopup {
                    CustomDeletePopup(
                        assetName: assetToDelete?.name ?? "",
                        isPresented: $showingDeletePopup,
                        onDelete: {
                            if let asset = assetToDelete {
                                deleteAsset(asset)
                            }
                        }
                    )
                    .zIndex(1000)
                }
            }
            .sheet(isPresented: $showingAddAsset) {
                AssetFormView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .onAppear {
                NotificationManager.shared.requestNotificationPermission()
                Task {
                    await refreshDataAndUpdateAssets()
                }
            }
            .onChange(of: assets) { oldAssets, newAssets in
                updatePortfolioData()
            }
            .refreshable {
                await refreshDataAndUpdateAssets()
            }
        }
    }
    
    private var totalValueHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Varlık")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(portfolioManager.currentTotalValue.formatAsCurrency())
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    if portfolioManager.totalInvestment > 0 &&
                       portfolioManager.currentTotalValue > 0 &&
                       abs(portfolioManager.profitLoss) > 0.01 {
                        HStack(spacing: 4) {
                            Image(systemName: portfolioManager.profitLoss >= 0 ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Text(formatProfitLossPercentage(portfolioManager.profitLossPercentage, profitLoss: portfolioManager.profitLoss))
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            Text("(\(portfolioManager.profitLoss >= 0 ? "+" : "")\(portfolioManager.profitLoss.formatAsCurrency()))")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(portfolioManager.profitLoss >= 0 ? .green.opacity(0.8) : .red.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button(action: { showingAnalytics = true }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var assetsListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Varlıklarım")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(assets.count) varlık")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(assets) { asset in
                        AssetCardView(
                            asset: asset,
                            onDelete: {
                                assetToDelete = asset
                                showingDeletePopup = true
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 180)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "wallet.pass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("Henüz varlık eklenmemiş")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("İlk varlığınızı ekleyerek portföy takibine başlayın. Altın, döviz ve diğer varlıklarınızı kolayca yönetebilirsiniz.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showingAddAsset = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("İlk Varlığını Ekle")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    // MARK: - Helper Functions
    
    private func formatProfitLossPercentage(_ percentage: Double, profitLoss: Double) -> String {
        let absPercentage = abs(percentage)
        
        if absPercentage < 0.01 && profitLoss != 0 {
            let result = "\(profitLoss >= 0 ? "+" : "")<0,01%"
            return result
        } else {
            let sign = profitLoss >= 0 ? "+" : ""
            let result = "\(sign)\(String(format: "%.2f", percentage))%"
            return result
        }
    }
    
    @MainActor
    private func refreshDataAndUpdateAssets() async {
        await marketDataManager.refreshData()
        await updateAssetValuesWithMarketData()
        updatePortfolioData()
    }
    
    private func updateAssetValuesWithMarketData() async {
        var hasChanges = false
        
        for asset in assets {
            let oldPrice = asset.currentPrice
            var newPrice: Double?
            
            switch asset.type {
            case .gold:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("gram") }?.sellPrice.parseToDouble()
            case .goldQuarter:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("çeyrek") }?.sellPrice.parseToDouble()
            case .goldHalf:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("yarım") }?.sellPrice.parseToDouble()
            case .goldFull:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("tam") }?.sellPrice.parseToDouble()
            case .goldRepublic:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("cumhuriyet") }?.sellPrice.parseToDouble()
            case .goldAta:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("ata") }?.sellPrice.parseToDouble()
            case .goldResat:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("reşat") }?.sellPrice.parseToDouble()
            case .goldHamit:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("hamit") }?.sellPrice.parseToDouble()
            case .goldFive:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("beşli") }?.sellPrice.parseToDouble()
            case .goldGremse:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("gremse") }?.sellPrice.parseToDouble()
            case .goldFourteen:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("14 ayar") }?.sellPrice.parseToDouble()
            case .goldEighteen:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("18 ayar") }?.sellPrice.parseToDouble()
            case .goldTwoAndHalf:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("iki buçuk") }?.sellPrice.parseToDouble()
            case .goldTwentyTwoBracelet:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("22 ayar") }?.sellPrice.parseToDouble()
            case .silver:
                newPrice = marketDataManager.goldPrices.first { $0.name.lowercased().contains("gram gümüş") }?.sellPrice.parseToDouble()
            case .usd:
                newPrice = marketDataManager.currencyRates.first { $0.code?.uppercased() == "USD" }?.sellPrice.parseToDouble()
            case .eur:
                newPrice = marketDataManager.currencyRates.first { $0.code?.uppercased() == "EUR" }?.sellPrice.parseToDouble()
            case .gbp:
                newPrice = marketDataManager.currencyRates.first { $0.code?.uppercased() == "GBP" }?.sellPrice.parseToDouble()
            case .tl:
                newPrice = 1.0
            }
            
            if let price = newPrice, abs(price - oldPrice) > 0.01 {
                asset.currentPrice = price
                asset.lastUpdated = Date()
                hasChanges = true
            }
        }
        
        if hasChanges {
            do {
                try modelContext.save()
            } catch {
                Logger.log("❌ Failed to save updated asset values: \(error)")
            }
        }
    }
    
    private func updatePortfolioData() {
        portfolioManager.updatePortfolio(with: assets)
    }
    
    private func deleteAsset(_ asset: Asset) {
        withAnimation(.easeInOut(duration: 0.4)) {
            PortfolioManager.shared.removePurchasePrice(for: asset.id)
            
            modelContext.delete(asset)
            
            do {
                try modelContext.save()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let remainingAssets = (try? self.modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                    PortfolioManager.shared.forceUpdate(with: remainingAssets)
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
            } catch {
                Logger.log("Delete error: \(error)")
            }
        }
    }
}
