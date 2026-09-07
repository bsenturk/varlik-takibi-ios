//
//  WidgetSync.swift
//  MyGolds
//
//  Uygulama → widget tek yönlü veri aktarımı.
//
//  Widget'a *tutar* değil **varlık listesi** yazılıyor (sembol, adet, maliyet ve
//  son bilinen fiyat). Fiyatı widget kendi çekip toplamı kendi hesapladığı için
//  kullanıcı uygulamayı açmasa da ana ekrandaki kart tazeleniyor; burası yalnızca
//  "hangi portföyde ne var" sorusunu güncelliyor.
//

import Foundation

@MainActor
enum WidgetSync {

    /// Paylaşımlı deposu güncelleyip widget'ı yeniler. Aynı içerik yeniden
    /// yazılırsa `WidgetSharedStore` yenilemeyi atlar.
    static func push(
        portfolios: [Portfolio],
        assets: [Asset],
        selectedID: String,
        currency: Currency,
        maskedRaw: String
    ) {
        WidgetSharedStore.isPro = UserDefaultsManager.shared.isPro

        let lockedIDs = ProLock.lockedPortfolioIDs(portfolios)
        let costs = PortfolioManager.shared.assetPurchasePrices

        let payloadPortfolios: [WidgetPortfolio] = portfolios.compactMap { portfolio in
            // Abonelik bitince kilitlenen portföy widget'a sızmamalı — kilit
            // uygulamada geçerliyse ana ekranda da geçerli.
            guard !lockedIDs.contains(portfolio.id) else { return nil }

            let scoped: [Asset] = portfolio.isGeneral
                ? assets.filter { asset in
                    guard let pid = asset.portfolio?.id else { return true }
                    return !lockedIDs.contains(pid)
                }
                : assets.filter { $0.portfolio?.id == portfolio.id }

            let holdings = scoped
                .filter { !ProLock.isLocked($0, lockedIDs: lockedIDs) }
                .map { asset in
                    WidgetPortfolio.Holding(
                        symbol: asset.symbol,
                        name: asset.name,
                        amount: asset.amount,
                        // Maliyeti kayıtlı değilse güncel fiyat: kâr/zarara 0 katkı
                        // verir (PortfolioMetrics ile aynı kural).
                        costPerUnit: costs[asset.id] ?? asset.currentPrice,
                        lastPrice: asset.currentPrice,
                        icon: asset.type.tileIcon,
                        tintHex: asset.type.tileTintHex
                    )
                }

            return WidgetPortfolio(
                id: portfolio.id.uuidString,
                name: portfolio.name,
                colorHex: portfolio.colorHex,
                isGeneral: portfolio.isGeneral,
                masked: UserDefaultsManager.isPortfolioMasked(maskedRaw, portfolio.id),
                holdings: holdings
            )
        }

        WidgetSharedStore.save(
            WidgetPayload(
                portfolios: payloadPortfolios,
                selectedID: selectedID,
                currencyCode: currency.rawValue
            )
        )
    }
}
