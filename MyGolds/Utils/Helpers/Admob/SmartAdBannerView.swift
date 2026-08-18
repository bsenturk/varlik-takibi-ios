//
//  SmartAdBannerView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//
//  Anchored adaptive banner: yüksekliği sabit 320x50 yerine, bannerın kaplayacağı
//  genişliğe ve cihaz yönüne göre SDK belirler (daha yüksek dolum ve eCPM).
//

import SwiftUI
import GoogleMobileAds

struct SmartAdBannerView: View {
    @StateObject private var adManager = AdMobManager.shared

    /// Banner tab bar'ın üstünde tam genişlikte durduğu için ölçü ekran genişliği.
    private var adSize: GADAdSize {
        GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(UIScreen.main.bounds.width)
    }

    var body: some View {
        VStack(spacing: 0) {
            if adManager.showBanner, !adManager.adError {
                AdMobBannerView(adSize: adSize)
                    .frame(height: adSize.size.height)
                    // Cihaz döndüğünde yeni genişlikle yeniden yüklensin.
                    .id(adSize.size.width)
                    .background(Color(.systemGray6))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: adManager.showBanner)
    }
}
