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
    @Published var bannerHeight: CGFloat = 50
    
    private init() {
        // AdMob'u başlat
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
    
    func hideBanner() {
        withAnimation(.easeOut(duration: 0.3)) {
            showBanner = false
        }
    }
    
    func showBannerAd() {
        withAnimation(.easeIn(duration: 0.3)) {
            showBanner = true
        }
    }
    
    func setBannerHeight(_ height: CGFloat) {
        bannerHeight = height
    }
}
