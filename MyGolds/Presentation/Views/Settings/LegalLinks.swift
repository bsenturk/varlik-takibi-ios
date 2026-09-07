//
//  LegalLinks.swift
//  MyGolds
//
//  Gizlilik politikası ve kullanım koşulları tek yerde.
//
//  Eskiden gizlilik politikası uygulamanın içine gömülü statik bir metindi ve
//  "27 Haziran 2024" tarihini taşıyordu; o tarihten sonra eklenen push token,
//  ATT sonucu ve reklam geliri olayları orada hiç anlatılmıyordu. Metni
//  uygulamayla birlikte yayınlamak, her güncellemede App Store turu
//  gerektiriyor — barındırılan sayfa hem güncel kalıyor hem de App Store
//  Connect'in istediği herkese açık URL'i sağlıyor.
//

import Foundation

enum LegalLinks {
    static let privacy = URL(string: "https://bsenturk.github.io/varliktakibi-legal/privacy.html")!

    /// Otomatik yenilenen abonelik şartlarını (yenilenme, 24 saat içinde iptal,
    /// iade) içerdiği için Apple'ın standart EULA'sının yerine geçiyor —
    /// App Store Review 3.1.2 kendi EULA'nı sunmana izin veriyor.
    static let terms = URL(string: "https://bsenturk.github.io/varliktakibi-legal/terms.html")!
}
