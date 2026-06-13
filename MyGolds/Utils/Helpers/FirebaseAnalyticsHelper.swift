//
//  FirebaseAnalyticsHelper.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

import Foundation
import FirebaseAnalytics

final class FirebaseAnalyticsHelper {
    static let shared = FirebaseAnalyticsHelper()
    
    private init() {}
    
    // MARK: - App Open Ad Events
    
    /// App Open Ad yüklendiğinde
    func logAppOpenAdLoaded() {
        Analytics.logEvent("app_open_ad_loaded", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    /// App Open Ad yüklenemediğinde
    func logAppOpenAdLoadFailed(error: String) {
        Analytics.logEvent("app_open_ad_load_failed", parameters: [
            "error_message": error,
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    /// App Open Ad gösterilmeye başladığında
    func logAppOpenAdWillPresent() {
        Analytics.logEvent("app_open_ad_will_present", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    /// App Open Ad tam olarak gösterildiğinde
    func logAppOpenAdDidPresent() {
        Analytics.logEvent("app_open_ad_did_present", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    /// App Open Ad kapatıldığında
    func logAppOpenAdDismissed() {
        Analytics.logEvent("app_open_ad_dismissed", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    /// App Open Ad gösterilemediğinde
    func logAppOpenAdPresentFailed(error: String) {
        Analytics.logEvent("app_open_ad_present_failed", parameters: [
            "error_message": error,
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "app_open"
        ])
    }
    
    // MARK: - Banner Ad Events
    
    /// Banner Ad yüklendiğinde
    func logBannerAdLoaded() {
        Analytics.logEvent("banner_ad_loaded", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad yüklenemediğinde
    func logBannerAdLoadFailed(error: String) {
        Analytics.logEvent("banner_ad_load_failed", parameters: [
            "error_message": error,
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad impression kaydedildiğinde
    func logBannerAdImpression() {
        Analytics.logEvent("banner_ad_impression", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad'a tıklandığında (screen present edilmeden önce)
    func logBannerAdClicked() {
        Analytics.logEvent("banner_ad_clicked", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad full screen present edildiğinde
    func logBannerAdWillPresentScreen() {
        Analytics.logEvent("banner_ad_will_present_screen", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad full screen kapatılmaya başladığında
    func logBannerAdWillDismissScreen() {
        Analytics.logEvent("banner_ad_will_dismiss_screen", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }
    
    /// Banner Ad full screen tamamen kapatıldığında
    func logBannerAdDidDismissScreen() {
        Analytics.logEvent("banner_ad_did_dismiss_screen", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "ad_type": "banner"
        ])
    }

    // MARK: - Product / Business Events
    //
    // PRIVACY: These events deliberately NEVER include financial/critical user data —
    // no balances, asset amounts, monetary values, or purchase prices. Only
    // behavioural signals and non-sensitive categories (asset class, plan type,
    // instrument symbol, currency code, screen name) are recorded so the funnel can
    // be analysed without profiling a user's actual holdings.

    // MARK: Onboarding

    /// Onboarding tamamlandığında (ATT sonrası tek seferlik bitiş noktası).
    func logOnboardingCompleted(reachedPage: Int, skipped: Bool) {
        Analytics.logEvent("onboarding_completed", parameters: [
            "reached_page": reachedPage,
            "skipped": skipped
        ])
    }

    // MARK: Assets

    /// Bir varlık eklendiğinde — yalnızca varlık sınıfı/sembolü ve davranışsal
    /// bayraklar; ASLA miktar, değer veya fiyat içermez.
    func logAssetAdded(category: String, symbol: String, isMerge: Bool, hasPurchasePrice: Bool) {
        Analytics.logEvent("asset_added", parameters: [
            "asset_category": category,
            "asset_symbol": symbol,
            "is_merge": isMerge,
            "has_purchase_price": hasPurchasePrice
        ])
    }

    /// Bir varlık silindiğinde (miktar/değer içermez).
    func logAssetDeleted(category: String, symbol: String) {
        Analytics.logEvent("asset_deleted", parameters: [
            "asset_category": category,
            "asset_symbol": symbol
        ])
    }

    // MARK: Monetization funnel

    /// Pro olmayan kullanıcı premium bir kategoriye dokunup paywall'a düştüğünde.
    func logPremiumCategoryLocked(category: String) {
        Analytics.logEvent("premium_category_locked", parameters: [
            "asset_category": category
        ])
    }

    /// Paywall açıldığında — hangi bağlamdan tetiklendiği.
    func logPaywallShown(context: String) {
        Analytics.logEvent("paywall_shown", parameters: [
            "context": context
        ])
    }

    /// Paywall'da bir plan seçildiğinde.
    func logPaywallPlanSelected(plan: String) {
        Analytics.logEvent("paywall_plan_selected", parameters: [
            "plan": plan
        ])
    }

    /// Paywall ana CTA'sına basıldığında (satın alma başlatılır).
    func logPaywallCtaTapped(plan: String, hasTrial: Bool) {
        Analytics.logEvent("paywall_cta_tapped", parameters: [
            "plan": plan,
            "has_trial": hasTrial
        ])
    }

    /// Paywall satın alma yapılmadan kapatıldığında.
    func logPaywallDismissed(context: String) {
        Analytics.logEvent("paywall_dismissed", parameters: [
            "context": context
        ])
    }

    /// Abonelik satın alımı başarıyla tamamlandığında (tutar/fiyat içermez).
    func logSubscriptionPurchased(plan: String, hadTrial: Bool) {
        Analytics.logEvent("subscription_purchased", parameters: [
            "plan": plan,
            "had_trial": hadTrial
        ])
    }

    /// Abonelik satın alımı başarısız olduğunda / iptal edildiğinde.
    func logSubscriptionPurchaseFailed(plan: String) {
        Analytics.logEvent("subscription_purchase_failed", parameters: [
            "plan": plan
        ])
    }

    /// Önceki satın alımlar geri yüklendiğinde.
    func logSubscriptionRestored() {
        Analytics.logEvent("subscription_restored", parameters: nil)
    }

    // MARK: Navigation / general

    /// Sekme/ekran görüntülemesi (Firebase'in standart screen_view olayı).
    func logScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName
        ])
    }

    /// Görüntüleme para birimi değiştirildiğinde (yalnızca kod, tutar değil).
    func logCurrencyChanged(to currency: String) {
        Analytics.logEvent("currency_changed", parameters: [
            "currency": currency
        ])
    }
}
