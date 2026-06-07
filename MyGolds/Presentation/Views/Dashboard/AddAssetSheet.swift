//
//  AddAssetSheet.swift
//  MyGolds
//
//  Multi-step "Varlık Ekle" flow: category grid → searchable type list →
//  custom-keypad amount entry + portfolio picker.
//

import SwiftUI
import SwiftData

struct AddAssetSheet: View {
    let targetPortfolio: Portfolio?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @StateObject private var formViewModel = AssetsFormViewModel()

    private enum Step: Equatable {
        case category
        case typeList(AssetCategory)
        case amount(AssetType)
    }

    private enum InputField { case amount, purchasePrice }

    @State private var step: Step = .category
    @State private var searchText = ""
    @State private var amount = ""
    @State private var purchasePrice = ""
    @State private var activeField: InputField = .amount
    @State private var selectedPortfolio: Portfolio?
    @State private var showAlert = false
    @State private var alertMessage = ""

    private var realPortfolios: [Portfolio] { portfolios.filter { !$0.isGeneral } }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider().opacity(0.4)

            switch step {
            case .category:
                categoryGrid
            case .typeList(let category):
                typeList(for: category)
            case .amount(let type):
                amountEntry(for: type)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            selectedPortfolio = targetPortfolio ?? realPortfolios.first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                interstitialAdManager.showAdIfAvailable()
            }
        }
        .alert("Hata", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) {}
        } message: { Text(alertMessage) }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))

            HStack {
                if !isFirstStep {
                    Button(action: goBack) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            Text("Geri").font(.system(size: 16))
                        }
                        .foregroundColor(.primary)
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var title: String {
        switch step {
        case .category: return "Varlık Ekle"
        case .typeList(let category): return category.displayName
        case .amount: return "Varlık Ekle"
        }
    }

    private var isFirstStep: Bool {
        if case .category = step { return true }
        return false
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch step {
            case .amount(let type):
                step = .typeList(type.category)
            case .typeList:
                step = .category
            case .category:
                break
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Step 1: category grid

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(AssetCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { step = .typeList(category) }
                    } label: {
                        VStack(spacing: 12) {
                            AssetIconTile(icon: category.iconName, tintHex: category.tintHex, size: 56)
                            Text(category.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(category.assetTypes.count) tür")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Step 2: type list

    private func typeList(for category: AssetCategory) -> some View {
        let types = category.assetTypes.filter {
            searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
        return VStack(spacing: 0) {
            searchBar
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(types, id: \.self) { type in
                        Button {
                            amount = ""
                            purchasePrice = ""
                            activeField = .amount
                            withAnimation(.easeInOut(duration: 0.2)) { step = .amount(type) }
                        } label: {
                            HStack(spacing: 12) {
                                AssetIconTile(icon: type.tileIcon, tintHex: type.tileTintHex, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(priceLabel(for: type))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Ara", text: $searchText)
                .font(.system(size: 16))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func priceLabel(for type: AssetType) -> String {
        guard let price = formViewModel.getSelectedAsset(from: type.displayName)?.sellPrice,
              !price.isEmpty else { return type.unit }
        return "₺\(price) / \(type.unit)"
    }

    // MARK: - Step 3: amount entry

    private func amountEntry(for type: AssetType) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        AssetIconTile(icon: type.tileIcon, tintHex: type.tileTintHex, size: 34)
                        Text(type.displayName)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.top, 8)

                    // Amount (drives the keypad when active)
                    Button { activeField = .amount } label: {
                        VStack(spacing: 4) {
                            Text("Miktar")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(amount.isEmpty ? "0" : amount)
                                    .font(.system(size: 44, weight: .heavy))
                                    .foregroundColor(amount.isEmpty ? .secondary : .primary)
                                Text(type.unit)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Rectangle()
                                .fill(activeField == .amount ? Color.accentColor : Color.clear)
                                .frame(width: 120, height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    portfolioPicker

                    purchasePriceField(for: type)

                    profitLossPreview(for: type)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)

            Keypad(
                onDigit: appendDigit,
                onComma: appendComma,
                onBackspace: backspace
            )
            .padding(.horizontal, 12)

            saveButton(for: type)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
        }
    }

    // Optional purchase-rate input (price the user paid per unit).
    private func purchasePriceField(for type: AssetType) -> some View {
        Button { activeField = .purchasePrice } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Satın Alınan Kur")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("(Opsiyonel)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if purchasePrice.isEmpty {
                    Text("Güncel kur")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                } else {
                    Text("₺\(purchasePrice)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(activeField == .purchasePrice ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profitLossPreview(for type: AssetType) -> some View {
        if let pl = estimatedProfitLoss(for: type) {
            HStack(spacing: 6) {
                Image(systemName: pl.value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                Text("Tahmini Kâr/Zarar:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("\(pl.value >= 0 ? "+" : "-")\(abs(pl.value).formatAsCurrency()) (%\(String(format: "%.2f", abs(pl.percent)).replacingOccurrences(of: ".", with: ",")))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(pl.value >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var portfolioPicker: some View {
        Menu {
            ForEach(realPortfolios) { portfolio in
                Button {
                    selectedPortfolio = portfolio
                } label: {
                    Label(portfolio.name, systemImage: selectedPortfolio?.id == portfolio.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Text("Portföy").foregroundColor(.secondary)
                Spacer()
                if let selected = selectedPortfolio {
                    Circle().fill(selected.color.color).frame(width: 8, height: 8)
                    Text(selected.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func saveButton(for type: AssetType) -> some View {
        Button(action: { save(type: type) }) {
            Text("Kaydet")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: isValidAmount
                            ? [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")]
                            : [.gray, .gray.opacity(0.8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!isValidAmount)
    }

    // MARK: - Keypad input

    private var isValidAmount: Bool {
        (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 && selectedPortfolio != nil
    }

    private func currentMarketPrice(for type: AssetType) -> Double {
        formViewModel.getSelectedAsset(from: type.displayName)?.sellPrice.parseToDouble() ?? 0.0
    }

    /// Live profit/loss estimate from the entered purchase rate vs the current market rate.
    private func estimatedProfitLoss(for type: AssetType) -> (value: Double, percent: Double)? {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), amountValue > 0,
              let purchase = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")), purchase > 0
        else { return nil }
        let current = currentMarketPrice(for: type)
        guard current > 0 else { return nil }
        let value = (current - purchase) * amountValue
        let percent = (current - purchase) / purchase * 100.0
        return (value, percent)
    }

    private func appendDigit(_ digit: String) {
        let maxDecimals = activeField == .amount ? 4 : 2
        switch activeField {
        case .amount: amount = appended(amount, digit, maxDecimals: maxDecimals)
        case .purchasePrice: purchasePrice = appended(purchasePrice, digit, maxDecimals: maxDecimals)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func appended(_ value: String, _ digit: String, maxDecimals: Int) -> String {
        var s = value
        if s == "0" { s = "" }
        if let commaIndex = s.firstIndex(of: ",") {
            let decimals = s.distance(from: commaIndex, to: s.endIndex) - 1
            if decimals >= maxDecimals { return s }
        }
        return s + digit
    }

    private func appendComma() {
        switch activeField {
        case .amount:
            if !amount.contains(",") { amount = amount.isEmpty ? "0," : amount + "," }
        case .purchasePrice:
            if !purchasePrice.contains(",") { purchasePrice = purchasePrice.isEmpty ? "0," : purchasePrice + "," }
        }
    }

    private func backspace() {
        switch activeField {
        case .amount: if !amount.isEmpty { amount.removeLast() }
        case .purchasePrice: if !purchasePrice.isEmpty { purchasePrice.removeLast() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Save

    private func save(type: AssetType) {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), amountValue > 0 else {
            alertMessage = "Lütfen geçerli bir miktar girin."
            showAlert = true
            return
        }
        guard let portfolio = selectedPortfolio else {
            alertMessage = "Lütfen bir portföy seçin."
            showAlert = true
            return
        }

        let currentPrice = currentMarketPrice(for: type)

        // Use the entered purchase rate as the cost basis when provided; otherwise the current rate.
        let enteredPurchase = Double(purchasePrice.replacingOccurrences(of: ",", with: "."))
        let costBasis = (enteredPurchase != nil && enteredPurchase! > 0) ? enteredPurchase! : currentPrice

        // Merge into an existing asset of the same type within this portfolio, if any.
        let existing = (portfolio.assets ?? []).first(where: { $0.type == type })

        if let existing {
            let oldAmount = existing.amount
            PortfolioManager.shared.updatePurchasePrice(
                for: existing.id,
                oldAmount: oldAmount,
                newAmount: oldAmount + amountValue,
                newPrice: costBasis
            )
            existing.amount += amountValue
            existing.currentPrice = currentPrice
            existing.lastUpdated = Date()
            try? modelContext.save()

            AssetHistoryManager.shared.recordDailySnapshot(for: existing, modelContext: modelContext)
            AssetHistoryManager.shared.recordTransaction(
                assetType: type, transactionType: .add,
                amount: amountValue, totalAmount: existing.amount,
                price: costBasis, context: modelContext
            )
        } else {
            let newAsset = Asset(type: type, amount: amountValue, currentRate: 0.0, currentPrice: currentPrice)
            newAsset.portfolio = portfolio
            PortfolioManager.shared.storePurchasePrice(for: newAsset.id, price: costBasis)
            modelContext.insert(newAsset)
            try? modelContext.save()

            AssetHistoryManager.shared.createInitialSnapshot(for: newAsset, purchasePrice: costBasis, modelContext: modelContext)
            AssetHistoryManager.shared.recordTransaction(
                assetType: type, transactionType: .initial,
                amount: amountValue, totalAmount: amountValue,
                price: costBasis, context: modelContext
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let all = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
            PortfolioManager.shared.forceUpdate(with: all)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}

// MARK: - Custom keypad

private struct Keypad: View {
    let onDigit: (String) -> Void
    let onComma: () -> Void
    let onBackspace: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [",", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button { tap(key) } label: {
                            Text(key)
                                .font(.system(size: 26, weight: .regular))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case ",": onComma()
        case "⌫": onBackspace()
        default: onDigit(key)
        }
    }
}
