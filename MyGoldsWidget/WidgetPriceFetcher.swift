//
//  WidgetPriceFetcher.swift
//  MyGoldsWidget
//
//  Widget'ın kendi fiyat çekimi. Supabase SDK'sı extension'a linklenmiyor —
//  `assets_prices` tablosu anon key ile salt okunur (RLS yalnızca SELECT'e
//  izin veriyor), dolayısıyla düz bir PostgREST GET'i yetiyor.
//
//  TRY fiyat kuralı `MarketDataManager.tryPrice(forSymbol:)` ile birebir aynı:
//  önce TRY satırı, yoksa USD satırı × canlı USD kuru.
//

import Foundation

enum WidgetPriceFetcher {

    private static let endpoint = "https://bpiclzhpxkmnqxqvlnmu.supabase.co/rest/v1/assets_prices"
    /// Public anon key — uygulamadaki `SupabaseManager` ile aynı.
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwaWNsemhweGttbnF4cXZsbm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4MTc5MDksImV4cCI6MjA5NjM5MzkwOX0.lgCoFANxEdZ2MCe0TM3VjCaCrwhPfETXPmc4UNtdxrU"

    fileprivate struct Row: Decodable {
        let symbol: String
        let currency: String
        let price: Double
    }

    /// Çekilen fiyatların sorgulanabilir hâli.
    struct Quotes {
        private let rows: [Row]

        fileprivate init(_ rows: [Row]) { self.rows = rows }

        static let empty = Quotes([])
        var isEmpty: Bool { rows.isEmpty }

        /// 1 USD kaç TRY.
        private var usdToTry: Double? {
            rows.first { $0.symbol == "USD" && $0.currency == "TRY" }?.price
        }

        /// `symbol`ün TRY cinsinden birim fiyatı.
        func tryPrice(_ symbol: String) -> Double? {
            if symbol == "TRY" { return 1.0 }
            let matches = rows.filter { $0.symbol == symbol }
            guard !matches.isEmpty else { return nil }
            if let tryRow = matches.first(where: { $0.currency == "TRY" }) { return tryRow.price }
            if let usdRow = matches.first(where: { $0.currency == "USD" }), let rate = usdToTry {
                return usdRow.price * rate
            }
            return matches.first?.price
        }

        /// TRY tutarını hedef para birimine çevirir (uygulamadaki
        /// `PortfolioManager.convertToTargetCurrency` ile aynı: kura bölme).
        func convert(_ amountInTRY: Double, to code: String) -> Double {
            guard code != "TRY", let rate = tryPrice(code), rate > 0 else { return amountInTRY }
            return amountInTRY / rate
        }
    }

    /// Verilen sembollerin fiyatlarını çeker. Ağ/parse hatasında boş döner —
    /// çağıran taraf uygulamanın yazdığı son bilinen fiyata düşer.
    static func fetch(symbols: Set<String>) async -> Quotes {
        // USD her zaman lazım: hem USD fiyatlı enstrümanları TRY'ye çevirmek hem
        // de kullanıcı USD görünümündeyse toplamı dönüştürmek için.
        let wanted = symbols.union(["USD"]).filter { $0 != "TRY" }
        guard !wanted.isEmpty else { return .empty }

        var components = URLComponents(string: endpoint)
        let list = wanted.sorted().map { "\"\($0)\"" }.joined(separator: ",")
        components?.queryItems = [
            URLQueryItem(name: "select", value: "symbol,currency,price"),
            URLQueryItem(name: "symbol", value: "in.(\(list))")
        ]
        guard let url = components?.url else { return .empty }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return .empty }
            return Quotes(try JSONDecoder().decode([Row].self, from: data))
        } catch {
            return .empty
        }
    }
}
