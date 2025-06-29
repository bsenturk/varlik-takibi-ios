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
    
    // Your real App Open Ad Unit ID
    private let adUnitID = "ca-app-pub-2545255000258244/1821136488"
    
    // For testing purposes
    private let testAdUnitID = "ca-app-pub-3940256099942544/5662855259"
    
    private override init() {
        super.init()
    }
    
    var isAdAvailable: Bool {
        return appOpenAd != nil && wasLoadTimeLessThanNHoursAgo(timeIntervalInHours: 4)
    }
    
    // MARK: - Load Ad
    
    func loadAd() {
        guard !isAdAvailable else {
            print("Ad is already loaded")
            return
        }
        
        print("Loading app open ad...")
        let request = GADRequest()
        
        // Use test ID in debug, real ID in production
        #if DEBUG
        let adID = testAdUnitID
        #else
        let adID = adUnitID
        #endif
        
        GADAppOpenAd.load(withAdUnitID: adID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load app open ad: \(error.localizedDescription)")
                    self?.isAdLoaded = false
                    return
                }
                
                guard let ad = ad else {
                    print("App open ad is nil")
                    self?.isAdLoaded = false
                    return
                }
                
                print("App open ad loaded successfully")
                self?.appOpenAd = ad
                self?.appOpenAd?.fullScreenContentDelegate = self
                self?.loadTime = Date()
                self?.isAdLoaded = true
            }
        }
    }
    
    // MARK: - Show Ad
    
    func showAdIfAvailable() {
        guard isAdAvailable else {
            print("App open ad is not available")
            loadAd() // Load new ad for next time
            return
        }
        
        guard !isAdShowing else {
            print("App open ad is already showing")
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("No root view controller found")
            return
        }
        
        print("Showing app open ad")
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
    
    // MARK: - GADFullScreenContentDelegate
    
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("App open ad will present")
        DispatchQueue.main.async {
            self.isAdShowing = true
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("App open ad dismissed")
        DispatchQueue.main.async {
            self.isAdShowing = false
            self.appOpenAd = nil
            self.isAdLoaded = false
        }
        
        // Load new ad for next time
        loadAd()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("App open ad failed to present: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isAdShowing = false
            self.appOpenAd = nil
            self.isAdLoaded = false
        }
        
        // Load new ad for next time
        loadAd()
    }
}
