//
//  CurrenciesViewModel.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 30.04.2024.
//

import SwiftUI
import SwiftSoup

final class CurrenciesViewModel: ObservableObject {
    
    // MARK: - Properties
    @Published var isLoaderShown = false
    @Published var currencies: [CurrencyModel] = []
    
    func viewOnAppear() {
        getCurrencies()
    }
    
    // MARK: - Helpers
    func getCurrencies() {
        currencies.removeAll()
        guard let url = URL(string: "https://kur.doviz.com/") else { return }
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
                let headers = try document.getElementsByClass("table sortable")
                let tbody = try headers.select("tbody")
                
                for body in tbody {
                    let tr = try body.select("tr")
                    
                    for currencyFullText in tr {
                        let currencyDetails = try currencyFullText.getElementsByClass("currency-details").select("div")
                        let buyingSellingExhangesValues = try currencyFullText.getElementsByClass("text-bold")
                        
                        guard !currencyDetails.isEmpty(), !buyingSellingExhangesValues.isEmpty() else { continue }
                        
                        let symbol = try currencyDetails[1].text()
                        let name = try currencyDetails[2].text()
                        let buyingPrice = try buyingSellingExhangesValues.first()?.text()
                        let sellingPrice = try buyingSellingExhangesValues[1].text()
                        let exchangeRate = try buyingSellingExhangesValues.last()?.text()
                        
                        guard !symbol.isEmpty && !name.isEmpty, let buyingPrice, !sellingPrice.isEmpty, let exchangeRate else { continue }
                        
                        let currencyModel = CurrencyModel(
                            symbol: symbol,
                            name: name,
                            buyingPrice: buyingPrice,
                            sellingPrice: sellingPrice,
                            exchangeRate: exchangeRate
                        )
                        
                        DispatchQueue.main.async {
                            self.currencies.append(currencyModel)
                        }
                    }
                }
        
            } catch {
                print(error)
            }
            
            DispatchQueue.main.async {
                self.isLoaderShown = false
            }
            
        }.resume()
    }
    
}
