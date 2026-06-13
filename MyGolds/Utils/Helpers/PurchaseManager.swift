//
//  PurchaseManager.swift
//  MyGolds
//
//  RevenueCat wrapper for the "Varlık Pro" subscription. Loads offerings,
//  performs purchases / restores, and keeps `UserDefaultsManager.isPro`
//  in sync with the user's active entitlements.
//

import Foundation
import RevenueCat

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

    private override init() { super.init() }

    // MARK: - Configuration

    /// Configures the RevenueCat SDK. Call once, as early as possible at launch.
    static func configure() {
        // Use `.debug` temporarily to surface RevenueCat's detailed reason for
        // store/config errors (e.g. which products failed to fetch).
        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: apiKey)
    }

    /// Starts observing entitlement changes and warms up offerings / customer info.
    /// Call after `configure()`.
    func start() {
        Purchases.shared.delegate = self
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
            // TEMP diagnostics: what intro/free-trial offer does StoreKit return per product?
            for pkg in current?.availablePackages ?? [] {
                let p = pkg.storeProduct
                if let intro = p.introductoryDiscount {
                    let unit = intro.subscriptionPeriod.unit
                    Logger.log("🎁 \(p.productIdentifier): intro found — mode=\(intro.paymentMode) period=\(intro.subscriptionPeriod.value) unit=\(unit) price=\(intro.localizedPriceString)")
                } else {
                    Logger.log("🎁 \(p.productIdentifier): NO introductoryDiscount returned by StoreKit")
                }
            }
        } catch {
            let ns = error as NSError
            Logger.log("❌ RevenueCat: failed to load offerings - \(ns.localizedDescription)")
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
                Logger.log("   ↳ underlying: \(underlying.localizedDescription) | \(underlying.userInfo)")
            }
        }
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
    }
}

// MARK: - PurchasesDelegate

extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in updateEntitlement(from: customerInfo) }
    }
}
