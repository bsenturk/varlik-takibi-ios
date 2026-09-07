//
//  Currency.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 19.10.2025.
//
//  Portföy tutarlarının gösterileceği para birimi. Liste, uygulamanın döviz
//  olarak zaten desteklediği kurların tamamı: ad, bayrak ve renk `AssetType.fx`
//  ile aynı kaynaktan okunuyor ki iki liste birbirinden kaymasın.
//

import Foundation

enum Currency: String, CaseIterable, Identifiable {
    case TRY, USD, EUR, GBP, CHF, SAR, CAD, RUB, AED, AUD, DKK, SEK, NOK, JPY, KWD

    var id: String { rawValue }

    // MARK: - Kimlik (tek kaynak: AssetType.fx)

    private static let fxBySymbol: [String: AssetType.FXInfo] =
        Dictionary(uniqueKeysWithValues: AssetType.fx.values.map { ($0.symbol, $0) })

    private var fx: AssetType.FXInfo? { Self.fxBySymbol[rawValue] }

    var flag: String { fx?.flag ?? "🏳️" }

    /// "Dolar", "İsviçre Frangı" …
    var name: String { fx?.name ?? rawValue }

    var tintHex: String { fx?.tintHex ?? "#8E8E93" }

    /// "₺", "$", "CHF" … Locale'in bu kod için kullandığı işaret. Elle tutulan
    /// bir tablo yerine Foundation'dan geliyor: 15 kodun bir kısmında ($, €, ¥)
    /// gerçek bir işaret, kalanında ISO kodunun kendisi doğru olan.
    var symbol: String { Self.makeFormatter(for: self).currencySymbol ?? rawValue }

    var displayName: String { "\(flag) \(rawValue)" }

    // MARK: - Biçimlendirme

    /// Tutarı bu para biriminde biçimlendirir.
    ///
    /// Locale her para biriminde `tr_TR`: uygulama Türkçe ve aynı ekranda ₺
    /// tutarları zaten "1.234,50" biçiminde. Dolar/euro/sterlini "1,234.50"
    /// diye göstermek — eski davranış — aynı kartta iki farklı sayı düzeni
    /// demekti; on beş para biriminde bu iyice tutarsız olurdu.
    func format(_ amount: Double) -> String {
        Self.makeFormatter(for: self).string(from: NSNumber(value: amount)) ?? "\(symbol)0,00"
    }

    private static func makeFormatter(for currency: Currency) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.currencyCode = currency.rawValue
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
}
