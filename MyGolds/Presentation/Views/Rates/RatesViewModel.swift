//
//  RatesViewModel.swift - Error Handling Fixed
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
    @Published var cryptoRates: [RateDisplayModel] = []
    @Published var bistRates: [RateDisplayModel] = []
    @Published var usRates: [RateDisplayModel] = []
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
        updateCurrencyRates(rate: MarketDataManager.shared.currencyRates)
        updateGoldRates(rate: MarketDataManager.shared.goldPrices)
        cryptoRates = mapMarketRates(MarketDataManager.shared.cryptoPrices, icon: "bitcoinsign.circle.fill", hex: "#F7931A")
        bistRates = mapMarketRates(MarketDataManager.shared.bistPrices, icon: "chart.line.uptrend.xyaxis", hex: "#E63946")
        usRates = mapMarketRates(MarketDataManager.shared.usPrices, icon: "building.columns.fill", hex: "#2A9D8F")
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

        MarketDataManager.shared.$cryptoPrices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prices in
                self?.cryptoRates = self?.mapMarketRates(prices, icon: "bitcoinsign.circle.fill", hex: "#F7931A") ?? []
            }
            .store(in: &cancellables)

        MarketDataManager.shared.$bistPrices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prices in
                self?.bistRates = self?.mapMarketRates(prices, icon: "chart.line.uptrend.xyaxis", hex: "#E63946") ?? []
            }
            .store(in: &cancellables)

        MarketDataManager.shared.$usPrices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prices in
                self?.usRates = self?.mapMarketRates(prices, icon: "building.columns.fill", hex: "#2A9D8F") ?? []
            }
            .store(in: &cancellables)

        MarketDataManager.shared.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRefreshing, on: self)
            .store(in: &cancellables)
        
        MarketDataManager.shared.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.setError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func refreshRates() async {
        Logger.log("📊 RatesViewModel: Starting rates refresh")
        errorMessage = nil
        
        Task {
            await MarketDataManager.shared.refreshData()
            Logger.log("📊 RatesViewModel: Rates refreshed successfully")
        }
    }
    
    func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            Logger.log("❌ RatesViewModel Error: \(message)")
        }
    }
    
    func clearError() {
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
    
    func updateCurrencyRates(rate: [AssetsPrice]) {
        let currencyNames: [String: String] = ["USD": "Dolar", "EUR": "Euro", "GBP": "Sterlin"]
        let currenciesIconName: [String: String] = ["USD": "dollarsign.circle.fill", "EUR": "eurosign.circle.fill", "GBP": "sterlingsign.circle.fill"]
        let currenciesColor: [String: Color] = ["USD": Color(hex: "#34C759"), "EUR": Color(hex: "#0A84FF"), "GBP": Color(hex: "#AF52DE")]
        
        currencyRates = rate.compactMap { price -> RateDisplayModel? in
            guard let code = price.code, !code.isEmpty else { return nil }
            
            let title = currencyNames[code] ?? price.name
            let iconName = currenciesIconName[code] ?? "questionmark.circle"
            let iconColor = currenciesColor[code] ?? .gray
            
            return RateDisplayModel(
                title: title,
                iconName: iconName,
                iconColor: iconColor,
                buyRate: price.buyPrice,
                sellRate: price.sellPrice,
                change: price.changePercent,
                isChangeRatePositive: isRateChangePercentagePositive(from: price.changePercent)
            )
        }
    }
    
    /// Maps live crypto / stock instruments (already TRY-priced) to display rows.
    func mapMarketRates(_ rate: [AssetsPrice], icon: String, hex: String) -> [RateDisplayModel] {
        rate.map { price in
            RateDisplayModel(
                title: "\(price.name) (\(price.code ?? ""))",
                iconName: icon,
                iconColor: Color(hex: hex),
                buyRate: price.buyPrice,
                sellRate: price.sellPrice,
                change: price.changePercent,
                isChangeRatePositive: isRateChangePercentagePositive(from: price.changePercent)
            )
        }
    }

    func updateGoldRates(rate: [AssetsPrice]) {
        goldRates = rate
            .sorted { goldRank($0.name) < goldRank($1.name) }
            .map { price -> RateDisplayModel in
                let isSilver = price.code?.lowercased().contains("gumus") == true
                    || normalize(price.name).contains("gumus")
                let iconName = isSilver ? "circle.grid.2x2.fill" : "circle.hexagongrid.fill"
                let iconColor: Color = isSilver ? Color(hex: "#9E9E9E") : Color(hex: "#FFB300")
                return RateDisplayModel(
                    title: price.name,
                    iconName: iconName,
                    iconColor: iconColor,
                    buyRate: price.buyPrice,
                    sellRate: price.sellPrice,
                    change: price.changePercent,
                    isChangeRatePositive: isRateChangePercentagePositive(from: price.changePercent)
                )
            }
    }

    /// Fixed display order for the gold/silver list. Matched by keyword against the
    /// (diacritic-folded, lowercased) rate name so it's robust to "14 Ayar Altın"
    /// vs "14 Ayar Bilezik" style naming differences.
    private static let goldOrderKeys: [[String]] = [
        ["gram altin"],            // Gram Altın
        ["ceyrek"],                // Çeyrek Altın
        ["yarim"],                 // Yarım Altın
        ["tam"],                   // Tam Altın
        ["cumhuriyet"],            // Cumhuriyet Altını
        ["ata"],                   // Ata Altın
        ["14 ayar"],               // 14 Ayar Bilezik
        ["18 ayar"],               // 18 Ayar Bilezik
        ["22 ayar"],               // 22 Ayar Bilezik
        ["iki bucuk", "ikibucuk"], // İkibuçuk Altın
        ["besli"],                 // Beşli Altın
        ["gremse"],                // Gremse Altın
        ["resat"],                 // Reşat Altın
        ["hamit"],                 // Hamit Altın
        ["gumus"]                  // Gram Gümüş
    ]

    private func goldRank(_ name: String) -> Int {
        let n = normalize(name)
        for (index, keys) in Self.goldOrderKeys.enumerated()
        where keys.contains(where: { n.contains($0) }) {
            return index
        }
        return Int.max // unknown names sink to the bottom
    }

    /// Lowercase + map Turkish letters to ASCII ("Çeyrek Altın" -> "ceyrek altin").
    /// Note: `.diacriticInsensitive` folding does NOT turn the dotless "ı" into "i",
    /// so the mapping is done explicitly here.
    private func normalize(_ s: String) -> String {
        let lowered = s.lowercased(with: Locale(identifier: "tr_TR"))
        var result = ""
        result.reserveCapacity(lowered.count)
        for ch in lowered {
            switch ch {
            case "ç": result.append("c")
            case "ğ": result.append("g")
            case "ı": result.append("i")
            case "ö": result.append("o")
            case "ş": result.append("s")
            case "ü": result.append("u")
            case "â": result.append("a")
            case "î": result.append("i")
            case "û": result.append("u")
            default: result.append(ch)
            }
        }
        return result
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
        return !string.contains("-")
    }
}
