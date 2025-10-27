//
//  RevenueCatManager.swift
//  MyGolds
//
//  Created by Claude on 27.10.2025.
//

import Foundation
import RevenueCat

@MainActor
class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()

    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isPremium: Bool = false
    @Published var isLoading: Bool = false

    // Product identifiers - App Store Connect'te oluşturulacak
    static let monthlyProductId = "com.xptapps.assetbook.premium.monthly"
    static let yearlyProductId = "com.xptapps.assetbook.premium.yearly"
    static let entitlementId = "premium"

    private init() {
        Logger.log("🔐 RevenueCatManager: Initialized")
    }

    // MARK: - Configuration

    func configure(apiKey: String) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        // Set delegate for customer info updates
        Purchases.shared.delegate = self

        Logger.log("🔐 RevenueCatManager: Configured with API key")

        // Fetch initial customer info
        Task {
            await fetchCustomerInfo()
            await fetchOfferings()
        }
    }

    // MARK: - Customer Info

    func fetchCustomerInfo() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements[Self.entitlementId]?.isActive == true

            Logger.log("🔐 RevenueCatManager: Customer info fetched - isPremium: \(isPremium)")
        } catch {
            Logger.log("❌ RevenueCatManager: Failed to fetch customer info - \(error)")
        }
    }

    // MARK: - Offerings

    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings

            if let current = offerings.current {
                Logger.log("🔐 RevenueCatManager: Offerings fetched - \(current.availablePackages.count) packages")
            } else {
                Logger.log("⚠️ RevenueCatManager: No current offering available")
            }
        } catch {
            Logger.log("❌ RevenueCatManager: Failed to fetch offerings - \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> CustomerInfo {
        isLoading = true
        defer { isLoading = false }

        Logger.log("🔐 RevenueCatManager: Attempting purchase - \(package.storeProduct.localizedTitle)")

        do {
            let result = try await Purchases.shared.purchase(package: package)

            self.customerInfo = result.customerInfo
            self.isPremium = result.customerInfo.entitlements[Self.entitlementId]?.isActive == true

            Logger.log("🔐 RevenueCatManager: Purchase successful - isPremium: \(isPremium)")

            // Log analytics
            FirebaseAnalyticsHelper.logEvent(
                name: "purchase_completed",
                parameters: [
                    "product_id": package.storeProduct.productIdentifier,
                    "price": package.storeProduct.price.description
                ]
            )

            return result.customerInfo
        } catch {
            Logger.log("❌ RevenueCatManager: Purchase failed - \(error)")
            throw error
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws -> CustomerInfo {
        isLoading = true
        defer { isLoading = false }

        Logger.log("🔐 RevenueCatManager: Restoring purchases")

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()

            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements[Self.entitlementId]?.isActive == true

            Logger.log("🔐 RevenueCatManager: Restore successful - isPremium: \(isPremium)")

            return customerInfo
        } catch {
            Logger.log("❌ RevenueCatManager: Restore failed - \(error)")
            throw error
        }
    }

    // MARK: - Helpers

    func getMonthlyPackage() -> Package? {
        offerings?.current?.availablePackages.first { package in
            package.packageType == .monthly
        }
    }

    func getYearlyPackage() -> Package? {
        offerings?.current?.availablePackages.first { package in
            package.packageType == .annual
        }
    }

    func getFormattedPrice(for package: Package) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? Locale.current

        return formatter.string(from: package.storeProduct.price) ?? "\(package.storeProduct.price)"
    }

    func getSubscriptionPeriod(for package: Package) -> String {
        switch package.packageType {
        case .monthly:
            return "Aylık"
        case .annual:
            return "Yıllık"
        default:
            return ""
        }
    }
}

// MARK: - PurchasesDelegate

extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Logger.log("🔐 RevenueCatManager: Received updated customer info")

        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isPremium = customerInfo.entitlements[Self.entitlementId]?.isActive == true
        }
    }
}
