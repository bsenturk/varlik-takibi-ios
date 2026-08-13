//
//  OnboardingView.swift
//  MyGolds
//
//  Redesigned onboarding: 3 paged screens → ATT → app, where the first action
//  is adding a real asset (the "aha" moment). The paywall is deferred until
//  after that first asset is added (armed here, presented by MainTabView).
//

import SwiftUI
import AppTrackingTransparency
import Charts
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var page = 0
    @State private var phase: Phase = .pages
    @State private var skippedOnboarding = false

    private enum Phase { case pages, notifications, att }

    private let pageCount = 3

    var body: some View {
        switch phase {
        case .notifications:
            NotificationPermissionView(onPermissionGranted: { _ in
                goToATTOrFinish()
            })
        case .att:
            ATTPermissionView(onPermissionGranted: { _ in
                completeAndArmFirstAsset()
            })
        case .pages:
            pagesView
        }
    }

    private var pagesView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Atla") { skippedOnboarding = true; finishPages() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $page) {
                OnboardingPage(
                    mock: AnyView(DashboardMock()),
                    title: "Tüm Varlıkların Tek Yerde",
                    description: "Altın, döviz, hisse ve kriptonu tek uygulamada, canlı fiyatlarla takip et."
                ).tag(0)

                OnboardingPage(
                    mock: AnyView(PortfoliosMock()),
                    title: "Farklı Hedefler,\nFarklı Portföyler",
                    description: "Emeklilik, ev peşinatı ya da günlük takip — hedeflerine göre ayrı portföyler oluştur."
                ).tag(1)

                OnboardingPage(
                    mock: AnyView(AnalysisMock()),
                    title: "Performansını\nYakından Takip Et",
                    description: "Dağılım grafikleri ve zaman bazlı analizlerle varlıklarının seyrini net gör."
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: pageCount, index: page)
                .padding(.bottom, 20)

            Button(action: advance) {
                Text(page == pageCount - 1 ? "İlk Varlığını Ekle" : "Devam Et")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            finishPages()
        }
    }

    private func finishPages() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    withAnimation { phase = .notifications }
                } else {
                    goToATTOrFinish()
                }
            }
        }
    }

    private func goToATTOrFinish() {
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            withAnimation { phase = .att }
        } else {
            completeAndArmFirstAsset()
        }
    }

    /// Finish onboarding and arm the post-onboarding hand-off: MainTabView will
    /// auto-open the Add-Asset flow, then present the paywall once an asset is added.
    private func completeAndArmFirstAsset() {
        FirebaseAnalyticsHelper.shared.logOnboardingCompleted(reachedPage: page, skipped: skippedOnboarding)
        UserDefaultsManager.shared.setValue(value: true, key: .pendingFirstAssetAdd)
        UserDefaultsManager.shared.setValue(value: true, key: .pendingOnboardingPaywall)
        coordinator.onboardingCompleted()
    }
}

// MARK: - Page scaffold

private struct OnboardingPage: View {
    let mock: AnyView
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            mock
                .frame(maxWidth: .infinity)
                .frame(height: 320)
            Spacer()
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 26, weight: .heavy))
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 12)
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == index ? 22 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: index)
            }
        }
    }
}

// MARK: - Mock illustrations
//
// Ekranlar uygulamanın gerçek bileşenleriyle kurulur (BalanceCardView,
// DashboardRowView, PortfolioChip, Analiz'in donut kartı) — onboarding'de
// gördüğü ekran, uygulamaya girince karşılaştığı ekranla birebir olsun diye.

/// Portföy sekmesi: bakiye kartı + varlık satırları.
private struct DashboardMock: View {
    @State private var currency: Currency = .TRY

