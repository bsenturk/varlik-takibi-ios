//
//  RatesView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RatesView: View {
    @StateObject private var viewModel = RatesViewModel()
    @StateObject private var marketData = MarketDataManager.shared
    @State private var searchText = ""
    @State private var tab: Tab = .gold

    /// ETF'ler bilerek yok: Pro özelliği, fiyatları da Pro'ya bağlı.
    private enum Tab: String, CaseIterable, Identifiable {
        case gold = "Altın"
        case currency = "Döviz"
        case crypto = "Kripto"
        case bist = "BIST"
        case us = "ABD"

        var id: String { rawValue }

        private var category: AssetCategory {
            switch self {
            case .gold: return .gold
            case .currency: return .currency
            case .crypto: return .crypto
            case .bist: return .bistStock
            case .us: return .usStock
            }
        }
        var tintHex: String { category.tintHex }

        var searchPlaceholder: String {
            switch self {
            case .gold: return "Altın ara"
            case .currency: return "Döviz ara"
            case .crypto: return "Kripto ara"
            case .bist, .us: return "Hisse ara"
            }
        }
    }

    private var allRates: [RateDisplayModel] {
        switch tab {
        case .gold: return viewModel.goldRates
        case .currency: return viewModel.currencyRates
        case .crypto: return viewModel.cryptoRates
        case .bist: return viewModel.bistRates
        case .us: return viewModel.usRates
        }
    }

    private var filteredRates: [RateDisplayModel] {
        guard !searchText.isEmpty else { return allRates }
        return allRates.filter { $0.title.searchMatches(searchText) }
    }

    /// Finans kategorisinde canlı piyasa verisi gösteren bir uygulamada
    /// App Store denetimi veri kaynağı ve tavsiye olmadığı notunu bekliyor.
    /// Aynı metin barındırılan Kullanım Koşulları'nda da var; kullanıcı
    /// fiyatlara baktığı yerde de görmeli.
    private var disclaimer: some View {
        Text("Fiyatlar üçüncü taraf sağlayıcılardan alınır ve gecikmeli olabilir. Bilgilendirme amaçlıdır, yatırım tavsiyesi değildir.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                // Lazy: BIST ~640 satır; hepsini bir anda kurmak sekmeyi
                // açarken takılıyordu.
                LazyVStack(spacing: 14) {
                    header
                    tabChips
                    searchBar

                    if filteredRates.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredRates) { rate in
                            RateCardView(
                                title: rate.title,
                                iconName: rate.iconName,
                                iconColor: rate.iconColor,
                                buyRate: rate.buyRate,
                                sellRate: rate.sellRate,
                                change: rate.change,
                                isChangeRatePositive: rate.isChangeRatePositive,
                                logoURL: rate.logoURL,
                                tintHex: rate.tintHex
                            )
                        }
                    }

                    if !filteredRates.isEmpty { disclaimer }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .refreshable { await viewModel.refreshRates() }
        }
        .alert("Hata", isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.clearError() }
        )) {
            Button("Tamam") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            if allRates.isEmpty { await viewModel.refreshRates() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Piyasalar")
                .font(.system(size: 32, weight: .heavy))
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#34C759"))
                    .frame(width: 8, height: 8)
                Text(liveText)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: marketData.lastUpdateTime ?? Date())
        return "Canlı · \(time) itibarıyla"
    }

    // MARK: - Chips

    /// Beş çip dar ekrana sığmıyor: kendi içinde yatay kayıyor. Sabit HStack
    /// olsaydı sayfayı taşırıp Ayarlar'daki yana kaymanın aynısını yapardı.
    /// Negatif padding kaydırmanın ekran kenarına kadar uzanmasını sağlıyor.
    private var tabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Tab.allCases) { option in
                    let isSelected = tab == option
                    Text(option.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(isSelected ? AnyShapeStyle(Color(hex: option.tintHex)) : AnyShapeStyle(Color(.systemGray5)))
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .onTapGesture {
                            // Arama sekmeye ait: "THY" yazıp Kripto'ya geçen boş liste görmesin.
                            searchText = ""
                            withAnimation(.easeInOut(duration: 0.2)) { tab = option }
                        }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.horizontal, -18)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            TextField(tab.searchPlaceholder, text: $searchText)
                .font(.system(size: 16))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            if allRates.isEmpty {
                ProgressView()
                    .padding(.top, 60)
                Text("Fiyatlar yükleniyor...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                    .padding(.top, 60)
                Text("Sonuç bulunamadı")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
