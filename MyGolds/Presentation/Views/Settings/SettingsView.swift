//
//  SettingsView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @State private var showingRateApp = false
    @State private var showingFeedback = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDarkModeSettings = false
    @State private var showingPaywall = false
    @State private var showingMembership = false
    @State private var shareItem: ShareItem?

    @StateObject private var userDefaults = UserDefaultsManager.shared
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    // Debug helpers
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
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

                    membershipSection
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
        .sheet(isPresented: $showingMembership) {
            MembershipSheet(isPro: userDefaults.isPro, onUpgrade: {
                showingMembership = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showingPaywall = true }
            })
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
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
                    Text("Varlık Takibi Pro'ya Geç")
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

    // MARK: - Membership

    /// Always-present membership row: shows "Pro" (purple pill) for subscribers or a
    /// muted "Ücretsiz" otherwise. Tapping opens the membership detail (manage +
    /// restore).
    private var membershipSection: some View {
        section("Üyelik") {
            Button(action: { showingMembership = true }) {
                settingsRow(
                    icon: userDefaults.isPro ? "crown.fill" : "person.fill",
                    color: userDefaults.isPro ? Color(hex: "#AF52DE") : Color(hex: "#8E8E93"),
                    title: "Üyelik Durumu",
                    trailing: userDefaults.isPro
                        ? .badge("Pro", Color(hex: "#AF52DE"))
                        : .value("Ücretsiz")
                )
            }
            .buttonStyle(.plain)
        }
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
        case badge(String, Color)
        case toggle(Binding<Bool>)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased(with: Locale(identifier: "tr_TR")))
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
            case .badge(let text, let color):
                HStack(spacing: 6) {
                    Text(text)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(color)
                        .clipShape(Capsule())
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

// MARK: - Membership detail sheet

/// Membership detail: a status card (Pro gradient / Free muted) plus the two
/// account actions — manage subscription (system sheet) and restore purchases.
private struct MembershipSheet: View {
    let isPro: Bool
    let onUpgrade: () -> Void

    @State private var showingManageSubscriptions = false
    @State private var isRestoring = false
    @State private var resultMessage: String?

    private let brandGradient = LinearGradient(
        colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                actions
                if !isPro { upgradeButton }
            }
            .padding(20)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .alert("Bilgi", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
    }

    // Status card: gradient + crown for subscribers, muted card for free users.
    // Compact horizontal layout so it stays a small header, not a hero banner.
    private var statusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isPro ? Color.white.opacity(0.22) : Color(hex: "#8E8E93").opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: isPro ? "crown.fill" : "person.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isPro ? .white : Color(hex: "#8E8E93"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(isPro ? "Varlık Takibi Pro" : "Ücretsiz Plan")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isPro ? .white : .primary)
                Text(isPro ? "Üyeliğiniz aktif · tüm özellikler açık"
                           : "Pro ile reklamsız deneyim ve tüm özellikler")
                    .font(.system(size: 12))
                    .foregroundColor(isPro ? .white.opacity(0.9) : .secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            Group {
                if isPro { brandGradient }
                else { Color(.secondarySystemGroupedBackground) }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: (isPro ? Color(hex: "#AF52DE") : .black).opacity(0.18),
                radius: 12, x: 0, y: 6)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            actionRow(icon: "creditcard.fill", color: Color(hex: "#0A84FF"),
                      title: "Abonelikleri Yönet", showChevron: true) {
                showingManageSubscriptions = true
            }
            Divider().padding(.leading, 64)
            actionRow(icon: "arrow.clockwise", color: Color(hex: "#34C759"),
                      title: "Satın Alımları Geri Yükle", loading: isRestoring) {
                restore()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func actionRow(icon: String, color: Color, title: String,
                           showChevron: Bool = false, loading: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    )
                Text(title).font(.system(size: 16)).foregroundColor(.primary)
                Spacer()
                if loading {
                    ProgressView()
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }

    private var upgradeButton: some View {
        Button(action: onUpgrade) {
            Text("Pro'ya Geç")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            let ok = await PurchaseManager.shared.restore()
            isRestoring = false
            resultMessage = ok ? "Aboneliğiniz başarıyla geri yüklendi."
                               : "Geri yüklenecek aktif bir abonelik bulunamadı."
        }
    }
}
