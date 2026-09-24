//
//  AdMobBannerView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import SwiftUI
import GoogleMobileAds

struct AdMobBannerView: UIViewRepresentable {
    @ObservedObject var adManager = AdMobManager.shared
    var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return "ca-app-pub-2545255000258244/1184209212"
        #endif
    }
    /// Anchored adaptive boyut; SmartAdBannerView ölçtüğü genişliğe göre verir.
    let adSize: AdSize
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }
        bannerView.delegate = context.coordinator
        let unitID = adUnitID
        bannerView.paidEventHandler = { [weak bannerView] value in
            FirebaseAnalyticsHelper.shared.logAdRevenue(
                value,
                format: "Banner",
                adUnitID: unitID,
                source: bannerView?.responseInfo?.loadedAdNetworkResponseInfo?.adSourceName
            )
        }

        let request = Request()
        bannerView.load(request)
        
        return bannerView
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // Banner güncellemeleri burada yapılabilir
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        let parent: AdMobBannerView
        
        init(_ parent: AdMobBannerView) {
            self.parent = parent
        }
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdLoaded()
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            FirebaseAnalyticsHelper.shared.logBannerAdLoadFailed(error: error.localizedDescription)
            parent.adManager.adError = true
        }
        
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdImpression()
        }
        
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdWillPresentScreen()
        }
        
        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdWillDismissScreen()
        }
        
        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdDidDismissScreen()
        }
        
        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            FirebaseAnalyticsHelper.shared.logBannerAdClicked()
        }
    }
}
