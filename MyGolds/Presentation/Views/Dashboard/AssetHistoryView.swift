//
//  AssetHistoryView.swift
//  MyGolds
//
//  Bir varlığın işlem geçmişi — tam ekran, "Varlığı Düzenle"den açılıyor.
//  Her alım için: ne zaman, ne kadar, o gün kaça alındı, bugün kaç ediyor.
//
//  "Bugün" değerleri kaydedilmiyor, canlı fiyattan her çizimde hesaplanıyor;
//  uygulama her açılışta fiyatı yenilediği için ekran kendiliğinden güncel.
//

import SwiftUI
import SwiftData

struct AssetHistoryView: View {
    let asset: Asset

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var marketData = MarketDataManager.shared
    @AppStorage(UserDefaultsManager.maskedPortfoliosKey) private var maskedPortfolios = ""

    /// Yeniden eskiye.
    @State private var transactions: [AssetTransactionHistory] = []

    private var valuesMasked: Bool {
        UserDefaultsManager.isPortfolioMasked(maskedPortfolios, asset.portfolio?.id)
    }

    /// Türk Lirası'nın fiyatı hep 1 — değişim göstermenin anlamı yok.
    private var isTRY: Bool { asset.symbol == "TRY" }

    /// Ev/araba gibi elle girilen varlık: miktar hep 1, anlamlı olan değer.
    private var isManual: Bool { asset.type.isManual }

    private var currentPrice: Double {
        if isTRY { return 1 }
        return marketData.tryPrice(forSymbol: asset.symbol) ?? asset.currentPrice
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                SelectionScreenHeader(
                    title: "İşlem Geçmişi",
                    subtitle: "Ne zaman, ne kadar eklendi, bugün ne ediyor",
                    onClose: { dismiss() }
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        summaryCard
                        if transactions.isEmpty {
                            emptyState
                        } else {
                            list
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            transactions = AssetHistoryManager.shared
                .getTransactionHistory(for: asset, context: modelContext)
                .reversed()
        }
    }

    // MARK: - Özet

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                AssetIconTile(
                    icon: asset.type.tileIcon,
                    tintHex: asset.type.tileTintHex,
                    size: 44,
                    logoURL: marketData.logoURL(forSymbol: asset.symbol)
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)
                    Text(isManual ? asset.type.displayName
                         : "\(Self.format(asset.amount)) \(asset.unit)"
                           + (asset.location.isEmpty ? "" : " · \(asset.location)"))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack(alignment: .top) {
                stat("Güncel Değer", (asset.amount * currentPrice).formatAsCurrency().maskedIfNeeded(valuesMasked))
                Spacer(minLength: 8)
                // Elle girilende fiyat = değer; aynı sayıyı iki kez yazmayalım.
                if !isTRY && !isManual {
                    stat("Güncel Fiyat", currentPrice.formatAsCurrency(), alignment: .center)
                    Spacer(minLength: 8)
                }
                stat("İlk Ekleme", transactions.last?.formattedDate ?? "—", alignment: .trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func stat(_ label: String, _ value: String, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: - Liste

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("İşlemler").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("\(transactions.count) işlem")
                    .font(.system(size: 13)).foregroundColor(.secondary)
            }
            if isManual {
                Text("Bugünkü değer, en son girdiğin değerdir.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            } else if !isTRY {
                Text("Bugünkü değerler güncel fiyattan hesaplanır.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, txn in
                    if index > 0 { Divider().padding(.leading, 60) }
                    row(txn)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func row(_ txn: AssetTransactionHistory) -> some View {
        let tint = Self.tint(for: txn.transactionType)
        let isBuy = txn.transactionType == .initial || txn.transactionType == .add
        let amountLine: String = {
            // Elle girilende "+1 adet" anlamsız: alımda değer satırı yeterli,
            // güncellemede o gün girilen değer gösterilir.
            if isManual { return isBuy ? "" : txn.price.formatAsCurrency().maskedIfNeeded(valuesMasked) }
            // Sadece maliyet düzeltmesi: miktar değişmedi, toplamı göster.
            if txn.transactionType == .edit && txn.amount == 0 {
                return "Toplam \(Self.format(txn.totalAmount)) \(asset.unit)"
            }
            let sign = isBuy ? "+" : (txn.transactionType == .remove ? "−" : "")
            return "\(sign)\(Self.format(txn.amount)) \(asset.unit)"
        }()

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: txn.transactionType.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(tint)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(txn.transactionType.displayName)
                    .font(.system(size: 15, weight: .semibold))
                Text(txn.formattedDate)
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if !amountLine.isEmpty {
                    Text(amountLine)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                if isBuy, txn.amount > 0 {
                    buyValueLine(txn)
                } else if txn.transactionType == .remove, txn.amount > 0, !isTRY {
                    Text("\(txn.price.formatAsCurrency()) / \(asset.unit)")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// "₺1.000 → ₺1.250  +%25" — alındığı gün ne kadardı, bugün ne kadar.
    @ViewBuilder
    private func buyValueLine(_ txn: AssetTransactionHistory) -> some View {
        let then = txn.amount * txn.price
        let now = txn.amount * currentPrice
        if isTRY || txn.price <= 0 {
            Text(then.formatAsCurrency().maskedIfNeeded(valuesMasked))
                .font(.system(size: 12)).foregroundColor(.secondary)
        } else {
            let pct = (currentPrice - txn.price) / txn.price * 100
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(then.formatAsCurrency().maskedIfNeeded(valuesMasked)) → \(now.formatAsCurrency().maskedIfNeeded(valuesMasked))")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("\(pct >= 0 ? "+" : "−")%\(String(format: "%.2f", abs(pct)).replacingOccurrences(of: ".", with: ","))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(pct >= 0 ? .green : .red)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("Henüz işlem yok")
                .font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private static func tint(for type: AssetTransactionHistory.TransactionType) -> Color {
        switch type {
        case .initial: return .blue
        case .add: return .green
        case .remove: return .red
        case .edit: return .orange
        }
    }

    /// Kripto miktarları 8 basamağa kadar anlamlı olabiliyor.
    private static func format(_ v: Double) -> String {
        Double.editableString(v, maxDecimals: 8)
    }
}
