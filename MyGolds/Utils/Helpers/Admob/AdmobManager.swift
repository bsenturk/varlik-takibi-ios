//
//  AdmobManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import GoogleMobileAds
import SwiftUI
import UIKit

class AdMobManager: ObservableObject {
    static let shared = AdMobManager()
    
    @Published var showBanner = true
    @Published var adError = false
    @Published var bannerHeight: CGFloat = 50
    @Published var isAppOpenAdShowing = false
    
    private var initializationComplete = false
    
    private init() {
        initializeAdMob()
    }
    
    // MARK: - Initialization
    
    private func initializeAdMob() {
        guard !initializationComplete else { return }
        
        Logger.log("🔧 AdMob: Initializing...")
        
        GADMobileAds.sharedInstance().start { [weak self] status in
            DispatchQueue.main.async {
                self?.initializationComplete = true
                Logger.log("🔧 AdMob: Initialization completed")
                
                // Start loading app open ad after AdMob is initialized
                AppOpenAdManager.shared.preloadAd()
            }
        }
    }
    
    // MARK: - Banner Management
    
    func hideBanner() {
        Logger.log("🎯 Banner: Hiding")
        withAnimation(.easeOut(duration: 0.3)) {
            showBanner = false
        }
    }
    
    func showBannerAd() {
        // Don't show ads for premium users
        guard !RevenueCatManager.shared.isPremium else {
            Logger.log("🎯 Banner: Not showing - User is Premium")
            return
        }

        // Don't show banner if app open ad is showing
        guard !AppOpenAdManager.shared.isAdShowing else {
            Logger.log("🎯 Banner: Not showing - App Open Ad is active")
            return
        }

        Logger.log("🎯 Banner: Showing")
        withAnimation(.easeIn(duration: 0.3)) {
            showBanner = true
        }
    }
    
    func setBannerHeight(_ height: CGFloat) {
        bannerHeight = height
    }
    
    // MARK: - State Management

    var shouldShowBanner: Bool {
        // Don't show ads for premium users
        guard !RevenueCatManager.shared.isPremium else {
            return false
        }

        return showBanner && !isAppOpenAdShowing && initializationComplete
    }
    
    // MARK: - Public Methods
    
    func refreshBannerIfNeeded() {
        if shouldShowBanner {
            showBannerAd()
        }
    }
}

// MARK: - Environment Support

private struct AdMobManagerKey: EnvironmentKey {
    static let defaultValue = AdMobManager.shared
}

extension EnvironmentValues {
    var adMobManager: AdMobManager {
        get { self[AdMobManagerKey.self] }
        set { self[AdMobManagerKey.self] = newValue }
    }
}

// MARK: - Interstitial Ad Manager

class InterstitialAdManager: NSObject, ObservableObject, GADFullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    private var interstitialAd: GADInterstitialAd?
    private var loadTime = Date()
    @Published var isAdShowing = false
    @Published var isAdLoaded = false
    @Published var isLoadingAd = false

    // Production Ad Unit ID
    private let adUnitID = "ca-app-pub-2545255000258244/4481594119"

    // Test Ad Unit ID for development
    private let testAdUnitID = "ca-app-pub-3940256099942544/1033173712"

    // Minimum time interval between ad shows (in seconds)
    private let minimumAdInterval: TimeInterval = 30 // 30 seconds
    private var lastAdShowTime: Date?

    private override init() {
        super.init()
        loadAd()
    }

    // MARK: - Public Properties

    var isAdAvailable: Bool {
        return interstitialAd != nil &&
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

    // MARK: - Private Methods

    private func wasLoadTimeLessThanNHoursAgo(timeIntervalInHours: Int) -> Bool {
        let now = Date()
        let timeIntervalInSeconds = TimeInterval(timeIntervalInHours * 3600)
        return now.timeIntervalSince(loadTime) < timeIntervalInSeconds
    }

    // MARK: - Ad Loading

    func loadAd() {
        guard !isLoadingAd else {
            Logger.log("📱 Interstitial: Already loading")
            return
        }

        guard interstitialAd == nil else {
            Logger.log("📱 Interstitial: Already loaded")
            return
        }

        isLoadingAd = true
        Logger.log("📱 Interstitial: Loading ad...")

        let request = GADRequest()

        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoadingAd = false

                if let error = error {
                    Logger.log("❌ Interstitial: Failed to load - \(error.localizedDescription)")
                    self.interstitialAd = nil
                    self.isAdLoaded = false

                    // Retry loading after 30 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        self.loadAd()
                    }
                    return
                }

                Logger.log("✅ Interstitial: Ad loaded successfully")
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.loadTime = Date()
                self.isAdLoaded = true
            }
        }
    }

    // MARK: - Ad Presentation

    func showAdIfAvailable() {
        // Don't show ads for premium users
        guard !RevenueCatManager.shared.isPremium else {
            Logger.log("📱 Interstitial: Not showing - User is Premium")
            return
        }

        guard canShowAd else {
            Logger.log("📱 Interstitial: Cannot show ad (not available or too soon)")
            if !isAdAvailable {
                loadAd() // Preload next ad
            }
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootViewController = windowScene.windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            Logger.log("❌ Interstitial: No root view controller found")
            return
        }

        // Find the topmost view controller (handles fullScreenCover case)
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        Logger.log("📱 Interstitial: Showing ad from topmost controller")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isAdShowing = true
            self.lastAdShowTime = Date()

            // Hide banner while interstitial is showing
            AdMobManager.shared.hideBanner()

            self.interstitialAd?.present(fromRootViewController: topController)
        }
    }

    // MARK: - Preloading

    func preloadAd() {
        guard interstitialAd == nil else {
            Logger.log("📱 Interstitial: Already preloaded")
            return
        }

        loadAd()
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 Interstitial: Did record impression")
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 Interstitial: Did record click")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Logger.log("❌ Interstitial: Failed to present - \(error.localizedDescription)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdShowing = false
            self.interstitialAd = nil
            self.isAdLoaded = false

            // Show banner again
            AdMobManager.shared.showBannerAd()

            // Try loading a new ad
            self.loadAd()
        }
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 Interstitial: Will present")

        DispatchQueue.main.async { [weak self] in
            self?.isAdShowing = true
        }
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.log("📱 Interstitial: Did dismiss")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAdShowing = false
            self.interstitialAd = nil
            self.isAdLoaded = false

            // Show banner again after interstitial is dismissed
            AdMobManager.shared.showBannerAd()

            // Preload next ad
            self.loadAd()
        }
    }
}

// MARK: - InterstitialAdManager Environment Support

private struct InterstitialAdManagerKey: EnvironmentKey {
    static let defaultValue = InterstitialAdManager.shared
}

extension EnvironmentValues {
    var interstitialAdManager: InterstitialAdManager {
        get { self[InterstitialAdManagerKey.self] }
        set { self[InterstitialAdManagerKey.self] = newValue }
    }
}
