//
//  AdmobManager.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
import GoogleMobileAds
import SwiftUI

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
