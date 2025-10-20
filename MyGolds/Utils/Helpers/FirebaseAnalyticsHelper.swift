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
}
