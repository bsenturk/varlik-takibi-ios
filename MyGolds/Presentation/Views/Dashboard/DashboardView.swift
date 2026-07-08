//
//  DashboardView.swift
//  MyGolds
//
//  The redesigned "Portföy" tab (v3.0.0): portfolio chips + balance card + asset list.
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @Query private var assets: [Asset]

    @StateObject private var marketDataManager = MarketDataManager.shared
    @StateObject private var portfolioManager = PortfolioManager.shared

    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @AppStorage("selectedPortfolioID") private var selectedPortfolioIDString: String = ""

    @State private var editorMode: EditorMode?
    @State private var assetToDelete: Asset?
    @State private var assetToEdit: Asset?
    @State private var showingDeletePopup = false
    @State private var showingPaywall = false

    /// Non-Pro users can keep at most this many real (non-Genel) portfolios.
    private let freePortfolioLimit = 2

    private enum EditorMode: Identifiable {
        case create
        case edit(Portfolio)
        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let p): return "edit-\(p.id.uuidString)"
            }
        }
    }

    // MARK: - Selection

    private var selectedPortfolio: Portfolio? {
        if let id = UUID(uuidString: selectedPortfolioIDString),
           let match = portfolios.first(where: { $0.id == id }) {
            return match
        }
        return portfolios.first(where: { $0.isGeneral }) ?? portfolios.first
    }

    private var isGeneralSelected: Bool { selectedPortfolio?.isGeneral ?? false }

    /// Assets in scope for the current selection.
    private var scopedAssets: [Asset] {
        guard let selected = selectedPortfolio else { return [] }
        if selected.isGeneral { return assets }
        return assets.filter { $0.portfolio?.id == selected.id }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationBarHidden(true)
        }
    }

    private var content: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 14) {
                // Header + chips are pinned (not inside the vertical ScrollView) so the
                // horizontal chips scroll isn't nested — every chip stays tappable.
                header.padding(.horizontal, 18)
                chipsRow

                ScrollView {
                    VStack(spacing: 18) {
                        balanceCard.padding(.horizontal, 18)

                        Group {
                            if scopedAssets.isEmpty {
                                emptyState
                            } else {
                                assetsSection
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .refreshable { await refresh() }
            }
            .padding(.top, 8)

            if showingDeletePopup {
                CustomDeletePopup(
                    assetName: assetToDelete?.name ?? "",
                    isPresented: $showingDeletePopup,
                    onDelete: { if let a = assetToDelete { deleteAsset(a) } }
                )
                .zIndex(900)
            }

            if let mode = editorMode {
                portfolioEditor(for: mode).zIndex(1000)
            }
        }
        .onAppear {
            if selectedPortfolioIDString.isEmpty,
               let general = portfolios.first(where: { $0.isGeneral }) {
                selectedPortfolioIDString = general.id.uuidString
            }
            // Ask for notification permission when the Portföy page opens.
            NotificationManager.shared.requestNotificationPermission()
            Task { await refresh() }

            // Calm moment: ask for an App Store rating if the user is engaged enough.
            // Self-gates (≥3 distinct days + ≥2 assets, once per version, no ad on screen).
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                RatingManager.shared.requestReviewIfAppropriate(assetCount: assets.count)
            }
        }
        .onChange(of: assets) { _, _ in portfolioManager.updatePortfolio(with: assets) }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(onClose: { showingPaywall = false }, context: .portfolioLimit)
        }
        .sheet(item: $assetToEdit) { asset in
            AssetEditSheet(asset: asset, onDeleted: { deleteAsset($0) })
        }
    }

    /// Opens the create-portfolio editor, or the paywall if a non-Pro user is at the limit.
    private func attemptCreatePortfolio() {
        let realCount = portfolios.filter { !$0.isGeneral }.count
        if !UserDefaultsManager.shared.isPro && realCount >= freePortfolioLimit {
            showingPaywall = true
        } else {
            editorMode = .create
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Portföylerim")
                .font(.system(size: 30, weight: .heavy))
            Spacer()
            Button(action: attemptCreatePortfolio) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Chips

    private var chipsRow: some View {
        // Edge-to-edge horizontal scroll with internal padding so the first and last chips
        // can scroll fully into view (and stay tappable). The negative padding cancels the
        // parent VStack's horizontal inset.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(portfolios) { portfolio in
                    PortfolioChip(
                        portfolio: portfolio,
                        isSelected: portfolio.id == selectedPortfolio?.id,
                        showsEditAffordance: false,
                        onTap: { handleChipTap(portfolio) }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 2)
        }
    }

    private func handleChipTap(_ portfolio: Portfolio) {
        if portfolio.id == selectedPortfolio?.id, !portfolio.isGeneral {
            // Tapping the already-selected (non-Genel) chip opens the editor.
            editorMode = .edit(portfolio)
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPortfolioIDString = portfolio.id.uuidString
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Balance card

    private var balanceCard: some View {
        BalanceCardView(
            portfolioColor: selectedPortfolio?.color ?? .blue,
            metrics: PortfolioMetrics.compute(for: scopedAssets, context: modelContext),
            selectedCurrency: $selectedCurrency
        )
    }

    // MARK: - Assets

    private var assetsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Varlıklarım")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Text(countLabel)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)

            ForEach(rowItems) { item in
                Group {
                    if let id = item.assetID, let asset = assets.first(where: { $0.id == id }) {
                        Button {
                            assetToEdit = asset
                        } label: {
                            DashboardRowView(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                assetToEdit = asset
                            } label: { Label("Düzenle", systemImage: "pencil") }
                            Button(role: .destructive) {
                                assetToDelete = asset
                                showingDeletePopup = true
                            } label: { Label("Sil", systemImage: "trash") }
                        }
                    } else {
                        DashboardRowView(item: item)
                    }
                }
            }
        }
    }

    private var countLabel: String {
        let count = isGeneralSelected ? rowItems.count : scopedAssets.count
        return isGeneralSelected ? "\(count) kategori" : "\(count) varlık"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "tray")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 30)

            Text(isGeneralSelected ? "Hadi başlayalım" : "Bu portföy boş")
                .font(.system(size: 20, weight: .bold))
            Text(isGeneralSelected
                 ? "Aşağıdaki + butonuna dokun, ilk varlığını ekle ve portföyünün canlı değerini gör."
                 : "Aşağıdaki + butonuna dokunarak bu portföye varlık ekle.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
    }

    // MARK: - Row item construction

    private var rowItems: [DashboardRowItem] {
        isGeneralSelected ? categoryRowItems() : assetRowItems()
    }

    private func assetRowItems() -> [DashboardRowItem] {
        scopedAssets
            .sorted { $0.totalValue > $1.totalValue }
            .map { asset in
                let spark = AssetHistoryManager.shared
                    .getChartData(for: asset.symbol, days: 30, context: modelContext)
                    .map { $0.price }
                return DashboardRowItem(
                    id: asset.id.uuidString,
                    title: asset.name,
                    subtitle: "\(Self.formatAmount(asset.amount)) \(asset.unit)",
                    value: asset.totalValue,
                    changePercent: profitLossPercent(for: asset),
                    sparkline: spark,
                    icon: asset.type.tileIcon,
                    tintHex: asset.type.tileTintHex,
                    assetID: asset.id
                )
            }
    }

    private func categoryRowItems() -> [DashboardRowItem] {
        let grouped = Dictionary(grouping: assets) { $0.type.category }
        return AssetCategory.allCases.compactMap { category -> DashboardRowItem? in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            let value = items.reduce(0) { $0 + $1.totalValue }
            guard value > 0 else { return nil }

            // Aggregate sparkline + cost basis across all assets in the category.
            var seriesByDay: [Date: Double] = [:]
            var costBasis = 0.0
            let calendar = Calendar.current

            for asset in items {
                let history = AssetHistoryManager.shared.getHistory(for: asset.symbol, context: modelContext)
                for point in history {
                    let day = calendar.startOfDay(for: point.date)
                    seriesByDay[day, default: 0] += asset.amount * point.price
                }
                let cost = PortfolioManager.shared.assetPurchasePrices[asset.id] ?? asset.currentPrice
                costBasis += cost * asset.amount
            }

            let spark = seriesByDay.keys.sorted().map { seriesByDay[$0] ?? 0 }
            let pct = costBasis > 0 ? ((value - costBasis) / costBasis) * 100.0 : 0.0

            return DashboardRowItem(
                id: "cat-\(category.rawValue)",
                title: category.displayName,
                subtitle: "\(items.count) varlık",
                value: value,
                changePercent: pct,
                sparkline: spark,
                icon: category.iconName,
                tintHex: category.tintHex,
                assetID: nil
            )
        }
        .sorted { $0.value > $1.value }
    }

    /// Profit/loss percentage of a holding vs its weighted average cost.
    private func profitLossPercent(for asset: Asset) -> Double {
        guard let cost = PortfolioManager.shared.assetPurchasePrices[asset.id], cost > 0 else { return 0 }
        return ((asset.currentPrice - cost) / cost) * 100.0
    }

    static func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 4
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Portfolio editor

    @ViewBuilder
    private func portfolioEditor(for mode: EditorMode) -> some View {
        switch mode {
        case .create:
            PortfolioEditorView(
                portfolio: nil,
                onSave: { name, color in
                    let new = PortfolioStore.create(name: name, color: color, context: modelContext)
                    selectedPortfolioIDString = new.id.uuidString
                    editorMode = nil
                },
                onDelete: nil,
                onCancel: { editorMode = nil }
            )
        case .edit(let portfolio):
            PortfolioEditorView(
                portfolio: portfolio,
                onSave: { name, color in
                    PortfolioStore.update(portfolio, name: name, color: color, context: modelContext)
                    editorMode = nil
                },
                onDelete: {
                    let wasSelected = portfolio.id == selectedPortfolio?.id
                    PortfolioStore.delete(portfolio, context: modelContext)
                    if wasSelected,
                       let general = portfolios.first(where: { $0.isGeneral }) {
                        selectedPortfolioIDString = general.id.uuidString
                    }
                    editorMode = nil
                },
                onCancel: { editorMode = nil }
            )
        }
    }

    // MARK: - Actions

    @MainActor
    private func refresh() async {
        await marketDataManager.refreshData()
        await updateAssetPrices()
        portfolioManager.updatePortfolio(with: assets)
    }

    @MainActor
    private func updateAssetPrices() async {
        var changed = false
        for asset in assets {
            // Relative threshold: a flat 0.01 TL floor swallowed the entire daily
            // move of sub-TL funds (e.g. ALC at ~0.35 TL moving 0.0014), freezing
            // their price and pinning profit/loss at 0%. Compare proportionally so
            // cheap funds update while pricey assets still skip float noise.
            if let newPrice = currentMarketPrice(for: asset),
               abs(newPrice - asset.currentPrice) > max(asset.currentPrice, 1) * 1e-6 {
                asset.currentPrice = newPrice
                asset.lastUpdated = Date()
                changed = true
            }
        }
        if changed { try? modelContext.save() }
    }

    /// Live price for an asset in TRY, keyed by its `symbol`. Covers gold, FX,
    /// crypto and stocks uniformly (USD-priced instruments converted to TRY).
    private func currentMarketPrice(for asset: Asset) -> Double? {
        if asset.symbol == "TRY" { return 1.0 }
        return marketDataManager.tryPrice(forSymbol: asset.symbol)
    }

    private func deleteAsset(_ asset: Asset) {
        withAnimation(.easeInOut(duration: 0.3)) {
            PortfolioManager.shared.removePurchasePrice(for: asset.id)
            AssetHistoryManager.shared.deleteAllHistory(for: asset.symbol, context: modelContext)
            AssetHistoryManager.shared.deleteAllTransactionHistory(for: asset.symbol, context: modelContext)
            modelContext.delete(asset)
            try? modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let remaining = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                PortfolioManager.shared.forceUpdate(with: remaining)
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
