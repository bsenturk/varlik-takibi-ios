//
//  Parser.swift - Cancel Protection Added
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//
import SwiftSoup
import SwiftUI

class Parser: ObservableObject {
    @Published var goldPrices: [AssetsPrice] = []
    @Published var currencyRates: [AssetsPrice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let goldURL = "https://altin.doviz.com"
    private let currencyURL = "https://kur.doviz.com"
    
    // Cancel protection
    private var currentFetchTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    func fetchAllData() async {
        // Cancel önceki task
        currentFetchTask?.cancel()
        
        currentFetchTask = Task {
            await performFetchAll()
        }
        
        await currentFetchTask?.value
    }
    
    @MainActor
    private func performFetchAll() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        guard !Task.isCancelled else {
            Logger.log("📊 Parser: Fetch cancelled before start")
            return
        }
        
        async let goldData = fetchGoldPrices()
        async let currencyData = fetchCurrencyRates()
        
        let (gold, currency) = await (goldData, currencyData)
        
        guard !Task.isCancelled else {
            Logger.log("📊 Parser: Fetch cancelled after completion")
            return
        }
        
        self.goldPrices = gold
        self.currencyRates = currency
    }
    
    func fetchGoldPrices() async -> [AssetsPrice] {
        guard !Task.isCancelled else {
            Logger.log("📊 Parser: Gold fetch cancelled")
            return []
        }
        
        do {
            let htmlContent = try await fetchHTML(from: goldURL)
            
            guard !Task.isCancelled else {
                Logger.log("📊 Parser: Gold fetch cancelled after HTML")
                return []
            }
            
            return parseGoldPrices(html: htmlContent)
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.errorMessage = "Altın fiyatları alınırken hata: \(error.localizedDescription)"
                }
            }
            return []
        }
    }
    
    func fetchCurrencyRates() async -> [AssetsPrice] {
        guard !Task.isCancelled else {
            Logger.log("📊 Parser: Currency fetch cancelled")
            return []
        }
        
        do {
            let htmlContent = try await fetchHTML(from: currencyURL)
            
            guard !Task.isCancelled else {
                Logger.log("📊 Parser: Currency fetch cancelled after HTML")
                return []
            }
            
            return parseCurrencyRates(html: htmlContent)
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.errorMessage = "Döviz kurları alınırken hata: \(error.localizedDescription)"
                }
            }
            return []
        }
    }
    
    // MARK: - Private Methods
    private func fetchHTML(from urlString: String) async throws -> String {
        guard !Task.isCancelled else {
            throw URLError(.cancelled)
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("tr-TR,tr;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 10 // 10 saniye timeout
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard !Task.isCancelled else {
            throw URLError(.cancelled)
        }
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return htmlString
    }
    
    private func parseGoldPrices(html: String) -> [AssetsPrice] {
        guard !Task.isCancelled else { return [] }
        
        var goldPrices: [AssetsPrice] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Altın tablosunu bul
            let goldTable = try doc.select("table.data-table, .market-data-table, table[data-type='gold']").first()
            
            // Eğer tablo bulunamazsa, farklı selectors dene
            let tableSelector = goldTable != nil ? "table.data-table" : "table"
            let rows = try doc.select("\(tableSelector) tbody tr, table tr")
            
            for row in rows.array() {
                guard !Task.isCancelled else { break }
                
                do {
                    let cells = try row.select("td")
                    
                    if cells.array().count >= 4 {
                        let nameElement = cells.get(0)
                        let name = try nameElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Altın isimlerini filtrele
                        if isGoldName(name) {
                            let buyPrice = try cells.get(1).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            let sellPrice = try cells.get(2).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            var change = ""
                            var changePercent = ""
                            
                            if cells.array().count > 3 {
                                change = try cells.get(3).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            if cells.array().count > 4 {
                                changePercent = try cells.get(4).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            let goldPrice = AssetsPrice(
                                name: name,
                                code: nil,
                                buyPrice: buyPrice,
                                sellPrice: sellPrice,
                                change: change,
                                changePercent: changePercent,
                                lastUpdate: Date()
                            )
                            
                            goldPrices.append(goldPrice)
                        }
                    }
                } catch {
                    continue // Bu satırı atla ve devam et
                }
            }
            
        } catch {
            Logger.log("Altın parsing hatası: \(error)")
        }
        
        return goldPrices
    }
    
    private func parseCurrencyRates(html: String) -> [AssetsPrice] {
        guard !Task.isCancelled else { return [] }
        
        var currencyRates: [AssetsPrice] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Döviz tablosunu bul
            let currencyTable = try doc.select("table.data-table, .market-data-table, table[data-type='currency']").first()
            
            let tableSelector = currencyTable != nil ? "table.data-table" : "table"
            let rows = try doc.select("\(tableSelector) tbody tr, table tr")
            
            for row in rows.array() {
                guard !Task.isCancelled else { break }
                
                do {
                    let cells = try row.select("td")
                    
                    if cells.array().count >= 4 {
                        let nameElement = cells.get(0)
                        let name = try nameElement.text().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Döviz isimlerini filtrele
                        if isCurrencyName(name) {
                            let buyPrice = try cells.get(1).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            let sellPrice = try cells.get(2).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            var change = ""
                            var changePercent = ""
                            
                            if cells.array().count > 3 {
                                change = try cells.get(3).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            if cells.array().count > 4 {
                                changePercent = try cells.get(4).text().trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            // Döviz kodunu çıkar
                            let code = extractCurrencyCode(from: name)
                            
                            let currencyRate = AssetsPrice(
                                name: name,
                                code: code,
                                buyPrice: buyPrice,
                                sellPrice: sellPrice,
                                change: change,
                                changePercent: changePercent,
                                lastUpdate: Date()
                            )
                            
                            currencyRates.append(currencyRate)
                        }
                    }
                } catch {
                    Logger.log("Currency row parsing error: \(error)")
                    continue
                }
            }
            
        } catch {
            Logger.log("Döviz parsing hatası: \(error)")
        }
        
        return currencyRates
    }
    
    // MARK: - Helper Methods
    private func isGoldName(_ name: String) -> Bool {
        let goldKeywords = [
            "gram altın", "çeyrek altın", "yarım altın", "tam altın",
            "cumhuriyet altını", "ata altın", "beşli altın", "hamit altın", "reşat altın", "gram gümüş"
        ]
        
        let lowercaseName = name.lowercased()
        return !goldKeywords.filter { $0 == lowercaseName }.isEmpty
    }
    
    private func isCurrencyName(_ name: String) -> Bool {
        let currencyKeywords = [
            "USD", "EUR", "GBP"
        ]
        
        let uppercaseName = name.uppercased()
        return currencyKeywords.contains { uppercaseName.contains($0) }
    }
    
    private func extractCurrencyCode(from name: String) -> String {
        let codes = ["USD", "EUR", "GBP"]
        
        for code in codes {
            if name.uppercased().contains(code) {
                return code
            }
        }
        
        // Eğer kod bulunamazsa, ilk kelimeyi döndür
        return String(name.prefix(3)).uppercased()
    }
}
