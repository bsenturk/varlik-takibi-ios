//
//  MainTabbarView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .assets
    @StateObject private var adManager = AdMobManager.shared
    
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
            
            // AdMob Banner
            if adManager.showBanner {
                AdMobBannerView()
                    .frame(height: 50)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom))
            }
            
            // Custom TabBar
            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
