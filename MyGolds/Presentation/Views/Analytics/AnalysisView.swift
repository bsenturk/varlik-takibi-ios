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
    @AppStorage(UserDefaultsManager.maskedPortfoliosKey) private var maskedPortfolios = ""
    @AppStorage("selectedPortfolioID") private var selectedPortfolioIDString: String = ""
    @State private var range: TimeRange = .month
    @State private var showingPaywall = false

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

    /// Pro bitince kilitlenen portföyler (bkz. ProLock).
    private var lockedPortfolioIDs: Set<UUID> { ProLock.lockedPortfolioIDs(portfolios) }

    private var selectedPortfolio: Portfolio? {
        if let id = UUID(uuidString: selectedPortfolioIDString),
           let match = portfolios.first(where: { $0.id == id }),
           !lockedPortfolioIDs.contains(match.id) { return match }
        return portfolios.first(where: { $0.isGeneral }) ?? portfolios.first
    }

    private var isGeneral: Bool { selectedPortfolio?.isGeneral ?? false }

    /// Seçili portföyün gözü kapalıysa tutarlar maskelenir (Portföy sekmesiyle aynı tercih).
    private var valuesMasked: Bool {
        UserDefaultsManager.isPortfolioMasked(maskedPortfolios, selectedPortfolio?.id)
    }

    private var scopedAssets: [Asset] {
        guard let selected = selectedPortfolio else { return [] }
        // Analiz baştan sona tutar ve oran gösterir; kilitli varlık hiçbirine girmez.
        let visible = ProLock.unlocked(assets, portfolios: portfolios)
        return selected.isGeneral ? visible : visible.filter { $0.portfolio?.id == selected.id }
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
                                    moversCard(title: "En Çok Yükselenler", assets: topGainers, positive: true)
                                }
                                if !topLosers.isEmpty {
                                    moversCard(title: "En Çok Düşenler", assets: topLosers, positive: false)
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
        .onAppear {
            portfolioManager.updatePortfolio(with: ProLock.unlocked(assets, portfolios: portfolios))
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(onClose: { showingPaywall = false }, context: .portfolioLimit)
        }
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
                        isLocked: lockedPortfolioIDs.contains(portfolio.id),
                        onTap: {
                            guard !lockedPortfolioIDs.contains(portfolio.id) else {
                                // Haptic her dokunuşta; paywall frekans tavanına
                                // tabi (dashboard'daki kilitli çiple aynı kural).
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                if FeatureGatePaywall.shouldShow() { showingPaywall = true }
                                return
                            }
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
        // Profit/loss is measured against the COST BASIS (what the user paid), not the
        // raw range value change: adding a new asset raises value and cost basis by
        // the same amount, so it must NOT read as profit. A raw value-change % counts
        // deposits as gains and explodes when several assets are added (e.g. %39600).
        let plPercent = metrics.profitLossPercent
        let isProfit = metrics.profitLoss >= 0
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
            Text(convertedValue.formatAsCurrency(currency: selectedCurrency).maskedIfNeeded(valuesMasked))
                .font(.system(size: 30, weight: .heavy))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if metrics.hasProfitLoss {
                HStack(spacing: 6) {
                    Image(systemName: isProfit ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                    Text("%\(String(format: "%.2f", abs(plPercent)).replacingOccurrences(of: ".", with: ","))")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Kar/Zarar").font(.system(size: 13)).foregroundColor(.secondary)
                }
                .foregroundColor(trendColor)
            }

            if hasEnoughHistory {
                Chart(downsample(series), id: \.date) { point in
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
                                Text(Self.percentLabel(slice.percent))
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

    /// Daily portfolio-value series for the selected range, sourced from
    /// `PortfolioSnapshot` (uncapped, and built with the *historical* holdings by
    /// the Time Machine — so past days aren't valued with today's amounts). For
    /// "Genel" we sum snapshots across all real portfolios per day. The final
    /// point is pinned to the live total so the chart ends at the current value.
    private func valueSeries() -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let rangeStart = calendar.date(byAdding: .day, value: -range.days, to: today) ?? today

        // Never chart value from before the user actually held any of their CURRENT
        // assets: clamp the window to the earliest current-holding date. This drops
        // stale snapshots left over from a previous holdings composition (e.g. assets
        // that were replaced), which would otherwise value past days on holdings the
        // user no longer owns and produce a nonsensical range % (e.g. −94%).
        let earliestHoldingDay = scopedAssets
            .map { calendar.startOfDay(for: $0.dateAdded) }
            .min()
        let start = max(rangeStart, earliestHoldingDay ?? rangeStart)

        let snapshots: [PortfolioSnapshot]
        if isGeneral {
            snapshots = portfolios
                .filter { !$0.isGeneral && !lockedPortfolioIDs.contains($0.id) }
                .flatMap { $0.snapshots ?? [] }
        } else {
            snapshots = selectedPortfolio?.snapshots ?? []
        }

        var byDay: [Date: Double] = [:]
        for snap in snapshots {
            let day = calendar.startOfDay(for: snap.date)
            guard day >= start && day <= today else { continue }
            byDay[day, default: 0] += snap.totalValue
        }

        // Pin the most recent point to the live total (snapshots are once/day).
        let liveValue = metrics.totalValue
        if liveValue > 0 { byDay[today] = liveValue }

        // Drop days we couldn't value (totalValue 0): the Time Machine stores a 0
        // when historical prices were unavailable, and a leading 0 would both flatten
        // the chart to the baseline and collapse the range % to "%0,00" (firstValue 0),
        // contradicting the dashboard's cost-basis P/L.
        return byDay.keys.sorted()
            .map { (date: $0, value: byDay[$0] ?? 0) }
            .filter { $0.value > 0 }
    }

    /// Downsample a daily series so long ranges stay readable: weekly buckets for
    /// 3A, monthly for 1Y/Tümü (keeping the latest point in each bucket). 1H/1A
    /// stay daily.
    private func downsample(_ series: [(date: Date, value: Double)]) -> [(date: Date, value: Double)] {
        let component: Calendar.Component?
        switch range {
        case .week, .month: component = nil
        case .quarter: component = .weekOfYear
        case .year, .all: component = .month
        }
        guard let comp = component, series.count > 2 else { return series }

        let calendar = Calendar.current
        var byBucket: [Date: (date: Date, value: Double)] = [:]
        for point in series {
            let key = calendar.dateInterval(of: comp, for: point.date)?.start
                ?? calendar.startOfDay(for: point.date)
            if let existing = byBucket[key], existing.date >= point.date { continue }
            byBucket[key] = point
        }
        return byBucket.values.sorted { $0.date < $1.date }
    }

    // MARK: - Movers (gainers / losers)

    /// Buradaki yüzde **fiyat hareketi**, portföy sekmesindeki ise alış fiyatına
    /// göre kâr/zarar. İkisi aynı varlıkta farklı sayılar veriyor ve rozetler
    /// birebir aynı göründüğü için karışıyordu: eski "Kazandıranlar /
    /// Kaybettirenler" başlıkları para ima ediyordu. Başlık artık hareketi
    /// söylüyor, alt satır da hangi tabana göre olduğunu.
    private func moversCard(title: String, assets: [Asset], positive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .padding(.horizontal, 18)
                .padding(.top, 18)

            Text("Son fiyat değişimine göre")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.top, 2)
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
                Text(value.formatAsCurrency(currency: selectedCurrency).maskedIfNeeded(valuesMasked))
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

    /// Günlük değişimi varlık başına **bir kez** hesaplar. Doğrudan `sorted`
    /// karşılaştırıcısında çağrılınca her karşılaştırma yeni bir geçmiş sorgusu
    /// açıyordu (n log n sorgu); artık n sorgu ve sıralama hazır değerler üzerinde.
    private var dayChanges: [UUID: Double] {
        Dictionary(uniqueKeysWithValues: scopedAssets.map { ($0.id, assetDayChangePercent($0)) })
    }

    private var topGainers: [Asset] {
        let changes = dayChanges
        return scopedAssets
            .filter { (changes[$0.id] ?? 0) > 0.001 }
            .sorted { (changes[$0.id] ?? 0) > (changes[$1.id] ?? 0) }
            .prefix(3)
            .map { $0 }
    }

    private var topLosers: [Asset] {
        let changes = dayChanges
        return scopedAssets
            .filter { (changes[$0.id] ?? 0) < -0.001 }
            .sorted { (changes[$0.id] ?? 0) < (changes[$1.id] ?? 0) }
            .prefix(3)
            .map { $0 }
    }

    private struct Slice { let name: String; let value: Double; let percent: Double; let color: Color }

    /// Distribution by ASSET CLASS (category): all holdings of the same class are
    /// one slice (e.g. the 3 BIST stocks → a single "Borsa İstanbul" slice), so the
    /// "Tür" count reflects asset classes — not individual instruments.
    private func distribution() -> [Slice] {
        let total = scopedAssets.reduce(0) { $0 + $1.totalValue }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: scopedAssets) { $0.type.category }
        return AssetCategory.allCases.compactMap { category -> Slice? in
            guard let items = grouped[category] else { return nil }
            let value = items.reduce(0) { $0 + $1.totalValue }
            guard value > 0 else { return nil }
            return Slice(
                name: category.displayName,
                value: value,
                percent: value / total * 100,
                color: Color(hex: category.tintHex)
            )
        }
        .sorted { $0.value > $1.value }
    }

    /// Percentage label that doesn't mislead: a small-but-present slice shows
    /// "<%1" instead of a flat "%0".
    static func percentLabel(_ p: Double) -> String {
        if p > 0 && p < 1 { return "<%1" }
        return "%\(String(format: "%.0f", p))"
    }
}
