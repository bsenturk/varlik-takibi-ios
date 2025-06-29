//
//  MainTabView.swift - iOS 16+ Modern Version
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .assets
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
    
    enum Tab: CaseIterable {
        case assets, rates, settings
        
        var title: String {
            switch self {
            case .assets: return "Varlıklarım"
            case .rates: return "Kurlar"
            case .settings: return "Ayarlar"
            }
        }
        
        var iconName: String {
            switch self {
            case .assets: return "wallet.pass.fill"
            case .rates: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            Group {
                switch selectedTab {
                case .assets:
                    AssetsView()
                case .rates:
                    RatesView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
//             AdMob Banner - Only show if should show
//            if adManager.shouldShowBanner {
//                SmartAdBannerView()
//                    .transition(.move(edge: .bottom).combined(with: .opacity))
//                    .animation(.easeInOut(duration: 0.3), value: adManager.shouldShowBanner)
//            }
            
            // Custom TabBar
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Ensure banner is shown when main tab appears
            if adManager.shouldShowBanner {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    adManager.refreshBannerIfNeeded()
                }
            }
        }
        // iOS 16+ modern syntax
        .onChange(of: appOpenAdManager.isAdShowing) { oldValue, newValue in
            handleAppOpenAdStateChange(isShowing: newValue)
        }
        // iOS 15 backward compatibility - yukarıdaki çalışmazsa bu kullanın:
        /*
        .onChange(of: appOpenAdManager.isAdShowing) { isShowing in
            handleAppOpenAdStateChange(isShowing: isShowing)
        }
        */
    }
    
    private func handleAppOpenAdStateChange(isShowing: Bool) {
        if isShowing {
            Logger.log("🔄 MainTab: App Open Ad showing, hiding banner")
            adManager.hideBanner()
        } else {
            Logger.log("🔄 MainTab: App Open Ad dismissed, showing banner after delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adManager.showBannerAd()
            }
        }
    }
    
    private var customTabBar: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20))
                        
                        Text(tab.title)
                            .font(.caption.bold())
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .top
        )
    }
}
