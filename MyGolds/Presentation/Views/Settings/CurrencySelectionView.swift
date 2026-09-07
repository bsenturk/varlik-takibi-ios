//
//  CurrencySelectionView.swift
//  MyGolds
//
//  Portföy tutarının gösterileceği para biriminin seçildiği ekran.
//
//  Eskiden hem bakiye kartında hem ayarlarda birer `Menu` vardı; dört seçenekle
//  idare ediyordu ama uygulamanın desteklediği on beş dövizin tamamı açılır
//  menüye sığmıyor ve kur bilgisi gösterilemiyordu. İki giriş noktası da artık
//  bu tek ekranı açıyor.
//

import SwiftUI

struct CurrencySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @StateObject private var marketDataManager = MarketDataManager.shared

    private let brandGradient = LinearGradient(
        colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        header

                        VStack(spacing: 12) {
                            ForEach(Currency.allCases) { currency in
                                currencyOption(currency)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                            Text("Geri").font(.system(size: 17))
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(brandGradient)
                .frame(width: 86, height: 86)
                .overlay(
                    Image(systemName: "dollarsign.arrow.circlepath")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundColor(.white)
                )
                .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 16, x: 0, y: 8)

            VStack(spacing: 6) {
                Text("Para Birimi")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.primary)
                Text("Portföyünün toplam değeri seçtiğin para biriminde gösterilir")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Seçenek

    private func currencyOption(_ currency: Currency) -> some View {
        let isSelected = currency == selectedCurrency
        return Button {
            // Zaten seçili olana tekrar basmak "değişim" değil; loglanırsa
            // currency_changed sayısı şişer.
            guard !isSelected else { dismiss(); return }
            let previous = selectedCurrency
            withAnimation(.easeInOut(duration: 0.2)) { selectedCurrency = currency }
            FirebaseAnalyticsHelper.shared.logCurrencyChanged(
                from: previous.rawValue, to: currency.rawValue
            )
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: currency.tintHex).opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay(Text(currency.flag).font(.system(size: 26)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(currency.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(rateLabel(for: currency))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(currency.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "#0A84FF") : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#0A84FF") : Color.primary.opacity(0.06),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// "1 USD = ₺48,43". Kur henüz yüklenmediyse yalnızca para biriminin adı
    /// kalır — boş bir satır ya da yanıltıcı bir sıfır göstermek yerine.
    private func rateLabel(for currency: Currency) -> String {
        guard currency != .TRY else { return "Ana para birimi" }
        guard let rate = marketDataManager.tryPrice(forSymbol: currency.rawValue), rate > 0
        else { return currency.symbol }
        return "1 \(currency.rawValue) = \(rate.formatAsCurrency(currency: .TRY))"
    }
}
