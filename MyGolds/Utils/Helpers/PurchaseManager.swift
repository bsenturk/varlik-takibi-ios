//
//  PurchaseManager.swift
//  MyGolds
//
//  RevenueCat wrapper for the "Varlık Pro" subscription. Loads offerings,
//  performs purchases / restores, and keeps `UserDefaultsManager.isPro`
//  in sync with the user's active entitlements.
//

import Foundation
import UIKit
import RevenueCat

/// Ana ekranda uygulamaya uzun basınca çıkan menüdeki "%30 indirim" kısayolu.
///
/// Kod App Store Connect'te yıllık abonelik altında **Custom Code** olarak
/// tanımlı. Kısayol statik değil dinamik: Pro kullanıcıya indirim göstermenin
/// anlamı yok, `refreshShortcut()` onu listeden çıkarıyor.
enum OfferCode {
    static let shortcutType = "com.xptapps.assetbook.offer30"
    /// App Store Connect'teki Custom Code ile birebir aynı olmalı.
    static let code = "VARLIK30"
    private static let appleID = "6479618311"

    /// Redeem sayfasını kod ön-doldurulmuş açar. StoreKit'in kendi
    /// `presentCodeRedemptionSheet`'i kodu dolduramıyor, kullanıcıya elle
    /// yazdırmak bu akışta kaybetmenin en garanti yolu.
    static var redeemURL: URL {
        URL(string: "https://apps.apple.com/redeem?ctx=offercodes&id=\(appleID)&code=\(code)")!
    }

    @MainActor
    private static var item: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: shortcutType,
            localizedTitle: "%30 indirim",
            localizedSubtitle: "Yıllık Pro üyelikte",
            icon: UIApplicationShortcutIcon(systemImageName: "gift.fill")
        )
    }

    /// Pro durumuna göre kısayolu ekler/kaldırır. Entitlement her
    /// güncellendiğinde çağrılıyor.
    @MainActor
    static func refreshShortcut() {
        UIApplication.shared.shortcutItems = UserDefaultsManager.shared.isPro ? [] : [item]
    }

    /// Kısayol dokunuşunu karşılar. `true` dönerse olay bize aitti.
    @MainActor
    @discardableResult
    static func handle(_ shortcut: UIApplicationShortcutItem) -> Bool {
        guard shortcut.type == shortcutType else { return false }
        FirebaseAnalyticsHelper.shared.logOfferCodeTapped()
        // Soğuk açılışta uygulama henüz aktif değil ve `open` sessizce
        // başarısız olabiliyor; bir tur bekletiyoruz.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIApplication.shared.open(redeemURL)
        }
        return true
    }
}

@MainActor
final class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()

    /// RevenueCat public SDK key (App Store / `appl_` prefix).
    static let apiKey = "appl_ggKxifmdFURKrEiDLTnAFiwlbFR"

    /// Entitlement identifier configured in the RevenueCat dashboard that unlocks
    /// "Varlık Pro". Adjust this if your dashboard uses a different identifier.
    static let entitlementID = "pro"

    /// All offerings fetched from RevenueCat (nil until the first load completes).
    @Published private(set) var offerings: Offerings?
    /// The current offering — drives the paywall's plan cards.
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var isLoadingOfferings = false
    /// True while a purchase or restore is in flight (drives the paywall spinner).
    @Published private(set) var purchaseInProgress = false
    /// Deneme hakkı hâlâ duruyor mu? Ürünün intro offer'ı, denemeyi bir kez
    /// kullanmış kullanıcıya da görünür; bu bayrak olmadan paywall "Ücretsiz
    /// Dene" yazıp kullanıcıdan anında ücret alır.
    /// ponytail: yalnızca `.ineligible` false sayılır — unknown (offline/sandbox)
    /// eski davranışta kalsın.
    @Published private(set) var trialEligible = true

    private override init() { super.init() }

    // MARK: - Configuration

    /// Configures the RevenueCat SDK. Call once, as early as possible at launch.
    static func configure() {
        // Verbose logs only in development; keep production quiet (RevenueCat's own
        // console logging is independent of our DEBUG-gated `Logger`).
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Starts observing entitlement changes and warms up offerings / customer info.
    /// Call after `configure()`.
    func start() {
        Purchases.shared.delegate = self
        OfferCode.refreshShortcut()
        Task { await refreshCustomerInfo() }
        Task { await loadOfferings() }
    }

    // MARK: - Data loading

    func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            self.currentOffering = offerings.current
            let current = offerings.current
            Logger.log("✅ RevenueCat: offering '\(current?.identifier ?? "nil")' loaded with \(current?.availablePackages.count ?? 0) package(s): \(current?.availablePackages.map { $0.storeProduct.productIdentifier } ?? [])")
            await refreshTrialEligibility()
        } catch {
            let ns = error as NSError
            Logger.log("❌ RevenueCat: failed to load offerings - \(ns.localizedDescription)")
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                Logger.log("   ↳ underlying: \(underlying.localizedDescription) | \(underlying.userInfo)")
            }
        }
    }

    /// Deneme uygunluğu abonelik grubu bazında olduğu için tek ürünü sormak yeter.
    private func refreshTrialEligibility() async {
        guard let product = (currentOffering?.annual ?? currentOffering?.availablePackages.first)?.storeProduct
        else { return }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product)
        trialEligible = (status != .ineligible)
        Logger.log("💎 RevenueCat: intro eligibility → \(status) (trialEligible: \(trialEligible))")
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateEntitlement(from: info)
        } catch {
            Logger.log("❌ RevenueCat: failed to fetch customer info - \(error)")
        }
    }

    // MARK: - Purchase / Restore

    /// Purchases the given package. Returns true if the user ends up subscribed.
    @discardableResult
    func purchase(_ package: Package) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            updateEntitlement(from: result.customerInfo)
            return isSubscribed(result.customerInfo)
        } catch {
            Logger.log("❌ RevenueCat: purchase failed - \(error)")
            return false
        }
    }

    /// Restores previous purchases. Returns true if an active subscription was found.
    @discardableResult
    func restore() async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            updateEntitlement(from: info)
            return isSubscribed(info)
        } catch {
            Logger.log("❌ RevenueCat: restore failed - \(error)")
            return false
        }
    }

    // MARK: - Entitlement sync

    private func isSubscribed(_ info: CustomerInfo) -> Bool {
        if info.entitlements[Self.entitlementID]?.isActive == true { return true }
        // Fallback: any active entitlement unlocks Pro (covers a differently-named
        // entitlement in the dashboard).
        return !info.entitlements.active.isEmpty
    }

    private func updateEntitlement(from info: CustomerInfo) {
        let pro = isSubscribed(info)
        if UserDefaultsManager.shared.isPro != pro {
            UserDefaultsManager.shared.isPro = pro
            Logger.log("💎 RevenueCat: Pro entitlement → \(pro)")
        }
        if pro { AdMobManager.shared.hideBanner() }
        OfferCode.refreshShortcut()
    }
}

// MARK: - PurchasesDelegate

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in updateEntitlement(from: customerInfo) }
    }
}
