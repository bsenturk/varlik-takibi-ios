//
//  AssetDetailView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 19.10.2025.
//

import SwiftUI
import Charts

struct AssetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager
    let asset: Asset

    @State private var selectedPeriod: ChartPeriod = .daily
    @State private var showPeriodSheet = false
    @State private var priceHistory: [AssetPriceHistory] = []
    @State private var transactionHistory: [AssetTransactionHistory] = []
    
    enum ChartPeriod: String, CaseIterable {
        case daily = "Günlük"
        case weekly = "Haftalık"
        case monthly = "Aylık"
        
        var icon: String {
            switch self {
            case .daily: return "calendar"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar.circle"
            }
        }
        
        var days: Int {
            switch self {
            case .daily: return 7
            case .weekly: return 30
            case .monthly: return 90
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chart Section
                chartSection
                
                // Price Summary Card
                priceSummaryCard
                
                // Transaction History (Varlık Geçmişi)
                transactionHistorySection
                
                // Price History List
                priceHistoryList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPeriodSheet) {
            periodSelectionSheet
        }
        .onAppear {
            loadPriceHistory()
            loadTransactionHistory()

            // Show interstitial ad when detail view opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                interstitialAdManager.showAdIfAvailable()
            }
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fiyat Grafiği")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showPeriodSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: selectedPeriod.icon)
                            .font(.caption)
                        Text(selectedPeriod.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if hasChartData {
                Chart {
                    ForEach(filteredPriceHistory) { entry in
                        LineMark(
                            x: .value("Tarih", entry.date),
                            y: .value("Fiyat", entry.price)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: chartYAxisRange)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.clear)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                emptyChartView
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
        .clipped()
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Grafik göstermek için yeterli veri yok")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Her giriş yaptığınızda fiyat geçmişi kaydedilir")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Price Summary Card
    private var priceSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("İlk Fiyat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(initialPrice.formatAsCurrency())
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Güncel Fiyat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(asset.currentPrice.formatAsCurrency())
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
            }
            
            // Sadece değişim varsa göster
            if hasPriceChange {
                Divider()
                
                HStack {
                    Text("Değişim")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: priceChangePercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        
                        Text(formatPercentage(priceChangePercentage))
                            .font(.title3.weight(.bold))
                    }
                    .foregroundColor(priceChangePercentage >= 0 ? .green : .red)
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
    }

    // MARK: - Transaction History Section
    
    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Varlık Geçmişi")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if transactionHistory.isEmpty {
                emptyTransactionHistoryView
            } else {
                VStack(spacing: 12) {
                    ForEach(transactionHistory) { transaction in
                        transactionHistoryRow(transaction: transaction)
                    }
                }
            }
        }
        .padding(.vertical)
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
    }
    
    private func transactionHistoryRow(transaction: AssetTransactionHistory) -> some View {
        HStack(spacing: 16) {
            // Transaction Type Icon
            ZStack {
                Circle()
                    .fill(Color(transaction.transactionType.color).opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transaction.transactionType.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(transaction.transactionType.color))
            }
            
            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(transaction.transactionType.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if transaction.transactionType == .add || transaction.transactionType == .remove {
                        Text(transaction.formattedAmount)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(transaction.transactionType == .add ? .green : .red)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(transaction.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if transaction.totalAmount.truncatingRemainder(dividingBy: 1) == 0 {
                        Text("Toplam: \(String(format: "%.0f", transaction.totalAmount)) \(asset.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Toplam: \(String(format: "%.2f", transaction.totalAmount)) \(asset.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Total Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.totalValue.formatAsCurrency())
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("Birim: \(transaction.price.formatAsCurrency())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var emptyTransactionHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Henüz işlem geçmişi bulunmuyor")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Varlık eklemeleri ve güncellemeleri burada görünür")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - Price History List

    private var priceHistoryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fiyat Geçmişi")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if priceHistory.isEmpty {
                emptyHistoryView
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(priceHistory.enumerated()), id: \.element.id) { index, entry in
                        priceHistoryRow(entry: entry, index: index)
                    }
                }
            }
        }
        .padding(.vertical)
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
    }

    // MARK: - Helper Properties

    private var hasPriceChange: Bool {
        return abs(priceChangePercentage) >= 0.01
    }
    
    private func priceHistoryRow(entry: AssetPriceHistory, index: Int) -> some View {
        HStack(spacing: 16) {
            // Date Circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                VStack(spacing: 0) {
                    Text(entry.dayString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(entry.monthString)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // Price Info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.price.formatAsCurrency())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Change Badge
            if index > 0 {
                changeIndicator(currentEntry: entry, previousEntry: priceHistory[index - 1])
            } else {
                // First entry badge
                Text("İlk Kayıt")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal)
    }
    
    private func changeIndicator(currentEntry: AssetPriceHistory, previousEntry: AssetPriceHistory) -> some View {
        let change = ((currentEntry.price - previousEntry.price) / previousEntry.price) * 100
        
        return HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            
            Text(formatPercentage(change))
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(change >= 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((change >= 0 ? Color.green : Color.red).opacity(0.1))
        )
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Henüz fiyat geçmişi bulunmuyor")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Varlığınız her app açılışında otomatik kaydedilir")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }
    
    // MARK: - Period Selection Sheet
    
    private var periodSelectionSheet: some View {
        VStack(spacing: 20) {
            // Handle Bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            // Title
            Text("Grafik Periyodu")
                .font(.title3.bold())
                .padding(.top, 8)
            
            // Period Options
            VStack(spacing: 12) {
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        showPeriodSheet = false
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(selectedPeriod == period ? Color.blue : Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: period.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(selectedPeriod == period ? .white : .secondary)
                            }
                            
                            Text(period.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedPeriod == period {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                                .shadow(
                                    color: selectedPeriod == period ? .blue.opacity(0.3) : .clear,
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedPeriod == period ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .presentationDetents([.height(350)])
        .presentationDragIndicator(.hidden)
    }
    
    // MARK: - Helper Properties & Methods
    private var initialPrice: Double {
        return PortfolioManager.shared.assetPurchasePrices[asset.id] ?? asset.currentPrice
    }

    private var priceChangePercentage: Double {
        guard initialPrice > 0 else { return 0 }
        return ((asset.currentPrice - initialPrice) / initialPrice) * 100
    }
    
    private var filteredPriceHistory: [AssetPriceHistory] {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: now)!
        
        return priceHistory.filter { $0.date >= startDate }
    }
    
    private var hasChartData: Bool {
        return !filteredPriceHistory.isEmpty && filteredPriceHistory.count >= 2
    }
    
    private var chartYAxisRange: ClosedRange<Double> {
        guard !filteredPriceHistory.isEmpty else { return 0...100 }
        
        let prices = filteredPriceHistory.map { $0.price }
        guard let minPrice = prices.min(), let maxPrice = prices.max() else {
            return 0...100
        }
        
        // Eğer tüm fiyatlar aynıysa
        if minPrice == maxPrice {
            let value = minPrice
            return (value * 0.98)...(value * 1.02)
        }
        
        let range = maxPrice - minPrice
        let padding = range * 0.2 // %20 padding
        
        let lowerBound = max(0, minPrice - padding)
        let upperBound = maxPrice + padding
        
        return lowerBound...upperBound
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let absValue = abs(value)
        
        if absValue < 0.01 && value != 0 {
            return "\(value >= 0 ? "+" : "")<0,01%"
        }
        
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }
    
    private func loadPriceHistory() {
        // Gerçek history verilerini SwiftData'dan yükle
        priceHistory = AssetHistoryManager.shared.getHistory(
            for: asset.type,
            context: modelContext
        )
        
        Logger.log("📊 AssetDetailView: Loaded \(priceHistory.count) history entries for \(asset.name)")
    }
    
    private func loadTransactionHistory() {
        // İşlem geçmişini SwiftData'dan yükle
        transactionHistory = AssetHistoryManager.shared.getTransactionHistory(
            for: asset.type,
            context: modelContext
        )
        
        Logger.log("📝 AssetDetailView: Loaded \(transactionHistory.count) transaction entries for \(asset.name)")
    }
}

// MARK: - AssetPriceHistory Extensions for Display

extension AssetPriceHistory {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
    
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Preview

#Preview {
    AssetDetailView(
        asset: Asset(
            type: .gold,
            amount: 10,
            currentRate: 0,
            currentPrice: 2500
        )
    )
}
