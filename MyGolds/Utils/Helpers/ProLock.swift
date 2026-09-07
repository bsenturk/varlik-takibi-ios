//
//  ProLock.swift
//  MyGolds
//
//  Pro aboneliği bittiğinde geriye dönük kilit kuralları.
//
//  Kapılar eskiden yalnızca *oluşturma anındaydı* (`attemptCreatePortfolio`,
//  `openCategory`): abonelik biten kullanıcı Pro'yken açtığı 5 portföyü ve
//  eklediği fonları sınırsızca görmeye devam ediyordu. Kural tek yerde durur ki
//  her tüketici (dashboard, analiz, varlık ekleme) aynı cevabı versin.
//
//  Veri ASLA silinmez — yalnızca erişim kısıtlanır. Pro'ya dönüldüğünde her şey
//  olduğu gibi geri gelir.
//

import Foundation

enum ProLock {
    /// Pro olmayan kullanıcının tutabileceği gerçek ("Genel" hariç) portföy sayısı.
    static let freePortfolioLimit = 2

    // MARK: - Portföy

    /// Pro değilken kilitlenen portföylerin id'leri.
    ///
    /// En eski `freePortfolioLimit` tanesi açık kalır; `createdAt` deterministik ve
    /// kullanıcının elle değiştiremeyeceği tek alan (`sortOrder` sürüklenerek
    /// değiştirilebildiği için kilit "oynatılabilir" olurdu). "Genel" bir toplam
    /// görünümü olduğu için asla kilitlenmez.
    static func lockedPortfolioIDs(_ portfolios: [Portfolio]) -> Set<UUID> {
        guard !UserDefaultsManager.shared.isPro else { return [] }
        let real = portfolios
            .filter { !$0.isGeneral }
            .sorted { $0.createdAt < $1.createdAt }
        return Set(real.dropFirst(freePortfolioLimit).map(\.id))
    }

    /// Yeni portföy oluşturulabilir mi (oluşturma anındaki eski kapı).
    static func canCreatePortfolio(_ portfolios: [Portfolio]) -> Bool {
        if UserDefaultsManager.shared.isPro { return true }
        return portfolios.filter { !$0.isGeneral }.count < freePortfolioLimit
    }

    // MARK: - Varlık

    /// Bir varlık kilitli mi: premium kategoriden (fon) geliyorsa ya da kilitli bir
    /// portföyde duruyorsa.
    ///
    /// `lockedIDs` dışarıdan geçilir; liste başına bir kez hesaplanıp her satırda
    /// yeniden kurulmasın diye.
    static func isLocked(_ asset: Asset, lockedIDs: Set<UUID>) -> Bool {
        guard !UserDefaultsManager.shared.isPro else { return false }
        if asset.type.category.isPremium { return true }
        guard let portfolioID = asset.portfolio?.id else { return false }
        return lockedIDs.contains(portfolioID)
    }

    /// Toplamlara, grafiklere ve analize girecek varlıklar. Kilitli olanlar
    /// arayüzde görünmeye devam eder ama hiçbir tutara katılmaz.
    static func unlocked(_ assets: [Asset], portfolios: [Portfolio]) -> [Asset] {
        guard !UserDefaultsManager.shared.isPro else { return assets }
        let lockedIDs = lockedPortfolioIDs(portfolios)
        return assets.filter { !isLocked($0, lockedIDs: lockedIDs) }
    }

    /// Kilitli varlıklar (tek satırlık "Pro ile açılır" özetini beslemek için).
    static func locked(_ assets: [Asset], portfolios: [Portfolio]) -> [Asset] {
        guard !UserDefaultsManager.shared.isPro else { return [] }
        let lockedIDs = lockedPortfolioIDs(portfolios)
        return assets.filter { isLocked($0, lockedIDs: lockedIDs) }
    }

    #if DEBUG
    /// Tek çalıştırılabilir kontrol: sıralama en eskiye göre, Genel hariç tutulur,
    /// Pro'da hiçbir şey kilitlenmez. Test target'ı yok, bu yüzden launch'ta
    /// assert olarak koşuyor (AdPaywallGate.selfCheck ile aynı kalıp).
    @MainActor
    static func selfCheck() {
        let wasPro = UserDefaultsManager.shared.isPro
        defer { UserDefaultsManager.shared.isPro = wasPro }

        let general = Portfolio(name: "Genel", isGeneral: true)
        // createdAt init'te `Date()` — sırayı deterministik yapmak için elle veriliyor.
        let old = Portfolio(name: "Eski")
        old.createdAt = Date(timeIntervalSince1970: 100)
        let mid = Portfolio(name: "Orta")
        mid.createdAt = Date(timeIntervalSince1970: 200)
        let new = Portfolio(name: "Yeni")
        new.createdAt = Date(timeIntervalSince1970: 300)
        // sortOrder kasten ters: kilit sürüklemeyle oynatılamamalı.
        old.sortOrder = 2; mid.sortOrder = 1; new.sortOrder = 0
        let all = [general, new, mid, old]

        UserDefaultsManager.shared.isPro = false
        let locked = lockedPortfolioIDs(all)
        assert(locked == [new.id], "En eski 2 açık kalmalı, sadece 'Yeni' kilitli: \(locked.count)")
        assert(!canCreatePortfolio(all), "3 portföyle yeni oluşturma kapalı olmalı")
        assert(canCreatePortfolio([general, old]), "1 portföyle oluşturma açık olmalı")

        UserDefaultsManager.shared.isPro = true
        assert(lockedPortfolioIDs(all).isEmpty, "Pro'da hiçbir portföy kilitlenmemeli")
        assert(canCreatePortfolio(all), "Pro'da oluşturma her zaman açık")
    }
    #endif
}
