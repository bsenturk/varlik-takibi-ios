//
//  SmartAdBannerView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 28.06.2025.
//

import SwiftUI
import GoogleMobileAds

struct SmartAdBannerView: View {
    @StateObject private var adManager = AdMobManager.shared
    @State private var bannerHeight: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 0) {
            if adManager.showBanner {
                AdMobBannerView()
                    .frame(height: bannerHeight)
                    .background(Color(.systemGray6))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        bannerHeight = adManager.bannerHeight
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: adManager.showBanner)
    }
}
