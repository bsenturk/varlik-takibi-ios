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
    @Query private var assets: [Asset]
    @AppStorage("selectedPortfolioID") private var selectedPortfolioIDString: String = ""

    @State private var selectedTab: Tab = .portfolio
    @State private var showOnboardingPaywall = false
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
        .sheet(isPresented: $showOnboardingPaywall) {
            PaywallView(onClose: { showOnboardingPaywall = false }, context: .onboarding)
        }
        .onAppear {
            if adManager.shouldShowBanner {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    adManager.refreshBannerIfNeeded()
                }
            }
            FirebaseAnalyticsHelper.shared.logScreenView(String(describing: selectedTab))
            presentFirstAssetAddIfNeeded()
        }
        .onChange(of: appOpenAdManager.isAdShowing) { _, newValue in
            handleAppOpenAdStateChange(isShowing: newValue)
        }
        .onChange(of: addPresenter.isPresented) { _, isPresented in
            // When the (onboarding) Add-Asset flow closes, surface the paywall once —
            // but only after the user has actually added an asset (felt the value).
            guard !isPresented,
                  UserDefaultsManager.shared.getValue(for: .pendingOnboardingPaywall) else { return }
            UserDefaultsManager.shared.setValue(value: false, key: .pendingOnboardingPaywall)
            // Never paywall an already-subscribed user (e.g. they reinstalled and
            // RevenueCat restored their entitlement on launch).
            guard !UserDefaultsManager.shared.isPro else { return }
            guard !assets.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Re-check in case the entitlement finished restoring during the delay.
                guard !UserDefaultsManager.shared.isPro else { return }
                showOnboardingPaywall = true
            }
        }
    }

    /// First launch hand-off from onboarding: auto-open the Add-Asset flow so the
    /// user's first action is adding a real asset. Consumed once.
    private func presentFirstAssetAddIfNeeded() {
        guard UserDefaultsManager.shared.getValue(for: .pendingFirstAssetAdd) else { return }
        UserDefaultsManager.shared.setValue(value: false, key: .pendingFirstAssetAdd)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            addPresenter.present()
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
            FirebaseAnalyticsHelper.shared.logScreenView(String(describing: tab))
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
