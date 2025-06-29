//
//  AppOpenAdManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 29.06.2025.
//

import SwiftUI
import GoogleMobileAds
import UIKit

// MARK: - App Open Ad Manager

class AppOpenAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    static let shared = AppOpenAdManager()
    
    private var appOpenAd: GADAppOpenAd?
    private var loadTime = Date()
    @Published var isAdShowing = false
    @Published var isAdLoaded = false
    @Published var isLoadingAd = false
    
    // Production Ad Unit ID
    private let adUnitID = "ca-app-pub-2545255000258244/1821136488"
    
    // Test Ad Unit ID for development
    private let testAdUnitID = "ca-app-pub-3940256099942544/5575463023"
    
    // Minimum time interval between ad shows (in seconds)
    private let minimumAdInterval: TimeInterval = 300 // 5 minutes
    private var lastAdShowTime: Date?
    
    private override init() {
        super.init()
        loadAd()
    }
    
    // MARK: - Public Properties
    
    var isAdAvailable: Bool {
        return appOpenAd != nil &&
               wasLoadTimeLessThanNHoursAgo(timeIntervalInHours: 4) &&
               !isAdShowing
    }
    
    var canShowAd: Bool {
        guard isAdAvailable else { return false }
        
        // Check minimum interval between ads
        if let lastShowTime = lastAdShowTime {
            let timeSinceLastAd = Date().timeIntervalSince(lastShowTime)
            return timeSinceLastAd >= minimumAdInterval
        }
        
        return true
    }
    
    // MARK: - Load Ad
    
    func loadAd() {
        guard !isLoadingAd && !isAdAvailable else {
            Logger.log("📱 App Open Ad: Already loaded or loading")
            return
        }
        
        isLoadingAd = true
        Logger.log("📱 App Open Ad: Loading...")
        
        let request = GADRequest()
        
        // Use test ID in debug, production ID in release
        #if DEBUG
        let adID = testAdUnitID
        Logger.log("📱 App Open Ad: Using test ad unit ID")
        #else
        let adID = adUnitID
        Logger.log("📱 App Open Ad: Using production ad unit ID")
        #endif
        
        GADAppOpenAd.load(withAdUnitID: adID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                self?.isLoadingAd = false
                
                if let error = error {
                    Logger.log("📱 App Open Ad: Failed to load - \(error.localizedDescription)")
                    FirebaseAnalyticsHelper.shared.logAppOpenAdLoadFailed(error: error.localizedDescription)
                    self?.isAdLoaded = false
                    
                    // Retry loading after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        self?.loadAd()
                    }
                    return
                }
                
                guard let ad = ad else {
                    Logger.log("📱 App Open Ad: Ad object is nil")
                    self?.isAdLoaded = false
                    return
                }
                
                Logger.log("📱 App Open Ad: Loaded successfully")
                self?.appOpenAd = ad
                self?.appOpenAd?.fullScreenContentDelegate = self
                self?.loadTime = Date()
                self?.isAdLoaded = true
                self?.showAdIfAvailable()
            }
        }
    }
    
    // MARK: - Show Ad
    func showAdIfAvailable() {
        guard canShowAd else {
            Logger.log("📱 App Open Ad: Cannot show ad - not available or too soon")
            if !isAdAvailable && !isLoadingAd {
                loadAd() // Load new ad for next time
            }
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            Logger.log("📱 App Open Ad: No root view controller found")
            return
        }
        
        // Check if there's already a presented view controller
        if rootViewController.presentedViewController != nil {
            Logger.log("📱 App Open Ad: Another view controller is presented, skipping")
            return
        }
        
        Logger.log("📱 App Open Ad: Showing ad")
        isAdShowing = true
        lastAdShowTime = Date()
        appOpenAd?.present(fromRootViewController: rootViewController)
    }
    
    // MARK: - Helper Methods
    
    private func wasLoadTimeLessThanNHoursAgo(timeIntervalInHours: Int) -> Bool {
        let now = Date()
        let timeIntervalBetweenNowAndLoadTime = now.timeIntervalSince(loadTime)
        let secondsPerHour = 3600.0
        let intervalInSeconds = TimeInterval(timeIntervalInHours) * secondsPerHour
        return timeIntervalBetweenNowAndLoadTime < intervalInSeconds
    }
    
    // MARK: - Public Methods
    func resetAdInterval() {
        lastAdShowTime = nil
    }
    
    func preloadAd() {
        if !isAdAvailable && !isLoadingAd {
            loadAd()
        }
    }
    
    func forceShowAd() {
         // Reset restrictions for test
         lastAdShowTime = nil
         
         if !isAdLoaded {
             loadAd()
             
             // Wait for load and then show
             DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                 self.showAdIfAvailable()
             }
             return
         }
         
         showAdIfAvailable()
     }
    
    // MARK: - GADFullScreenContentDelegate
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 App Open Ad: Will present")
        FirebaseAnalyticsHelper.shared.logAppOpenAdWillPresent()
        DispatchQueue.main.async {
            self.isAdShowing = true
        }
        
        // Hide banner ad when app open ad shows
        DispatchQueue.main.async {
            AdMobManager.shared.hideBanner()
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 App Open Ad: Did dismiss")
        FirebaseAnalyticsHelper.shared.logBannerAdDidDismissScreen()
        DispatchQueue.main.async {
            self.isAdShowing = false
        }
        appOpenAd = nil
        isAdLoaded = false
        
        // Show banner ad again after app open ad dismisses
        DispatchQueue.main.async {
            AdMobManager.shared.showBannerAd()
        }
        
        // Load new ad for next time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.loadAd()
        }
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Logger.log("📱 App Open Ad: Failed to present - \(error.localizedDescription)")
        FirebaseAnalyticsHelper.shared.logAppOpenAdPresentFailed(error: error.localizedDescription)
        DispatchQueue.main.async {
            self.isAdShowing = false
        }
        appOpenAd = nil
        isAdLoaded = false
        
        // Show banner ad again if app open ad fails
        DispatchQueue.main.async {
            AdMobManager.shared.showBannerAd()
        }
        
        // Try to load new ad
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.loadAd()
        }
    }
}

// MARK: - SwiftUI Environment Support

private struct AppOpenAdManagerKey: EnvironmentKey {
    static let defaultValue = AppOpenAdManager.shared
}

extension EnvironmentValues {
    var appOpenAdManager: AppOpenAdManager {
        get { self[AppOpenAdManagerKey.self] }
        set { self[AppOpenAdManagerKey.self] = newValue }
    }
}
