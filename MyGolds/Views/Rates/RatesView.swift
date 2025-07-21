//
//  RatesView.swift - Pull to Refresh Fixed v2
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RatesView: View {
    @StateObject private var viewModel = RatesViewModel()
    @State private var isManuallyRefreshing = false
    
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
                await performRefresh()
            }
            .overlay {
                if (viewModel.isRefreshing || isManuallyRefreshing) && viewModel.currencyRates.isEmpty {
                    ProgressView("Kurlar yükleniyor...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemBackground))
                }
            }
            .alert("Hata", isPresented: Binding<Bool>(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.clearError() }
            )) {
                Button("Tamam") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                // Initial load if no data
                if viewModel.currencyRates.isEmpty && viewModel.goldRates.isEmpty {
                    await performRefresh()
                }
            }
        }
    }
    
    @MainActor
    private func performRefresh() async {
        isManuallyRefreshing = true
        defer { isManuallyRefreshing = false }
        
        Logger.log("📊 RatesView: Starting refresh")
        
        do {
            await viewModel.refreshRates()
            Logger.log("📊 RatesView: Refresh completed successfully")
        } catch {
            Logger.log("📊 RatesView: Refresh failed - \(error.localizedDescription)")
            viewModel.setError("Kurlar güncellenirken hata oluştu: \(error.localizedDescription)")
        }
    }
}
