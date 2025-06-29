//
//  RatesViewModel.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import SwiftUI
import Combine

class RatesViewModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var currencyRates: [RateDisplayModel] = []
    @Published var goldRates: [RateDisplayModel] = []
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // MarketDataManager'dan verileri dinle
        MarketDataManager.shared.$currencyRates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rates in
                self?.updateCurrencyRates(rate: rates)
            }
            .store(in: &cancellables)
        
        MarketDataManager.shared.$goldPrices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prices in
                self?.updateGoldRates(rate: prices)
            }
            .store(in: &cancellables)
        
        MarketDataManager.shared.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRefreshing, on: self)
            .store(in: &cancellables)
        
        MarketDataManager.shared.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    @MainActor
    func refreshRates() async {
        await MarketDataManager.shared.refreshData()
    }
    
    func updateCurrencyRates(rate: [AssetsPrice]) {
        let currencyNames: [String: String] = ["USD": "Dolar", "EUR": "Euro", "GBP": "Sterlin"]
        let currenciesIconName: [String: String] = ["USD": "dollarsign.circle", "EUR": "eurosign.circle", "GBP": "sterlingsign.circle"]
        let currenciesColor: [String: Color] = ["USD": .green, "EUR": .blue, "GBP": .purple]
        currencyRates = rate.map { price -> RateDisplayModel  in
            let title = currencyNames[price.code ?? ""] ?? price.name
            let iconName = currenciesIconName[price.code ?? ""] ?? ""
            let iconColor = currenciesColor[price.code ?? ""] ?? .clear
            return RateDisplayModel(
                title: title,
                iconName: iconName,
                iconColor: iconColor,
                buyRate: price.buyPrice,
                sellRate: price.sellPrice,
                change: configureRateChangePercantage(from: price.change),
                isChangeRatePositive: isRateChangePercentagePositive(from: price.change)
            )
        }
    }
    
    func updateGoldRates(rate: [AssetsPrice]) {
        goldRates = rate.map { price -> RateDisplayModel  in
            return RateDisplayModel(
                title: price.name,
                iconName: "circle.hexagongrid.circle",
                iconColor: .yellow,
                buyRate: price.buyPrice,
                sellRate: price.sellPrice,
                change: configureRateChangePercantage(from: price.change),
                isChangeRatePositive: isRateChangePercentagePositive(from: price.change)
            )
        }
    }
    
    private func parseDouble(from string: String) -> Double {
        let cleanString = string.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
        
        return Double(cleanString) ?? 0.0
    }
    
    private func isRateChangePercentagePositive(from string: String) -> Bool {
        if string.contains("-") {
            return false
        }
        return true
    }
    
    private func configureRateChangePercantage(from string: String) -> String {
        let cleanString = string.replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "+", with: "")
        
        return cleanString
    }
}