    var body: some View {
        VStack(spacing: 10) {
            BalanceCardView(
                portfolioColor: .blue,
                metrics: PortfolioMetrics(totalValue: 1_250_430, profitLoss: 182_640, profitLossPercent: 17.08),
                selectedCurrency: $currency
            )
            DashboardRowView(item: DashboardRowItem(
                id: "gold",
                title: AssetCategory.gold.displayName,
                subtitle: "3 varlık",
                value: 620_400,
                changePercent: 2.41,
                sparkline: [10, 11, 10.4, 12, 13, 12.6, 14, 15.2],
                icon: AssetCategory.gold.iconName,
                tintHex: AssetCategory.gold.tintHex,
                assetID: nil
            ))
            DashboardRowView(item: DashboardRowItem(
                id: "usd",
                title: AssetCategory.currency.displayName,
                subtitle: "2 varlık",
                value: 358_700,
                changePercent: 0.86,
                sparkline: [14, 13.6, 14.2, 14, 14.8, 15, 14.7, 15.4],
                icon: AssetCategory.currency.iconName,
                tintHex: AssetCategory.currency.tintHex,
                assetID: nil
            ))
        }
        .frame(width: 358)
    }
}

/// Portföy chip'leri: hedeflere göre ayrılmış portföyler.
private struct PortfoliosMock: View {
    @State private var currency: Currency = .TRY

    private static let portfolios: [Portfolio] = [
        Portfolio(name: "Genel", isGeneral: true),
        Portfolio(name: "Emeklilik", colorHex: PortfolioColor.purple.rawValue),
        Portfolio(name: "Ev Peşinatı", colorHex: PortfolioColor.orange.rawValue)
    ]

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(Self.portfolios, id: \.id) { portfolio in
                    PortfolioChip(
                        portfolio: portfolio,
                        isSelected: portfolio.name == "Emeklilik",
                        showsEditAffordance: false,
                        showsEditPencil: false,
                        onTap: {}
                    )
                }
            }
            BalanceCardView(
                portfolioColor: .purple,
                metrics: PortfolioMetrics(totalValue: 840_000, profitLoss: 96_400, profitLossPercent: 12.96),
                selectedCurrency: $currency
            )
        }
        .frame(width: 358)
    }
}

/// Analiz sekmesi: varlık dağılımı donut'u + açıklama listesi.
private struct AnalysisMock: View {
    private struct Slice { let name: String; let percent: Double; let color: Color }

    private static let slices: [Slice] = [
        Slice(name: "Altın", percent: 46, color: Color(hex: AssetCategory.gold.tintHex)),
        Slice(name: "Döviz", percent: 29, color: Color(hex: AssetCategory.currency.tintHex)),
        Slice(name: "Borsa İstanbul", percent: 15, color: Color(hex: AssetCategory.bistStock.tintHex)),
        Slice(name: "Kripto", percent: 10, color: Color(hex: AssetCategory.crypto.tintHex))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Varlık Dağılımı").font(.system(size: 20, weight: .bold))

            HStack(spacing: 18) {
                ZStack {
                    Chart(Self.slices, id: \.name) { slice in
                        SectorMark(
                            angle: .value("Değer", slice.percent),
                            innerRadius: .ratio(0.66),
                            angularInset: 2
                        )
                        .foregroundStyle(slice.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 130, height: 130)

                    VStack(spacing: 2) {
                        Text("Tür").font(.system(size: 13)).foregroundColor(.secondary)
                        Text("\(Self.slices.count)").font(.system(size: 26, weight: .heavy))
                    }
                }

                VStack(spacing: 14) {
                    ForEach(Self.slices, id: \.name) { slice in
                        HStack(spacing: 10) {
                            Circle().fill(slice.color).frame(width: 11, height: 11)
                            Text(slice.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 6)
                            Text("%\(Int(slice.percent))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            // Analiz sekmesinde kart gri zemine oturuyor; burada zemin beyaz
            // olduğu için satır kartlarıyla aynı gölge/çerçeve ile ayrıştırılıyor.
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .frame(width: 358)
    }
}
