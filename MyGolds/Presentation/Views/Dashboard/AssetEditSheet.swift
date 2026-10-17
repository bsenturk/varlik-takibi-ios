//
//  AssetEditSheet.swift
//  MyGolds
//
//  Update the amount of an existing holding, or delete it. Replaces the old
//  read-only AssetDetailView as the row-tap destination.
//

import SwiftUI
import SwiftData

struct AssetEditSheet: View {
    let asset: Asset
    /// Called when the user confirms deletion (the parent owns the delete logic).
    var onDeleted: (Asset) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var marketData = MarketDataManager.shared
    @AppStorage(UserDefaultsManager.maskedPortfoliosKey) private var maskedPortfolios = ""

    /// Varlığın ait olduğu portföyün gözü kapalıysa tutarlar maskelenir.
    private var valuesMasked: Bool {
        UserDefaultsManager.isPortfolioMasked(maskedPortfolios, asset.portfolio?.id)
    }

    @State private var amountText: String = ""
    @State private var costText: String = ""
    @State private var locationText: String = ""
    @State private var nameText: String = ""
    @State private var showDeleteConfirm = false
    @State private var showingHistory = false

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
    private var parsedCost: Double? {
        Double(costText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool { (parsedAmount ?? 0) > 0 }

    /// Türk Lirası is the base currency — it has no editable cost.
    private var isTRY: Bool { asset.symbol == "TRY" }

    /// Ev/araba gibi elle girilen varlık: "Miktar" alanı TL değeri tutuyor,
    /// miktar hep 1.
    private var isManual: Bool { asset.type.isManual }

    private var currentPrice: Double {
        if asset.symbol == "TRY" { return 1 }
        if isManual { return parsedAmount ?? asset.currentPrice }
        return marketData.tryPrice(forSymbol: asset.symbol) ?? asset.currentPrice
    }

    /// Kaydedilecek miktar — elle girilenlerde hep 1.
    private var editedQuantity: Double { isManual ? 1 : (parsedAmount ?? 0) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Varlığı Düzenle")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                header
                amountField
                if isManual {
                    ManualNameField(name: $nameText, example: asset.type.manualNameExample)
                }
                if !isTRY { costField }
                if !isManual {
                    LocationPicker(location: $locationText, suggestions: asset.type.category.locationSuggestions)
                }
                valuePreview
                historyButton
                deleteButton
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        // Küçük ekranda / klavye açıkken Kaydet kaydırmanın dibinde kaybolmasın.
        .safeAreaInset(edge: .bottom) {
            saveButton
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            amountText = isManual ? Self.formatPrice(asset.currentPrice) : Self.format(asset.amount)
            costText = averageCost.map { Self.formatPrice($0) } ?? ""
            locationText = asset.location
            // Tür adıyla aynıysa isim verilmemiş demektir; alan boş açılsın.
            nameText = asset.name == asset.type.displayName ? "" : asset.name
        }
        .fullScreenCover(isPresented: $showingHistory) { AssetHistoryView(asset: asset) }
        .alert("Varlığı Sil", isPresented: $showDeleteConfirm) {
            Button("Sil", role: .destructive) {
                onDeleted(asset)
                dismiss()
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("\(asset.name) bu portföyden silinecek. Bu işlem geri alınamaz.")
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            AssetIconTile(
                icon: asset.type.tileIcon,
                tintHex: asset.type.tileTintHex,
                size: 44,
                logoURL: marketData.logoURL(forSymbol: asset.symbol)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isManual ? asset.type.displayName : "Güncel: \(Self.format(asset.amount)) \(asset.unit)")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isManual ? "Güncel Değer" : "Miktar").font(.system(size: 14)).foregroundColor(.secondary)
            HStack {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .bold))
                    .onChange(of: amountText) { _, new in
                        let clean = new.sanitizedDecimal(maxDecimals: isManual ? 2 : 8)
                        if clean != new { amountText = clean }
                    }
                Text(isManual ? "₺" : asset.unit).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// Average cost / average buy rate per unit (weighted), if recorded.
    private var averageCost: Double? {
        PortfolioManager.shared.assetPurchasePrices[asset.id]
    }

    /// Label differs by asset class: stocks/crypto/funds = "cost", gold/FX = "rate".
    private var costLabel: String {
        if isManual { return asset.type.manualCostLabel }
        return asset.type.category.isDynamic ? "Ortalama Maliyet" : "Ortalama Alış Kuru"
    }

    /// Editable weighted-average cost / buy rate per unit.
    private var costField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(costLabel).font(.system(size: 14)).foregroundColor(.secondary)
            HStack {
                Text("₺").font(.system(size: 22, weight: .semibold)).foregroundColor(.secondary)
                TextField("0", text: $costText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold))
                    .onChange(of: costText) { _, new in
                        let clean = new.sanitizedDecimal(maxDecimals: 2)
                        if clean != new { costText = clean }
                    }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var valuePreview: some View {
        let amount = editedQuantity
        let value = amount * currentPrice
        // Profit/loss vs the (edited) average cost.
        let cost = parsedCost ?? averageCost
        let profitLoss: (value: Double, percent: Double)? = {
            guard !isTRY, let cost, cost > 0, amount > 0 else { return nil }
            let v = (currentPrice - cost) * amount
            let p = (currentPrice - cost) / cost * 100
            return (v, p)
        }()

        return VStack(spacing: 0) {
            infoRow("Güncel Değer", value.formatAsCurrency().maskedIfNeeded(valuesMasked))
            if let pl = profitLoss {
                Divider().padding(.leading, 16)
                HStack {
                    Text("Kâr / Zarar").foregroundColor(.secondary)
                    Spacer()
                    Text("\(pl.value >= 0 ? "+" : "-")\(abs(pl.value).formatAsCurrency().maskedIfNeeded(valuesMasked)) (%\(String(format: "%.2f", abs(pl.percent)).replacingOccurrences(of: ".", with: ",")))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(pl.value >= 0 ? .green : .red)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 16, weight: .bold))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - History

    private var historyButton: some View {
        Button { showingHistory = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("İşlem Geçmişi")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Kaydet")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(isValid ? Color.accentColor : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isValid)
    }

    private var deleteButton: some View {
        Button(role: .destructive) { showDeleteConfirm = true } label: {
            Text("Varlığı Sil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity).frame(height: 48)
        }
    }

    // MARK: - Actions

    private func save() {
        guard (parsedAmount ?? 0) > 0 else { return }
        let newAmount = editedQuantity
        let oldAmount = asset.amount
        let price = currentPrice
        let delta = newAmount - oldAmount

        asset.amount = newAmount
        if isManual {
            let name = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            asset.name = name.isEmpty ? asset.type.displayName : String(name.prefix(ManualNameField.maxLength))
        } else {
            asset.location = LocationPicker.normalized(locationText)
        }
        asset.currentPrice = price
        asset.lastUpdated = Date()

        // Persist the (possibly edited) average cost directly — the user sets it
        // explicitly here rather than it being a weighted average of buys.
        if !isTRY, let newCost = parsedCost, newCost > 0 {
            PortfolioManager.shared.storePurchasePrice(for: asset.id, price: newCost)
        }
        try? modelContext.save()

        let txnType: AssetTransactionHistory.TransactionType =
            delta > 0 ? .add : (delta < 0 ? .remove : .edit)
        AssetHistoryManager.shared.recordTransaction(
            for: asset, transactionType: txnType,
            amount: abs(delta), totalAmount: newAmount, price: price, context: modelContext
        )
        AssetHistoryManager.shared.recordDailySnapshot(for: asset, modelContext: modelContext)

        let all = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
        PortfolioManager.shared.forceUpdate(with: all)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    /// Miktar gösterimi. Kripto miktarları 8 basamağa kadar anlamlı olabiliyor.
    private static func format(_ v: Double) -> String {
        Double.editableString(v, maxDecimals: 8)
    }

    /// Price/cost formatted with a comma decimal for the editable field.
    private static func formatPrice(_ v: Double) -> String {
        Double.editableString(v, maxDecimals: 2)
    }
}
