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

    private var allRates: [RateDisplayModel] {
        viewModel.currencyRates + viewModel.goldRates
    }

    private var filteredRates: [RateDisplayModel] {
        guard !searchText.isEmpty else { return allRates }
        return allRates.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
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
                                isChangeRatePositive: rate.isChangeRatePositive
                            )
                        }
                    }
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
            Text("Güncel Kurlar")
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

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            TextField("Döviz veya altın ara", text: $searchText)
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
                Text("Kurlar yükleniyor...")
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
