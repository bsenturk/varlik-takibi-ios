//
//  MainTabView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import SwiftData

/// Lets any screen trigger the global Add-Asset flow owned by `MainTabView`.
final class AddAssetPresenter: ObservableObject {
    static let shared = AddAssetPresenter()
    @Published var isPresented = false
    private init() {}
    func present() { isPresented = true }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @AppStorage("selectedPortfolioID") private var selectedPortfolioIDString: String = ""

    @State private var selectedTab: Tab = .portfolio
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
    @StateObject private var addPresenter = AddAssetPresenter.shared
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager

    enum Tab: CaseIterable {
        case portfolio, analysis, rates, settings

        var title: String {
            switch self {
            case .portfolio: return "Portföy"
            case .analysis: return "Analiz"
            case .rates: return "Kurlar"
            case .settings: return "Ayarlar"
            }
        }

        var iconName: String {
            switch self {
            case .portfolio: return "creditcard.fill"
            case .analysis: return "chart.xyaxis.line"
            case .rates: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
    }

    /// The portfolio a newly added asset should land in (never the "Genel" aggregate).
    private var addTargetPortfolio: Portfolio? {
        if let selected = portfolios.first(where: { $0.id.uuidString == selectedPortfolioIDString }),
           !selected.isGeneral {
            return selected
        }
        return portfolios.first(where: { !$0.isGeneral })
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .portfolio:
                    DashboardView()
                case .analysis:
                    AnalysisView()
                case .rates:
                    RatesView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if adManager.shouldShowBanner {
                SmartAdBannerView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: adManager.shouldShowBanner)
            }

            customTabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $addPresenter.isPresented) {
            AddAssetSheet(targetPortfolio: addTargetPortfolio)
                .environmentObject(interstitialAdManager)
        }
        .onAppear {
            if adManager.shouldShowBanner {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    adManager.refreshBannerIfNeeded()
                }
            }
        }
        .onChange(of: appOpenAdManager.isAdShowing) { _, newValue in
            handleAppOpenAdStateChange(isShowing: newValue)
        }
    }

    private func handleAppOpenAdStateChange(isShowing: Bool) {
        if isShowing {
            adManager.hideBanner()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                adManager.showBannerAd()
            }
        }
    }

    // MARK: - Tab bar

    private var customTabBar: some View {
        ZStack {
            // Floating pill with the three tabs split around a centered gap.
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    tabButton(.portfolio)
                    tabButton(.analysis)
                }
                .frame(maxWidth: .infinity)

                Color.clear.frame(width: 76)

                HStack(spacing: 0) {
                    tabButton(.rates)
                    tabButton(.settings)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 60)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)

            plusButton
                .offset(y: -18)
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 19))
                Text(tab.title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var plusButton: some View {
        Button {
            interstitialAdManager.preloadAd()
            addPresenter.present()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 4))
                .shadow(color: Color(hex: "#AF52DE").opacity(0.45), radius: 12, x: 0, y: 6)
        }
    }
}
