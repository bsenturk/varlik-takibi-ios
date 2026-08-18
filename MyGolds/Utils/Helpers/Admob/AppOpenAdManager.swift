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
    /// Gösterim istendi ama reklam henüz yüklü değildi — yükleme bitince gösterilir.
    /// Bu olmadan her `loadAd` başarısı yeni bir gösterime yol açıyordu (döngü).
    private var pendingShowTrigger: Trigger?
    @Published var isAdLoaded = false
    @Published var isLoadingAd = false
    
    // Production Ad Unit ID
    private let adUnitID = "ca-app-pub-2545255000258244/1821136488"
    
    // Test Ad Unit ID for development
    private let testAdUnitID = "ca-app-pub-3940256099942544/5575463023"
    
    /// Reklamı ne tetikledi — frekans kapağı buna göre değişiyor.
    enum Trigger {
        /// Uygulamanın soğuk açılışı (kullanıcı bilinçli olarak uygulamayı açtı).
        case coldStart
        /// Arka plandan dönüş; gün içinde sık olduğu için kapak daha uzun.
        case foregroundReturn

        var minimumInterval: TimeInterval {
            switch self {
            case .coldStart: return 0           // her uygulama açılışında gösterilir
            case .foregroundReturn: return 300  // 5 dk
            }
        }
    }

    private static let lastShowKey = "last_app_open_ad_show"

    /// UserDefaults'ta: uygulamayı kapatıp açarak frekans kapağı aşılmasın.
    private var lastAdShowTime: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastShowKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastShowKey) }
    }

    /// Yükleme init'te DEĞİL, AdMob SDK'sı başladıktan sonra tetiklenir
    /// (AdMobManager.initializeAdMob → preloadAd). SDK hazır olmadan atılan istek
    /// hataya düşüp açılış anını kaçırıyordu.
    private override init() {
        super.init()
    }
    
    // MARK: - Public Properties
    
    var isAdAvailable: Bool {
        return appOpenAd != nil &&
               wasLoadTimeLessThanNHoursAgo(timeIntervalInHours: 4) &&
               !isAdShowing
    }
    
    /// Frekans kapağı: son gösterimden bu yana yeterli süre geçti mi.
    private func isWithinFrequencyCap(_ trigger: Trigger) -> Bool {
        guard let last = lastAdShowTime else { return true }
        return Date().timeIntervalSince(last) >= trigger.minimumInterval
    }

    var canShowAd: Bool {
        isAdAvailable && isWithinFrequencyCap(.coldStart) && FullScreenAdGate.shared.canShow
    }

    /// Foreground'daki key window'un root'u. `connectedScenes.first` açılışta
    /// yanlış sahneyi verip reklamı sessizce düşürüyordu.
    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)?
            .rootViewController
    }

    /// `Did dismiss` bazen hiç gelmiyor (sunum yarıda kesilirse). Ekranda reklam
    /// yokken bayrak takılı kalırsa banner oturum boyunca gizli kalıyordu.
    func clearStaleShowingState() {
        guard isAdShowing, Self.rootViewController?.presentedViewController == nil else { return }
        Logger.log("📱 App Open Ad: Stale isAdShowing cleared")
        isAdShowing = false
        AdMobManager.shared.showBannerAd()
    }
    
    // MARK: - Load Ad
    
    func loadAd() {
        // SDK başlamadan atılan istek hataya düşüyor; start() callback'i zaten
        // preloadAd() çağırıyor, o yüzden burada sessizce bekle.
        guard AdMobManager.shared.initializationComplete else {
            Logger.log("📱 App Open Ad: SDK not ready — deferring load")
            return
        }

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
                if let trigger = self?.pendingShowTrigger {
                    self?.pendingShowTrigger = nil
                    self?.showAdIfAvailable(trigger: trigger)
                }
            }
        }
    }
    
    // MARK: - Show Ad

    /// `retriesLeft`: yalnızca *geçici* engeller için (pencere henüz hazır değil,
    /// ekranda sheet var, başka bir tam ekran reklam yeni kapandı) saniyede bir
    /// yeniden denenir. Frekans kapağı gibi bilinçli engellerde tekrar denenmez —
    /// amaç açılışı kaçırmamak, kullanıcıyı reklama boğmak değil.
    func showAdIfAvailable(trigger: Trigger = .coldStart, retriesLeft: Int = 4) {
        clearStaleShowingState()

        // No ads for Pro users.
        guard !UserDefaultsManager.shared.isPro else { return }

        // Don't show the app-open ad while the user is still in the onboarding flow.
        // Once onboarding is finished, app-open ads show normally.
        guard UserDefaultsManager.shared.getValue(for: .hasSeenOnboarding) else {
            Logger.log("📱 App Open Ad: Onboarding not finished — skipping app open ad")
            preloadAd()
            return
        }

        guard isWithinFrequencyCap(trigger) else {
            Logger.log("📱 App Open Ad: Frequency cap — skipping")
            return
        }

        guard isAdAvailable else {
            // Henüz yüklenmediyse yükle ve gösterimi beklet.
            pendingShowTrigger = trigger
            if !isLoadingAd { loadAd() }
            return
        }

        guard FullScreenAdGate.shared.canShow,
              let rootViewController = Self.rootViewController,
              rootViewController.presentedViewController == nil else {
            guard retriesLeft > 0 else {
                Logger.log("📱 App Open Ad: Still blocked, giving up for this launch")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.showAdIfAvailable(trigger: trigger, retriesLeft: retriesLeft - 1)
            }
            return
        }

        Logger.log("📱 App Open Ad: Showing ad")
        pendingShowTrigger = nil
        isAdShowing = true
        lastAdShowTime = Date()
        FullScreenAdGate.shared.recordShown()
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
