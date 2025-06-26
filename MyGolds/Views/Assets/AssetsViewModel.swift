//
//  AssetsViewModel.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 22.02.2024.
//

import SwiftUI
import SwiftSoup
import AppTrackingTransparency

final class AssetsViewModel: ObservableObject {
    @Published var assets = [AssetEntity]()
    @Published var totalAssetValue = ""
    @Published var isLoaderShown = false
    
    private var adDidLoad = false
    private let adCoordinator = AdCoordinator()
    private var assetsValues: [String: String] = [:]
    
    func viewOnAppear() {
        fetchAssets()
        getAssetPrices()
    }
    
    func fetchAssets() {
        guard let assetsEntity = CoreDataStack.shared.fetch(entityName: "AssetEntity") as? [AssetEntity] else { return }
        assets = assetsEntity
    }
    
    func removeAsset(asset: AssetEntity) {
        CoreDataStack.shared.delete(object: asset)
    }
    
    func getAssetPrices() {
        guard let url = URL(string: "https://doviz.com/") else { return }
        let request = URLRequest(url: url)
        isLoaderShown = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self, let data else { return }
            
            if let error {
                print(error)
            }
            
            guard let html = String(data: data, encoding: .utf8) else { return }
            guard let document = try? SwiftSoup.parse(html) else { return }
            
            do {
                let headers = try document.getElementsByClass("market-data")
                
                var assetNames: [String] = []
                var assetValues: [String] = []
                
                for header in headers {
                    let spans = try header.select("span")
                    print(spans.count)
                    for span in spans {
                        let spanNames = try span.getElementsByClass("name")
                        
                        if let spanNameItem = spanNames.first() {
                            let assetName = try spanNameItem.text()
                            assetNames.append(assetName)
                        }
                        
                        let spanValues = try span.getElementsByClass("value")
                        
                        if let spanValueItem = spanValues.first() {
                            let assetValue = try spanValueItem.text()
                            assetValues.append(assetValue)
                        }
                    }
                }
                
                for i in 0..<assetNames.count {
                    let name = assetNames[i]
                    let value = assetValues[i]
                    assetsValues[name] = value
                }
                
                DispatchQueue.main.async {
                    self.calculateTotalPrice()
                    self.isLoaderShown = false
                }
                
            } catch {
                print(error)
            }
            
        }.resume()
    }
    
    func calculateAssetValue(asset: AssetEntity) -> String {
        guard let currency = Currencies(rawValue: asset.currencySymbol ?? "") else { return "" }
        var assetValue = 0.0
        switch currency {
        case .usd:
            assetValue = calculateDolarsPrice(asset: asset)
        case .euro:
            assetValue = calculateEurosPrice(asset: asset)
        case .aux:
            assetValue = calculateGoldsPrice(asset: asset)
        case .gbp:
            assetValue = calculatePoundsPrice(asset: asset)
        case .agx:
            assetValue = calculateSilverPrice(asset: asset)
        }
        
        return "₺\(numberFormatter(value: assetValue))"
    }
    
    private func calculateTotalPrice() {
        var totalPrice = 0.0
        for asset in assets {
            guard let currency = Currencies(rawValue: asset.currencySymbol ?? "") else { continue }
            switch currency {
            case .usd:
                totalPrice += calculateDolarsPrice(asset: asset)
            case .euro:
                totalPrice += calculateEurosPrice(asset: asset)
            case .aux:
                totalPrice += calculateGoldsPrice(asset: asset)
            case .gbp:
                totalPrice += calculatePoundsPrice(asset: asset)
            case .agx:
                totalPrice += calculateSilverPrice(asset: asset)
            }
        }
        
        totalAssetValue = "₺\(numberFormatter(value: totalPrice))"
    }
    
    private func calculateGoldsPrice(asset: AssetEntity) -> Double {
        let goldType = (asset.currencyName ?? "").uppercased()
        let gramGoldName = "GRAM ALTIN"
        guard let gramGoldValue = assetsValues[gramGoldName],
              let gramGoldPrice = formatValues(value: gramGoldValue) else { return .zero }
        let calculatedPrice = GoldCurrencyHelper.getGoldValueFromGramGold(goldType: goldType, gramGoldPrice: gramGoldPrice, quantity: Int(asset.quantity))
        return calculatedPrice
    }
    
    private func calculateDolarsPrice(asset: AssetEntity) -> Double {
        guard let dollarName = asset.currencyName?.uppercased(),
              let dolarValue = assetsValues[dollarName],
              let dolarPrice = formatValues(value: dolarValue) else { return .zero }
        
        return Double(asset.quantity) * dolarPrice
    }
    
    private func calculateEurosPrice(asset: AssetEntity) -> Double {
        guard let euroName = asset.currencyName?.uppercased(),
              let euroValue = assetsValues[euroName],
              let euroPrice = formatValues(value: euroValue) else { return .zero }
        
        return Double(asset.quantity) * euroPrice
    }
    
    private func calculatePoundsPrice(asset: AssetEntity) -> Double {
        guard let poundName = asset.currencyName?.uppercased(with: Locale(identifier: "tr-TR")),
              let poundValue = assetsValues[poundName],
              let poundPrice = formatValues(value: poundValue) else { return .zero }
        
        return Double(asset.quantity) * poundPrice
    }
    
    private func calculateSilverPrice(asset: AssetEntity) -> Double {
        guard let silverName = asset.currencyName?.uppercased(with: Locale(identifier: "tr-TR")),
              let silverValue = assetsValues[silverName],
              let silverPrice = formatValues(value: silverValue) else { return .zero }
        
        return Double(asset.quantity) * silverPrice
    }
    
    private func formatValues(value: String) -> Double? {
        let valueRemovedDot = value.replacingOccurrences(of: ".", with: "")
        let valueWithoutComma = valueRemovedDot.replacingOccurrences(of: ",", with: ".")
        return Double(valueWithoutComma)
    }
    
    private func numberFormatter(value: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencySymbol = ""
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.groupingSize = 3
        numberFormatter.usesGroupingSeparator = true
        
        guard let formattedString = numberFormatter.string(from: NSNumber(floatLiteral: value)) else { return "" }
        return formattedString
    }
    
    func requestTrackingAuthorization() {
        guard !adDidLoad else { return }
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            guard let self else { return }
            
            switch status {
            case .notDetermined:
                break
            case .restricted, .denied:
                loadAd()
                FirebaseEventHelper.sendEvent(event: .trackingNonAuthorized, parameters: nil)
            case .authorized:
                loadAd()
                FirebaseEventHelper.sendEvent(event: .trackingAuthorized, parameters: nil)
            @unknown default: break
            }
        }
    }
    
    private func loadAd() {
        guard !adDidLoad else { return }
        DispatchQueue.main.async {
            self.adCoordinator.loadAd()
            self.adDidLoad = true
        }
    }
}
