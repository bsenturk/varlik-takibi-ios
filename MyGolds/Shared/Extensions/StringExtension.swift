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

    /// Sayı alanlarının temizleyici + biçimleyici çifti. Düzenlenebilir alanda
    /// binlik ayracı OLMAMALI: `parsedAmount` "1.873.746,00"u ayrıştıramaz.
    static func numberSelfCheck() {
        assert("0,25".sanitizedDecimal(maxDecimals: 4) == "0,25")
        assert("1.5".sanitizedDecimal(maxDecimals: 4) == "1,5", "nokta virgüle çevrilmeli")
        assert(",5".sanitizedDecimal(maxDecimals: 4) == "0,5", "baştaki ayraca 0 eklenmeli")
        assert("1,2,3".sanitizedDecimal(maxDecimals: 4) == "1,23", "tek ayraç kalmalı")
        assert("0,123456".sanitizedDecimal(maxDecimals: 4) == "0,1234", "ondalık sınırı")
        assert("12a3₺".sanitizedDecimal(maxDecimals: 2) == "123", "rakam dışı atılmalı")
        assert("7".sanitizedDecimal(maxDecimals: 0) == "7")
        // %g 1e6'dan sonra bilimsel gösterime düşüyordu (3,74749e+06 hatası).
        assert(Double.editableString(3_747_490, maxDecimals: 2) == "3747490",
               "büyük tutar bilimsel gösterime düşmemeli")
        assert(Double.editableString(0.12345678, maxDecimals: 8) == "0,12345678",
               "kripto miktarı kırpılmamalı")
    }
    #endif

    /// Serbest metni tek ondalık ayraçlı bir sayıya indirger: yalnızca rakamlar
    /// ve tek bir ayraç kalır, ondalık basamak sayısı sınırlanır. Sistem
    /// klavyesi ve yapıştırma her şeyi verebildiği için miktar/fiyat alanları
    /// yazıldıkça bundan geçiyor. Bölge ayarına göre "." gelebildiğinden
    /// virgüle çevriliyor — ayrıştırma tarafı virgül bekliyor.
    func sanitizedDecimal(maxDecimals: Int) -> String {
        var out = ""
        var seenSeparator = false
        var decimals = 0
        for ch in self {
            if ch.isNumber {
                if seenSeparator {
                    if decimals == maxDecimals { continue }
                    decimals += 1
                }
                out.append(ch)
            } else if (ch == "," || ch == ".") && !seenSeparator && maxDecimals > 0 {
                seenSeparator = true
                out.append(out.isEmpty ? "0," : ",")
            }
        }
        return out
    }

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
