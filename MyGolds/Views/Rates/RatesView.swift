//
//  RatesView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RatesView: View {
    @StateObject private var viewModel = RatesViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Group {
                        ForEach(viewModel.currencyRates) { rate in
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
                    Group {
                        ForEach(viewModel.goldRates) { rate in
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
                .padding()
            }
            .navigationTitle("Güncel Kurlar")
            .refreshable {
                await viewModel.refreshRates()
            }
            .overlay {
                if viewModel.isRefreshing && viewModel.currencyRates.isEmpty {
                    ProgressView("Kurlar yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                }
            }
            .alert("Hata", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("Tamam") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}
