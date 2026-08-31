//
//  FirebaseAnalyticsHelper.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

import Foundation
import FirebaseAnalytics
import GoogleMobileAds

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
    
    // MARK: - Ad Revenue

    /// AdMob'un impression-level revenue callback'i (`paidEventHandler`).
    /// Firebase'in standart `ad_impression` olayı olarak yazılır; GA4 bunu
    /// gelir olarak sayar, yani AdMob↔GA4 hesap bağlantısı olmadan da reklam
    /// geliri raporlarda görünür.
    func logAdRevenue(_ value: GADAdValue, format: String, adUnitID: String, source: String?) {
        // GADAdValue mikro cinsindendir (1.000.000 mikro = 1 birim).
        let amount = value.value.dividing(by: 1_000_000).doubleValue
        var params: [String: Any] = [
            AnalyticsParameterAdPlatform: "AdMob",
            AnalyticsParameterAdFormat: format,
            AnalyticsParameterAdUnitName: adUnitID,
            AnalyticsParameterAdSource: source ?? "unknown",
            "precision": value.precision.rawValue
        ]
        // GA4, currency geçersiz/boşsa `value`'yu sessizce yok sayar — gelir
        // kaybolur ve nedeni raporda görünmez. Geçerli ISO-4217 yoksa event
        // yine gönderilir (impression sayımı için) ama tutarsız gelir yazılmaz.
        if value.currencyCode.count == 3 {
            params[AnalyticsParameterCurrency] = value.currencyCode
            params[AnalyticsParameterValue] = amount
        } else {
            params["invalid_currency"] = value.currencyCode.isEmpty ? "empty" : value.currencyCode
        }
        Analytics.logEvent(AnalyticsEventAdImpression, parameters: params)
    }

    // MARK: - Interstitial Ad Events

    func logInterstitialAdLoaded() {
        Analytics.logEvent("interstitial_ad_loaded", parameters: ["ad_type": "interstitial"])
    }

    func logInterstitialAdLoadFailed(error: String) {
        Analytics.logEvent("interstitial_ad_load_failed", parameters: [
            "error_message": error,
            "ad_type": "interstitial"
        ])
    }

    func logInterstitialAdWillPresent() {
        Analytics.logEvent("interstitial_ad_will_present", parameters: ["ad_type": "interstitial"])
    }

    func logInterstitialAdDismissed() {
        Analytics.logEvent("interstitial_ad_dismissed", parameters: ["ad_type": "interstitial"])
    }

    func logInterstitialAdPresentFailed(error: String) {
        Analytics.logEvent("interstitial_ad_present_failed", parameters: [
            "error_message": error,
            "ad_type": "interstitial"
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

    /// Ana ekran kısayolundaki indirim kodu kullanıldığında. Silme anına
    /// müdahale ettiği için dönüşümü ayrıca izlenmeli.
    func logOfferCodeTapped() {
        Analytics.logEvent("offer_code_tapped", parameters: nil)
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

    /// Paywall satın alma yapılmadan kapatıldığında. `seconds_shown`, refleks
    /// kapatma ile "okudu ama ikna olmadı"yı ayırır.
    func logPaywallDismissed(context: String, secondsShown: Int) {
        Analytics.logEvent("paywall_dismissed", parameters: [
            "context": context,
            "seconds_shown": secondsShown
        ])
    }

    /// Abonelik satın alımı başarıyla tamamlandığında (tutar/fiyat içermez).
    func logSubscriptionPurchased(plan: String, hadTrial: Bool) {
        Analytics.logEvent("subscription_purchased", parameters: [
            "plan": plan,
            "had_trial": hadTrial
        ])
    }

    /// Abonelik satın alımı tamamlanmadığında. `reason` olmadan kullanıcı iptali
    /// ile gerçek store hatası aynı sayıya düşüyordu; huninin son adımı okunamıyordu.
    /// - Parameters:
    ///   - reason: `cancelled` (kullanıcı App Store sayfasını kapattı) veya `error`.
    ///   - errorCode: RevenueCat/StoreKit hata kodu; iptalde nil.
    func logSubscriptionPurchaseFailed(plan: String, reason: String, errorCode: Int?) {
        var params: [String: Any] = ["plan": plan, "reason": reason]
        if let errorCode { params["error_code"] = errorCode }
        Analytics.logEvent("subscription_purchase_failed", parameters: params)
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

    /// Görüntüleme para birimi *gerçekten* değiştiğinde (yalnızca kod, tutar değil).
    /// `from` olmadan tekrar eden değişimlerin bir gidiş-geliş mi yoksa tek yönlü
    /// bir tercih mi olduğu ayırt edilemiyordu.
    func logCurrencyChanged(from previous: String, to currency: String) {
        Analytics.logEvent("currency_changed", parameters: [
            "from_currency": previous,
            "currency": currency
        ])
    }

    // MARK: Permissions

    /// ATT diyalogunun sonucu. Sadece reddi loglayan eski event izin oranını
    /// hesaplanamaz bırakıyordu; burada her sonuç tek event'e yazılıyor.
    func logATTResult(status: String) {
        Analytics.logEvent("att_result", parameters: [
            "status": status
        ])
    }
}
