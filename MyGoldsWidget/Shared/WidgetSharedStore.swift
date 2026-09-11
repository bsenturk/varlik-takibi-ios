//
//  WidgetSharedStore.swift
//  MyGolds + MyGoldsWidget (iki target'ta da derlenir)
//
//  Widget ile uygulama arasındaki tek temas noktası: App Group'taki paylaşımlı
//  UserDefaults.
//
//  Buraya *hesaplanmış tutar* değil, **varlık listesi** yazılıyor (sembol, adet,
//  maliyet). Fiyatı widget kendisi çekiyor — yoksa widget yalnızca kullanıcı
//  uygulamayı açtığında tazelenirdi. Uygulama son bilinen fiyatı da yazıyor;
//  ağ yoksa widget ona düşüyor.
//

import Foundation
import WidgetKit

// MARK: - Payload

/// Bir portföyün widget'ta çizilebilmesi için gereken her şey.
struct WidgetPortfolio: Codable, Identifiable {
    struct Holding: Codable {
        /// `assets_prices.symbol` ile birebir aynı anahtar.
        let symbol: String
        let name: String
        let amount: Double
        /// Ağırlıklı ortalama birim maliyet (TRY). Kâr/zarar bunun üstünden.
        let costPerUnit: Double
        /// Uygulamanın en son gördüğü TRY birim fiyat — ağ hatasında yedek.
        let lastPrice: Double
        /// SF Symbol adı ya da bayrak emojisi.
        let icon: String
        let tintHex: String
    }

    let id: String
    let name: String
    let colorHex: String
    /// "Genel" toplam görünümü — widget'ta rozet olarak ayırt edilir.
    let isGeneral: Bool
    /// Kullanıcı bu portföyün gözünü kapattıysa tutarlar widget'ta da gizlenir.
    let masked: Bool
    let holdings: [Holding]
}

struct WidgetPayload: Codable {
    let portfolios: [WidgetPortfolio]
    /// Uygulamada seçili portföyün id'si — widget varsayılan olarak bunu gösterir.
    let selectedID: String
    /// Currency ham değeri ("TRY", "USD", ...).
    let currencyCode: String

    func portfolio(id: String?) -> WidgetPortfolio? {
        if let id, let match = portfolios.first(where: { $0.id == id }) { return match }
        return portfolios.first(where: { $0.id == selectedID }) ?? portfolios.first
    }
}

// MARK: - Store

enum WidgetSharedStore {
    static let appGroup = "group.com.xptapps.assetbook"

    private static let payloadKey = "widget_payload"
    private static let proKey = "widget_is_pro"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Widget'ın kilit kapısı. Payload'dan ayrı bir anahtar: abonelik bittiğinde
    /// kullanıcı Portföy sekmesini hiç açmasa da (yani yeni payload yazılmasa da)
    /// `PurchaseManager` bunu tek başına güncelleyip widget'ı kilide düşürebilsin.
    static var isPro: Bool {
        get { defaults?.bool(forKey: proKey) ?? false }
        set {
            guard isPro != newValue else { return }
            defaults?.set(newValue, forKey: proKey)
            reload()
        }
    }

    static func loadPayload() -> WidgetPayload? {
        guard let data = defaults?.data(forKey: payloadKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }

    static func save(_ payload: WidgetPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        // Aynı içerik tekrar yazılıp widget'ın kıt yenileme bütçesini yakmasın.
        // (Payload'da zaman damgası yok; tam da bu karşılaştırma çalışsın diye —
        // "en son güncelleme" bilgisi widget'ın kendi fiyat çekim anıdır.)
        guard defaults?.data(forKey: payloadKey) != data else { return }
        defaults?.set(data, forKey: payloadKey)
        reload()
    }

    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
