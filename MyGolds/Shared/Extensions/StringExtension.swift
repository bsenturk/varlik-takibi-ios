//
//  StringExtension.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import Foundation

extension String {
    /// Arama karşılaştırması için harfleri düzleştirir.
    ///
    /// `localizedCaseInsensitiveContains` harf katlamayı cihazın locale'ine
    /// bırakıyor ve Türkçe'de i/I ile ı/İ **ayrı harfler**: "BIT" yazan
    /// kullanıcı Bitcoin'i, "is portföy" yazan "İŞ PORTFÖY..."u bulamıyordu.
    /// Fon adları tamamen büyük harf ve İ dolu olduğu için bu, fon aramasını
    /// doğrudan kırıyordu.
    ///
    /// Aksan katlaması ı↔i çiftini eşitlemiyor (ı, noktası kaldırılmış bir i
    /// değil, ayrı bir kod noktası); o yüzden dört harf önce düz "i"ye
    /// indiriliyor, ardından geri kalan aksanlar Türkçe olmayan bir locale ile
    /// katlanıyor (ş→s, ö→o, ü→u, ç→c, ğ→g).
    var searchFolded: String {
        let unified = replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
        return unified.folding(options: [.caseInsensitive, .diacriticInsensitive],
                               locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Arama kutusundaki sorgu bu metinde geçiyor mu. Boş sorgu her şeyi eşler.
    func searchMatches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return searchFolded.contains(trimmed.searchFolded)
    }

    #if DEBUG
    /// Tek çalıştırılabilir kontrol. Test target'ı yok, bu yüzden launch'ta
    /// assert olarak koşuyor (AdPaywallGate.selfCheck ile aynı kalıp).
    static func searchSelfCheck() {
        let shouldMatch: [(String, String)] = [
            ("Bitcoin", "BIT"), ("Bitcoin", "bıt"), ("Bitcoin", "BİT"),
            ("Ripple", "rıp"),
            ("İŞ PORTFÖY PARA PİYASASI FONU", "is portfoy"),
            ("ZİRAAT PORTFÖY BAŞAK PARA PİYASASI (TL) FONU", "basak"),
            ("Gram Altın", "ALTIN"), ("Çeyrek Altın", "ceyrek"), ("Gümüş", "gumus"),
            ("ASELS.IS", "asels")
        ]
        for (text, query) in shouldMatch {
            assert(text.searchMatches(query), "'\(query)' → '\(text)' eşleşmeliydi")
        }
        assert(!"Bitcoin".searchMatches("doge"), "alakasız sorgu eşleşmemeli")
        assert("Bitcoin".searchMatches(""), "boş sorgu her şeyi eşlemeli")
    }
    #endif

    func parseToDouble() -> Double? {
        let cleanString = self
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
        return Double(cleanString)
    }
}
