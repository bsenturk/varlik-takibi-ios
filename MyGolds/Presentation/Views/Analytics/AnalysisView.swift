//
//  AnalysisView.swift
//  MyGolds
//
//  The redesigned "Analiz" tab (v3.0.0): value trend + distribution, scoped to the
//  currently selected portfolio.
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @Query private var assets: [Asset]
    @StateObject private var portfolioManager = PortfolioManager.shared

    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @AppStorage("selectedPortfolioID") private var selectedPortfolioIDString: String = ""
    @State private var range: TimeRange = .month

    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "1H", month = "1A", quarter = "3A", year = "1Y", all = "Tümü"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .all: return 3650
            }
        }
    }

    // MARK: - Selection

    private var selectedPortfolio: Portfolio? {
        if let id = UUID(uuidString: selectedPortfolioIDString),
           let match = portfolios.first(where: { $0.id == id }) { return match }
        return portfolios.first(where: { $0.isGeneral }) ?? portfolios.first
    }

    private var isGeneral: Bool { selectedPortfolio?.isGeneral ?? false }

    private var scopedAssets: [Asset] {
        guard let selected = selectedPortfolio else { return [] }
        return selected.isGeneral ? assets : assets.filter { $0.portfolio?.id == selected.id }
    }

    private var metrics: PortfolioMetrics {
        PortfolioMetrics.compute(for: scopedAssets, context: modelContext)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                // Header + chips pinned so the horizontal chips scroll isn't nested.
                header.padding(.horizontal, 18)
                portfolioChips

                ScrollView {
                    VStack(spacing: 18) {
                        Group {
                            if scopedAssets.isEmpty {
                                emptyState
                            } else {
                                valueCard
                                distributionCard
                                if !topGainers.isEmpty {
                                    moversCard(title: "En Çok Kazandıranlar", assets: topGainers, positive: true)
                                }
                                if !topLosers.isEmpty {
                                    moversCard(title: "En Çok Kaybettirenler", assets: topLosers, positive: false)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.top, 8)
        }
        .onAppear { portfolioManager.updatePortfolio(with: assets) }
    }

    // MARK: - Header

    private var header: some View {
        Text("Analiz")
            .font(.system(size: 30, weight: .heavy))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var portfolioChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(portfolios) { portfolio in
                    PortfolioChip(
                        portfolio: portfolio,
                        isSelected: portfolio.id == selectedPortfolio?.id,
                        showsEditAffordance: false,
                        showsEditPencil: false,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedPortfolioIDString = portfolio.id.uuidString
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
    }

    // MARK: - Value + trend card

    private var valueCard: some View {
        let series = valueSeries()
        let convertedValue = portfolioManager.convertToTargetCurrency(metrics.totalValue, targetCurrency: selectedCurrency)
        // Profit/loss over the SELECTED RANGE drives both the change badge and the
        // chart color, so the number and the graphic always agree (green = up).
        let firstValue = series.first?.value ?? 0
        let lastValue = series.last?.value ?? 0
        let rangeChangePercent = firstValue > 0 ? ((lastValue - firstValue) / firstValue) * 100 : 0
        let isProfit = lastValue >= firstValue
        let trendColor: Color = isProfit ? Color(hex: "#34C759") : Color(hex: "#FF3B30")
        // Require a real stretch of history before showing the range % + chart,
        // so a couple of early snapshots don't render an exaggerated trend.
        let hasEnoughHistory: Bool = {
            guard series.count >= 3,
                  let first = series.first?.date,
                  let last = series.last?.date else { return false }
            let spanDays = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
            return spanDays >= 5
        }()
        return VStack(alignment: .leading, spacing: 14) {
            Text("Güncel Değer")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text(convertedValue.formatAsCurrency(currency: selectedCurrency))
                .font(.system(size: 30, weight: .heavy))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if hasEnoughHistory {
                HStack(spacing: 6) {
                    Image(systemName: isProfit ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                    Text("%\(String(format: "%.2f", abs(rangeChangePercent)).replacingOccurrences(of: ".", with: ","))")
                        .font(.system(size: 14, weight: .semibold))
                    Text(rangeLabel).font(.system(size: 13)).foregroundColor(.secondary)
                }
                .foregroundColor(trendColor)
            }

            if hasEnoughHistory {
                Chart(series, id: \.date) { point in
                    let converted = portfolioManager.convertToTargetCurrency(point.value, targetCurrency: selectedCurrency)
                    AreaMark(x: .value("Tarih", point.date), y: .value("Değer", converted))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [trendColor.opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Tarih", point.date), y: .value("Değer", converted))
                        .foregroundStyle(trendColor)
                        .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 160)
            } else {
                Text("Grafik için yeterli geçmiş veri bulunmuyor.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }

            rangePicker
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var rangeLabel: String {
        switch range {
        case .week: return "Son 1 Hafta"
        case .month: return "Son 1 Ay"
        case .quarter: return "Son 3 Ay"
        case .year: return "Son 1 Yıl"
        case .all: return "Tüm Zamanlar"
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { range = option }
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(range == option ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            range == option
                            ? AnyShapeStyle((selectedPortfolio?.color ?? .blue).color)
                            : AnyShapeStyle(Color(.tertiarySystemBackground))
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Distribution

    private var distributionCard: some View {
        let slices = distribution()
        return VStack(alignment: .leading, spacing: 14) {
            Text("Varlık Dağılımı").font(.system(size: 20, weight: .bold))

            if slices.isEmpty {
                Text("Henüz veri yok").font(.system(size: 14)).foregroundColor(.secondary)
            } else {
                HStack(spacing: 18) {
                    // Donut with center count
                    ZStack {
                        Chart(slices, id: \.name) { slice in
                            SectorMark(
                                angle: .value("Değer", slice.value),
                                innerRadius: .ratio(0.66),
                                angularInset: 2
                            )
                            .foregroundStyle(slice.color)
                            .cornerRadius(4)
                        }
                        .frame(width: 150, height: 150)

                        VStack(spacing: 2) {
                            Text("Tür").font(.system(size: 13)).foregroundColor(.secondary)
                            Text("\(slices.count)").font(.system(size: 26, weight: .heavy))
                        }
                    }

                    // Legend
                    VStack(spacing: 14) {
                        ForEach(slices, id: \.name) { slice in
                            HStack(spacing: 10) {
                                Circle().fill(slice.color).frame(width: 11, height: 11)
                                Text(slice.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer(minLength: 6)
                                Text("%\(String(format: "%.0f", slice.percent))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("Analiz için varlık yok")
                .font(.system(size: 18, weight: .semibold))
            Text("Bu portföye varlık ekleyince analizler burada görünecek.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data

    private func valueSeries() -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -range.days, to: today) ?? today

        var byDay: [Date: Double] = [:]
        for asset in scopedAssets {
            let history = AssetHistoryManager.shared.getHistory(for: asset.symbol, from: start, to: today, context: modelContext)
            for point in history {
                let day = calendar.startOfDay(for: point.date)
                byDay[day, default: 0] += asset.amount * point.price
            }
        }
        return byDay.keys.sorted().map { (date: $0, value: byDay[$0] ?? 0) }
    }

    // MARK: - Movers (gainers / losers)

    private func moversCard(title: String, assets: [Asset], positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 6)

            ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                moverRow(asset)
                if index < assets.count - 1 {
                    Divider().padding(.leading, 78)
                }
            }
        }
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func moverRow(_ asset: Asset) -> some View {
        let pct = assetDayChangePercent(asset)
        let positive = pct >= 0
        let color = positive ? Color(hex: "#34C759") : Color(hex: "#FF3B30")
        let value = portfolioManager.convertToTargetCurrency(asset.totalValue, targetCurrency: selectedCurrency)
        return HStack(spacing: 12) {
            AssetIconTile(icon: asset.type.tileIcon, tintHex: asset.type.tileTintHex, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(value.formatAsCurrency(currency: selectedCurrency))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                Image(systemName: positive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .bold))
                Text("\(positive ? "+" : "−")%\(String(format: "%.2f", abs(pct)).replacingOccurrences(of: ".", with: ","))")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func assetDayChangePercent(_ asset: Asset) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let history = AssetHistoryManager.shared.getHistory(for: asset.symbol, context: modelContext)
        guard let prev = history.filter({ calendar.startOfDay(for: $0.date) < today })
            .sorted(by: { $0.date < $1.date }).last?.price, prev > 0 else { return 0 }
        return ((asset.currentPrice - prev) / prev) * 100.0
    }

    private var topGainers: [Asset] {
        scopedAssets
            .filter { assetDayChangePercent($0) > 0.001 }
            .sorted { assetDayChangePercent($0) > assetDayChangePercent($1) }
            .prefix(3)
            .map { $0 }
    }

    private var topLosers: [Asset] {
        scopedAssets
            .filter { assetDayChangePercent($0) < -0.001 }
            .sorted { assetDayChangePercent($0) < assetDayChangePercent($1) }
            .prefix(3)
            .map { $0 }
    }

    private struct Slice { let name: String; let value: Double; let percent: Double; let color: Color }

    /// Distinct colors assigned by slice order so every slice is visually unique
    /// (gold types all share one tint, which previously made the donut one color).
    private static let slicePalette: [Color] = [
        Color(hex: "#FFB300"), Color(hex: "#34C759"), Color(hex: "#0A84FF"),
        Color(hex: "#AF52DE"), Color(hex: "#FF3B30"), Color(hex: "#F7931A"),
        Color(hex: "#2A9D8F"), Color(hex: "#E63946"), Color(hex: "#5856D6"),
        Color(hex: "#FF9500"), Color(hex: "#30B0C7"), Color(hex: "#8E8E93")
    ]

    private func distribution() -> [Slice] {
        let total = scopedAssets.reduce(0) { $0 + $1.totalValue }
        guard total > 0 else { return [] }

        // Genel: group by category. A specific portfolio: one slice per holding
        // (its real name), so distinct asset types show as distinct slices.
        let raw: [(name: String, value: Double)]
        if isGeneral {
            let grouped = Dictionary(grouping: scopedAssets) { $0.type.category }
            raw = AssetCategory.allCases.compactMap { category in
                guard let items = grouped[category] else { return nil }
                let value = items.reduce(0) { $0 + $1.totalValue }
                guard value > 0 else { return nil }
                return (category.displayName, value)
            }
        } else {
            raw = scopedAssets
                .map { (name: $0.name, value: $0.totalValue) }
                .filter { $0.value > 0 }
        }

        return raw
            .sorted { $0.value > $1.value }
            .enumerated()
            .map { index, item in
                Slice(
                    name: item.name,
                    value: item.value,
                    percent: item.value / total * 100,
                    color: Self.slicePalette[index % Self.slicePalette.count]
                )
            }
    }
}
