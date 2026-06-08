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

    @State private var amountText: String = ""
    @State private var showDeleteConfirm = false

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool { (parsedAmount ?? 0) > 0 }

    private var currentPrice: Double {
        if asset.symbol == "TRY" { return 1 }
        return marketData.tryPrice(forSymbol: asset.symbol) ?? asset.currentPrice
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                amountField
                valuePreview
                Spacer(minLength: 0)
                saveButton
                deleteButton
            }
            .padding(20)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Varlığı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear { amountText = Self.format(asset.amount) }
            .alert("Varlığı Sil", isPresented: $showDeleteConfirm) {
                Button("Sil", role: .destructive) {
                    onDeleted(asset)
                    dismiss()
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("\(asset.name) bu portföyden silinecek. Bu işlem geri alınamaz.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            AssetIconTile(icon: asset.type.tileIcon, tintHex: asset.type.tileTintHex, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name).font(.system(size: 18, weight: .bold))
                Text("Güncel: \(Self.format(asset.amount)) \(asset.unit)")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Miktar").font(.system(size: 14)).foregroundColor(.secondary)
            HStack {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .bold))
                Text(asset.unit).foregroundColor(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var valuePreview: some View {
        let value = (parsedAmount ?? 0) * currentPrice
        return HStack {
            Text("Güncel Değer").foregroundColor(.secondary)
            Spacer()
            Text(value.formatAsCurrency()).font(.system(size: 16, weight: .bold))
        }
        .padding(.horizontal, 4)
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
        guard let newAmount = parsedAmount, newAmount > 0 else { return }
        let oldAmount = asset.amount
        let price = currentPrice
        let delta = newAmount - oldAmount

        PortfolioManager.shared.updatePurchasePrice(
            for: asset.id, oldAmount: oldAmount, newAmount: newAmount, newPrice: price
        )
        asset.amount = newAmount
        asset.currentPrice = price
        asset.lastUpdated = Date()
        try? modelContext.save()

        let txnType: AssetTransactionHistory.TransactionType =
            delta > 0 ? .add : (delta < 0 ? .remove : .edit)
        AssetHistoryManager.shared.recordTransaction(
            symbol: asset.symbol, assetType: asset.type, transactionType: txnType,
            amount: abs(delta), totalAmount: newAmount, price: price, context: modelContext
        )
        AssetHistoryManager.shared.recordDailySnapshot(for: asset, modelContext: modelContext)

        let all = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
        PortfolioManager.shared.forceUpdate(with: all)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private static func format(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%g", v)
    }
}
