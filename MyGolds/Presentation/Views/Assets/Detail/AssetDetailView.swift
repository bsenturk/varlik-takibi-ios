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
    let asset: Asset
    
    @State private var selectedPeriod: ChartPeriod = .daily
    @State private var showPeriodSheet = false
    @State private var priceHistory: [PriceHistoryEntry] = []
    
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
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chart Section
                chartSection
                
                // Price Summary Card
                priceSummaryCard
                
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
            
            Text("Şuan grafik göstermek için yeterli veri yok")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
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

    // MARK: - Price History List

    private var priceHistoryList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fiyat Geçmişi")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if priceHistory.isEmpty {
                // Sadece ilk ekleme bilgisini göster
                initialPriceHistoryView
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

    // MARK: - Initial Price History View (Geçmiş yoksa)

    private var initialPriceHistoryView: some View {
        HStack(spacing: 16) {
            // Date Circle
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                VStack(spacing: 0) {
                    Text(asset.dateAdded.dayString)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Text(asset.dateAdded.monthString)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            // Price Info
            VStack(alignment: .leading, spacing: 4) {
                Text(initialPrice.formatAsCurrency())
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(asset.dateAdded.formattedDateTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // "İlk Ekleme" Badge
            Text("İlk Ekleme")
                .font(.caption.weight(.semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.1))
                )
        }
        .padding(.horizontal)
    }

    // MARK: - Helper Properties

    private var hasPriceChange: Bool {
        return abs(priceChangePercentage) >= 0.01 // 0.01%'den fazla değişim varsa göster
    }
    
    private func priceHistoryRow(entry: PriceHistoryEntry, index: Int) -> some View {
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
            }
        }
        .padding(.horizontal)
    }
    
    private func changeIndicator(currentEntry: PriceHistoryEntry, previousEntry: PriceHistoryEntry) -> some View {
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
    
    private var filteredPriceHistory: [PriceHistoryEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .daily:
            return priceHistory.filter {
                calendar.isDate($0.date, inSameDayAs: now) ||
                calendar.dateComponents([.day], from: $0.date, to: now).day ?? 0 <= 7
            }
        case .weekly:
            return priceHistory.filter {
                calendar.dateComponents([.weekOfYear], from: $0.date, to: now).weekOfYear ?? 0 <= 4
            }
        case .monthly:
            return priceHistory.filter {
                calendar.dateComponents([.month], from: $0.date, to: now).month ?? 0 <= 6
            }
        }
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
    
    private var xAxisStride: Calendar.Component {
        switch selectedPeriod {
        case .daily: return .hour
        case .weekly: return .day
        case .monthly: return .weekOfYear
        }
    }
    
    private var xAxisDateFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .daily:
            return .dateTime.hour()
        case .weekly:
            return .dateTime.day().month(.abbreviated)
        case .monthly:
            return .dateTime.month(.abbreviated)
        }
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
        let calendar = Calendar.current
        let now = Date()
        
        let daysSinceAdded = calendar.dateComponents([.day], from: asset.dateAdded, to: now).day ?? 0
        
        if daysSinceAdded == 0 {
            priceHistory = [
                PriceHistoryEntry(
                    date: asset.dateAdded,
                    price: initialPrice
                ),
                PriceHistoryEntry(
                    date: now,
                    price: asset.currentPrice
                )
            ]
        } else {
            priceHistory = (0...min(daysSinceAdded, 30)).compactMap { dayOffset in
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return nil }
                
                let progress = Double(daysSinceAdded - dayOffset) / Double(daysSinceAdded)
                let priceDifference = asset.currentPrice - initialPrice
                let price = initialPrice + (priceDifference * progress)
                
                let variance = price * Double.random(in: -0.02...0.02)
                let finalPrice = max(0, price + variance)
                
                return PriceHistoryEntry(
                    date: date,
                    price: finalPrice
                )
            }.reversed()
        }
        
        Logger.log("📊 AssetDetailView: Loaded \(priceHistory.count) price history entries for \(asset.name)")
    }
}

// MARK: - Price History Entry Model

struct PriceHistoryEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let price: Double
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
    
    // Equatable conformance
    static func == (lhs: PriceHistoryEntry, rhs: PriceHistoryEntry) -> Bool {
        return lhs.id == rhs.id
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
