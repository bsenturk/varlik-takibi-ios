//
//  CurrencySelectionView.swift
//  MyGolds
//
//  Portföy tutarının gösterileceği para biriminin seçildiği ekran.
//
//  Eskiden hem bakiye kartında hem ayarlarda birer `Menu` vardı; dört seçenekle
//  idare ediyordu ama uygulamanın desteklediği on beş dövizin tamamı açılır
//  menüye sığmıyor ve kur bilgisi gösterilemiyordu. İki giriş noktası da artık
//  bu tek ekranı tam ekran açıyor.
//
//  Tasarım kasten sade: tek bir liste, satır başına tek bir karar. Seçili olan
//  dışında hiçbir satırda işaret yok — boş daireler on beş satırda görsel
//  gürültüye dönüşüyor ve hangisinin seçili olduğunu okumayı zorlaştırıyordu.
//

import SwiftUI

struct CurrencySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @StateObject private var marketDataManager = MarketDataManager.shared

    private let accent = Color(hex: "#0A84FF")

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                list
            }
        }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Para Birimi")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.primary)
                Text("Portföyün bu para biriminde gösterilir")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 16)

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Circle())
                    // Görsel daire 30pt, dokunma hedefi Apple'ın 44pt sınırında.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .offset(x: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Liste

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(Currency.allCases.enumerated()), id: \.element) { index, currency in
                    row(currency)
                    if index < Currency.allCases.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ currency: Currency) -> some View {
        let isSelected = currency == selectedCurrency
        return Button {
            // Zaten seçili olana tekrar basmak "değişim" değil; loglanırsa
            // currency_changed sayısı şişer.
            guard !isSelected else { dismiss(); return }
            let previous = selectedCurrency
            selectedCurrency = currency
            FirebaseAnalyticsHelper.shared.logCurrencyChanged(
                from: previous.rawValue, to: currency.rawValue
            )
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Text(currency.flag)
                    .font(.system(size: 26))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle(for: currency))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "USD · 1 USD = ₺48,43". Kur henüz yüklenmediyse yalnızca kod kalır —
    /// yanıltıcı bir sıfır göstermek yerine.
    private func subtitle(for currency: Currency) -> String {
        guard currency != .TRY else { return "TRY · Ana para birimi" }
        guard let rate = marketDataManager.tryPrice(forSymbol: currency.rawValue), rate > 0
        else { return currency.rawValue }
        return "\(currency.rawValue) · 1 \(currency.rawValue) = \(rate.formatAsCurrency(currency: .TRY))"
    }
}
