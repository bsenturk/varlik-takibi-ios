//
//  AdMobBannerView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: UIViewRepresentable {
    var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return "ca-app-pub-2545255000258244/1184209212"
        #endif
    }
    let adSize: GADAdSize
    
    init(adSize: GADAdSize = GADAdSizeBanner) {
        self.adSize = adSize
    }
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.windows.first?.rootViewController
        bannerView.delegate = context.coordinator
        
        let request = GADRequest()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // Banner güncellemeleri burada yapılabilir
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GADBannerViewDelegate {
        let parent: AdMobBannerView
        
        init(_ parent: AdMobBannerView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdLoaded()
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            FirebaseAnalyticsHelper.shared.logBannerAdLoadFailed(error: error.localizedDescription)
        }
        
        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdImpression()
        }
        
        func bannerViewWillPresentScreen(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdWillPresentScreen()
        }
        
        func bannerViewWillDismissScreen(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdWillDismissScreen()
        }
        
        func bannerViewDidDismissScreen(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdDidDismissScreen()
        }
        
        func bannerViewDidRecordClick(_ bannerView: GADBannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdClicked()
        }
    }
}
