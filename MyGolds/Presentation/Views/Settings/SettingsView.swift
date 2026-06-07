//
//  SettingsView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingRateApp = false
    @State private var showingFeedback = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDarkModeSettings = false
    @State private var showingPaywall = false
    @State private var shareItem: ShareItem?

    @StateObject private var userDefaults = UserDefaultsManager.shared
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // Debug helpers
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var notificationManager = NotificationManager.shared

    struct ShareItem: Identifiable {
        let id = UUID()
        let text: String
        let url: URL?
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Ayarlar")
                        .font(.system(size: 34, weight: .heavy))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    if !userDefaults.isPro {
                        proBanner.padding(.horizontal, 20)
                    }

                    #if DEBUG
                    debugSection
                    #endif

                    preferencesSection
                    supportSection
                    footer
                }
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showingRateApp) {
            RateAppView()
                .presentationDetents([.height(460)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showingFeedback) { FeedbackView() }
        .sheet(isPresented: $showingPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showingDarkModeSettings) { DarkModeSettingsView() }
        .sheet(isPresented: $showingPaywall) { PaywallView(onClose: { showingPaywall = false }) }
        .sheet(item: $shareItem) { item in
            if let url = item.url {
                ActivityViewController(activityItems: [item.text, url])
            } else {
                ActivityViewController(activityItems: [item.text])
            }
        }
    }

    // MARK: - Pro banner

    private var proBanner: some View {
        Button(action: { showingPaywall = true }) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Varlık Pro'ya Geç")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Sınırsız portföy ve gelişmiş analiz")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(hex: "#AF52DE").opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        section("Tercihler") {
            // Currency
            Menu {
                ForEach(Currency.allCases, id: \.self) { currency in
                    Button {
                        selectedCurrency = currency
                    } label: {
                        Label("\(currency.rawValue) (\(currency.symbol))",
                              systemImage: selectedCurrency == currency ? "checkmark" : "")
                    }
                }
            } label: {
                settingsRow(
                    icon: "turkishlirasign.square.fill", color: Color(hex: "#0A84FF"),
                    title: "Para Birimi",
                    trailing: .value("\(selectedCurrency.rawValue) (\(selectedCurrency.symbol))")
                )
            }

            divider

            Button(action: { showingDarkModeSettings = true }) {
                settingsRow(
                    icon: userDefaults.darkModePreference.iconName, color: Color(hex: "#AF52DE"),
                    title: "Görünüm",
                    trailing: .value(userDefaults.darkModePreference.displayName)
                )
            }
            .buttonStyle(.plain)

            divider

            settingsRow(
                icon: "bell.fill", color: Color(hex: "#FF3B30"),
                title: "Bildirimler",
                trailing: .toggle($notificationsEnabled)
            )
            .onChange(of: notificationsEnabled) { _, enabled in
                if enabled {
                    notificationManager.requestNotificationPermission()
                    notificationManager.handleAppLaunch()
                } else {
                    notificationManager.cancelAllPortfolioNotifications()
                }
            }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        section("Destek") {
            Button(action: { showingFeedback = true }) {
                settingsRow(icon: "envelope.fill", color: Color(hex: "#34C759"),
                            title: "Bize Ulaşın", trailing: .chevron)
            }
            .buttonStyle(.plain)

            divider

            Button(action: { showingRateApp = true }) {
                settingsRow(icon: "star.fill", color: Color(hex: "#FF9F0A"),
                            title: "Uygulamayı Puanla", trailing: .chevron)
            }
            .buttonStyle(.plain)

            divider

            Button(action: { showingPrivacyPolicy = true }) {
                settingsRow(icon: "lock.shield.fill", color: Color(hex: "#8E8E93"),
                            title: "Gizlilik Politikası", trailing: .chevron)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text(AppVersionHelper.appName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            Text(AppVersionHelper.displayVersionString)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("© 2026 Varlık Takibi. Tüm hakları saklıdır.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: - Reusable building blocks

    private enum RowTrailing {
        case chevron
        case value(String)
        case toggle(Binding<Bool>)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 34)
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20)
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 64)
    }

    private func settingsRow(icon: String, color: Color, title: String, trailing: RowTrailing) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                )
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Spacer()
            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            case .value(let text):
                HStack(spacing: 6) {
                    Text(text).font(.system(size: 16)).foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            case .toggle(let binding):
                Toggle("", isOn: binding).labelsHidden()
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    // MARK: - Debug (only in debug builds)

    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: 10) {
            Text("🐛 DEBUG").font(.headline).foregroundColor(.orange)
            HStack(spacing: 10) {
                Button("Load Ad") { appOpenAdManager.loadAd() }.buttonStyle(.bordered)
                Button("Force Ad") { appOpenAdManager.forceShowAd() }.buttonStyle(.borderedProminent)
                Button(userDefaults.isPro ? "Pro: ON" : "Pro: OFF") {
                    userDefaults.isPro.toggle()
                    if userDefaults.isPro { adManager.hideBanner() } else { adManager.showBannerAd() }
                }.buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Button("Test Notif") { notificationManager.scheduleTestNotification() }.buttonStyle(.bordered)
                Button("Reset Onboarding") {
                    UserDefaultsManager.shared.setValue(value: false, key: .hasSeenOnboarding)
                }.buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    #endif
}
