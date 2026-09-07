//
//  SettingsView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import StoreKit
import UIKit
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    #if DEBUG
    @State private var marketsAllUp = RatesViewModel.demoAllUp
    #endif
    @State private var showingRateApp = false
    @State private var showingFeedback = false
    @State private var showingDarkModeSettings = false
    @State private var showingCurrencyPicker = false
    /// Non-nil while a paywall is up; hangi yüzeyden açıldığını da taşır —
    /// banner ile üyelik sayfası eskiden tek `general` bağlamında toplanıyordu.
    @State private var paywallContext: PaywallContext?
    @State private var showingMembership = false
    @State private var shareItem: ShareItem?

    @StateObject private var userDefaults = UserDefaultsManager.shared
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY
    @Environment(\.openURL) private var openURL

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
        .sheet(isPresented: $showingDarkModeSettings) { DarkModeSettingsView() }
        .sheet(isPresented: $showingCurrencyPicker) { CurrencySelectionView() }
        .fullScreenCover(item: $paywallContext) { context in
            PaywallView(onClose: { paywallContext = nil }, context: context)
        }
        .sheet(isPresented: $showingMembership) {
            MembershipSheet(isPro: userDefaults.isPro, onUpgrade: {
                showingMembership = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { paywallContext = .membership }
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
        .onAppear {
            // Re-check every time this screen appears, so the status shown
            // reflects any change the user just made in iOS Settings.
            notificationManager.checkAuthorizationStatus()
        }
    }

    // MARK: - Pro banner

    /// Fiyat, paywall'daki yıllık planın aya düşen tutarı — "aylık şu kadar"
    /// çapası kartın kendisinde duruyor ki kullanıcı tıklamadan maliyeti bilsin.
    private var proBanner: some View {
        Button(action: { paywallContext = .settings }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(ProStyle.accent.opacity(0.14))
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(ProStyle.border, lineWidth: 1)
                        )
                        .overlay(
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(ProStyle.accent)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro'ya geç")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Kilitli 4 özelliği aç")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    if let monthly = ProPlan.monthlyEquivalent {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(monthly)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundColor(ProStyle.accent)
                            Text("/ay")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }

                // Dört rozet dar ekranda sığsın diye aralık 14 → 10.
                HStack(spacing: 10) {
                    proPerk("Reklamsız")
                    proPerk("TEFAS")
                    proPerk("Sınırsız portföy")
                    proPerk("Widget")
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ProStyle.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ProStyle.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func proPerk(_ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ProStyle.accent)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .fixedSize()
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
                    color: userDefaults.isPro ? ProStyle.accent : Color(hex: "#8E8E93"),
                    title: "Üyelik Durumu",
                    trailing: userDefaults.isPro
                        ? .badge("Pro", ProStyle.accent)
                        : .value("Ücretsiz")
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        section("Tercihler") {
            // Currency — seçim ayrı bir ekranda (bkz. CurrencySelectionView).
            Button(action: { showingCurrencyPicker = true }) {
                settingsRow(
                    icon: "turkishlirasign.square.fill", color: Color(hex: "#0A84FF"),
                    title: "Para Birimi",
                    trailing: .value("\(selectedCurrency.flag) \(selectedCurrency.rawValue)")
                )
            }
            .buttonStyle(.plain)

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

            Button(action: handleNotificationRowTap) {
                settingsRow(
                    icon: "bell.fill", color: Color(hex: "#FF3B30"),
                    title: "Bildirimler",
                    trailing: .value(notificationStatusText)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// `.notDetermined` asks in-app (iOS only shows that dialog once); any
    /// other state can only be changed in iOS Settings, so send them there.
    private func handleNotificationRowTap() {
        if notificationManager.authorizationStatus == .notDetermined {
            notificationManager.requestNotificationPermission()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "Açık"
        case .denied: return "Kapalı"
        case .notDetermined: return "İzin Ver"
        @unknown default: return "Kapalı"
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

            Button(action: { openURL(LegalLinks.privacy) }) {
                settingsRow(icon: "lock.shield.fill", color: Color(hex: "#8E8E93"),
                            title: "Gizlilik Politikası", trailing: .chevron)
            }
            .buttonStyle(.plain)

            divider

            Button(action: { openURL(LegalLinks.terms) }) {
                settingsRow(icon: "doc.text.fill", color: Color(hex: "#8E8E93"),
                            title: "Kullanım Koşulları", trailing: .chevron)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
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
            Button("Reset Onboarding") {
                UserDefaultsManager.shared.setValue(value: false, key: .hasSeenOnboarding)
            }.buttonStyle(.bordered)
            // Screenshot çekerken Pro ekranlarını görmek için.
            Button(userDefaults.isPro ? "Pro: AÇIK ✅" : "Pro: KAPALI") {
                PurchaseManager.debugForcePro.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(userDefaults.isPro ? .green : .gray)
            Button("📸 Demo Verisi Yükle") {
                DemoData.load(context: modelContext)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            // Piyasalar listesinde her şey yükselişte görünsün (screenshot için).
            Button(marketsAllUp ? "📈 Piyasalar: YÜKSELİŞ" : "📉 Piyasalar: gerçek") {
                RatesViewModel.demoAllUp.toggle()
                marketsAllUp = RatesViewModel.demoAllUp
            }
            .buttonStyle(.borderedProminent)
            .tint(marketsAllUp ? .green : .gray)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    #endif
}

// MARK: - Membership detail sheet

/// Membership detail: a status card (Pro accent / Free muted) plus the two
/// account actions — manage subscription (system sheet) and restore purchases.
private struct MembershipSheet: View {
    let isPro: Bool
    let onUpgrade: () -> Void

    @State private var showingManageSubscriptions = false
    @State private var isRestoring = false
    @State private var resultMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard
                actions
            }
            .padding(20)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if !isPro {
                upgradeButton
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color(.systemGroupedBackground).ignoresSafeArea(edges: .bottom))
            }
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .alert("Bilgi", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
    }

    // Status card: solid accent + crown for subscribers, muted card for free users.
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isPro ? ProStyle.accent : Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
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
                .background(ProStyle.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

#if DEBUG

// MARK: - Demo data (App Store screenshots)

/// App Store ekran görüntüleri için gerçekçi bir portföy tohumlar. Sadece DEBUG
/// derlemesinde var, Release'e hiç girmiyor.
///
/// Yalnızca altın / gümüş / döviz kullanıyor: bu türlerin sembolü `AssetType`
/// üzerinden geliyor, dolayısıyla fiyat servisi bir sonraki yenilemede doğru
/// fiyatı buluyor. Kripto ve BIST sembolleri canlı katalogdan geldiği için elle
/// uydurmak, yenileme sonrası bozuk satır riski demek.
enum DemoData {

    private struct Holding {
        let type: AssetType
        /// Kripto / BIST / fon için katalogdaki (`assets_prices.symbol`) sembol.
        /// Altın, gümüş ve dövizde nil — sembol `AssetType`'tan türüyor.
        var symbol: String? = nil
        var name: String? = nil
        var unit: String? = nil
        let amount: Double
        /// Güncel birim fiyat (TRY). Kripto USD fiyatlansa da uygulama TRY
        /// saklıyor, o yüzden buradaki değerler de TRY.
        let price: Double
        /// Alış birim fiyatı (TRY) — kâr yüzdesini bu belirliyor.
        let cost: Double
        /// Günlük değişim (%). Analiz'deki "En Çok Kazandıranlar / Kaybettirenler"
        /// kâr/zarara değil bu güne göre sıralanıyor, o yüzden dünkü fiyatı
        /// buradan geriye hesaplıyoruz.
        var dayChange: Double = 0
    }

    /// Semboller ve fiyatlar canlı `assets_prices` katalogundan alındı; uydurma
    /// sembol kullanılırsa fiyat yenilemesi satırı bulamaz ve demo bozulur.
    private static let plan: [(name: String, color: PortfolioColor, holdings: [Holding])] = [
        ("Portföyüm", .purple, [
            Holding(type: .gold,        amount: 42,    price: 6_703.63,  cost: 5_610,  dayChange: 2.4),
            Holding(type: .goldQuarter, amount: 12,    price: 10_968.53, cost: 9_180,  dayChange: 0.8),
            Holding(type: .crypto, symbol: "BTC", name: "Bitcoin", unit: "adet",
                    amount: 0.15,  price: 3_011_770, cost: 2_480_000, dayChange: 1.9),
            Holding(type: .crypto, symbol: "ETH", name: "Ethereum", unit: "adet",
                    amount: 2.5,   price: 89_813,    cost: 74_500,    dayChange: 1.2),
            Holding(type: .usd,         amount: 4_500, price: 47.78,     cost: 41.20,  dayChange: 0.3),
            Holding(type: .bistStock, symbol: "THYAO.IS", name: "THYAO", unit: "lot",
                    amount: 400,   price: 305.25,    cost: 262.00,    dayChange: 0.5)
        ]),
        ("Emeklilik", .green, [
            Holding(type: .goldFull,     amount: 6,     price: 43_739.96, cost: 36_900, dayChange: 0.7),
            Holding(type: .goldRepublic, amount: 3,     price: 45_103.00, cost: 38_500, dayChange: 0.6),
            Holding(type: .eur,          amount: 2_000, price: 55.25,     cost: 47.80,  dayChange: 0.2),
            Holding(type: .fund, symbol: "TTE",
                    name: "İŞ PORTFÖY BIST TEKNOLOJİ AĞIRLIK SINIRLAMALI ENDEKSİ HİSSE SENEDİ (TL) FONU",
                    unit: "lot",
                    amount: 60_000, price: 1.816762, cost: 1.58,      dayChange: 0.4),
            Holding(type: .bistStock, symbol: "ASELS.IS", name: "ASELS", unit: "lot",
                    amount: 250,   price: 387.50,    cost: 328.00,    dayChange: -1.1)
        ]),
        ("Ev Peşinatı", .blue, [
            // Gram altın bilerek burada yok: aynı sembol iki portföyde olursa
            // "Genel" kapsamında movers listesinde iki kez çıkıp Bitcoin'i
            // ilk üçten düşürüyor.
            Holding(type: .goldHalf, amount: 4,   price: 21_937.07, cost: 18_600, dayChange: 0.9),
            Holding(type: .silver,   amount: 800, price: 99.25,     cost: 78.40,  dayChange: 3.1),
            Holding(type: .bistStock, symbol: "GARAN.IS", name: "GARAN", unit: "lot",
                    amount: 600,   price: 131.00,   cost: 112.00,    dayChange: 0.4),
            // ABD borsası TRY karşılığıyla: 305,93 USD × 47,7776.
            Holding(type: .usStock, symbol: "AAPL", name: "AAPL", unit: "lot",
                    amount: 6,     price: 14_616.60, cost: 12_400,   dayChange: -1.4),
            Holding(type: .fund, symbol: "DFI",
                    name: "ATLAS PORTFÖY SERBEST FON",
                    unit: "lot",
                    amount: 15_000, price: 5.4381,  cost: 4.72,      dayChange: -2.0)
        ])
    ]

    /// Grafiklerin dolu görünmesi için kaç günlük geçmiş üretilecek.
    private static let historyDays = 90

    @MainActor
    static func load(context: ModelContext) {
        wipe(context: context)

        for (index, entry) in plan.enumerated() {
            let portfolio = Portfolio(
                name: entry.name,
                colorHex: entry.color.rawValue,
                sortOrder: index + 1
            )
            context.insert(portfolio)

            for holding in entry.holdings {
                let asset: Asset
                if let symbol = holding.symbol {
                    asset = Asset(
                        type: holding.type,
                        symbol: symbol,
                        name: holding.name ?? symbol,
                        unit: holding.unit ?? "adet",
                        amount: holding.amount,
                        currentPrice: holding.price
                    )
                } else {
                    asset = Asset(
                        type: holding.type,
                        amount: holding.amount,
                        currentPrice: holding.price
                    )
                }
                // Analiz grafiği pencereyi en eski varlık tarihine kırpıyor;
                // bugün eklenmiş varlıkta tek gün kalıp "yeterli geçmiş yok"
                // diyor. Geriye tarihlemek grafiği dolduruyor.
                asset.dateAdded = Calendar.current.date(
                    byAdding: .day, value: -historyDays, to: Date()
                ) ?? Date()
                asset.portfolio = portfolio
                context.insert(asset)
                PortfolioManager.shared.storePurchasePrice(for: asset.id, price: holding.cost)
                seedPriceHistory(for: holding, context: context)
            }

            seedSnapshots(for: portfolio, holdings: entry.holdings, context: context)
        }

        try? context.save()
        Logger.log("📸 DemoData: \(plan.count) portföy tohumlandı")
    }

    /// Mevcut veriyi tamamen siler — ekran görüntüsü için temiz bir başlangıç
    /// gerekiyor, üstüne eklemek karışık portföyler üretirdi. "Genel" korunur,
    /// silinemez bir toplam görünümü olduğu için.
    @MainActor
    private static func wipe(context: ModelContext) {
        try? context.delete(model: Asset.self)
        try? context.delete(model: AssetPriceHistory.self)
        try? context.delete(model: PortfolioSnapshot.self)
        let existing = (try? context.fetch(FetchDescriptor<Portfolio>())) ?? []
        for portfolio in existing where !portfolio.isGeneral {
            context.delete(portfolio)
        }
        PortfolioManager.shared.resetPortfolio()
    }

    /// Alış fiyatından bugünkü fiyata doğru yükselen, hafif dalgalı bir eğri.
    /// Düz çizgi sahte duruyor, tamamen rastgele olan da trendi kaybettiriyor.
    private static func curve(from start: Double, to end: Double, day: Int) -> Double {
        let progress = Double(day) / Double(historyDays)
        let trend = start + (end - start) * progress
        // Genlik ilerledikçe küçülüyor: eski günlerde daha oynak görünsün.
        let wobble = sin(Double(day) * 0.7) * trend * 0.012 * (1 - progress * 0.5)
        return trend + wobble
    }

    @MainActor
    private static func seedPriceHistory(for holding: Holding, context: ModelContext) {
        let calendar = Calendar.current
        for day in 0...historyDays {
            guard let date = calendar.date(byAdding: .day, value: day - historyDays, to: Date()) else { continue }
            // Dünkü fiyat, istenen günlük değişimden geriye hesaplanıyor —
            // movers listesini belirleyen tek nokta bu.
            let price: Double
            if day == historyDays - 1 {
                price = holding.price / (1 + holding.dayChange / 100)
            } else {
                price = curve(from: holding.cost, to: holding.price, day: day)
            }
            let entry = AssetPriceHistory(
                assetType: holding.type,
                symbol: holding.symbol,
                date: date,
                price: price,
                amount: holding.amount
            )
            context.insert(entry)
        }
    }

    @MainActor
    private static func seedSnapshots(for portfolio: Portfolio, holdings: [Holding], context: ModelContext) {
        let calendar = Calendar.current
        for day in 0...historyDays {
            guard let date = calendar.date(byAdding: .day, value: day - historyDays, to: Date()) else { continue }
            let total = holdings.reduce(0.0) { sum, holding in
                sum + curve(from: holding.cost, to: holding.price, day: day) * holding.amount
            }
            context.insert(PortfolioSnapshot(date: date, totalValue: total, portfolio: portfolio))
        }
    }
}

#endif
