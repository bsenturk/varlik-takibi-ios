//
//  PaywallView.swift
//  MyGolds
//
//  "Varlık Pro" paywall — backed by RevenueCat offerings + a local `isPro` flag.
//

import SwiftUI
import RevenueCat

/// Pro yüzeylerinin (ayarlardaki kart, üyelik ekranı, paywall) ortak kimliği.
/// Gradyan yok: tek düz vurgu rengi + tonlu arka planlar.
enum ProStyle {
    static let accent = Color(hex: "#AF52DE")
    static var tint: Color { accent.opacity(0.10) }
    static var border: Color { accent.opacity(0.35) }
}

/// Abonelik planları ve fiyat metinleri — paywall ve ayarlar kartı aynı kaynağı
/// kullansın diye tek yerde.
@MainActor
enum ProPlan: String, CaseIterable, Identifiable {
    case yearly, monthly, weekly

    var id: String { rawValue }

    /// Exact App Store product identifiers.
    var productID: String { "com.xptapps.assetbook.premium.\(rawValue)" }

    var title: String {
        switch self {
        case .yearly:  return "Yıllık"
        case .monthly: return "Aylık"
        case .weekly:  return "Haftalık"
        }
    }

    /// Kartın altındaki küçük satır.
    var cadence: String {
        switch self {
        case .yearly:  return "her yıl"
        case .monthly: return "her ay"
        case .weekly:  return "her hafta"
        }
    }

    var periodWord: String {
        switch self {
        case .yearly:  return "yıl"
        case .monthly: return "ay"
        case .weekly:  return "hafta"
        }
    }

    /// Offerings yüklenene kadar gösterilen referans fiyat.
    var fallbackPrice: String {
        switch self {
        case .yearly:  return "₺299,99"
        case .monthly: return "₺49,99"
        case .weekly:  return "₺14,99"
        }
    }

    /// Live RevenueCat package. Prefers the standard Annual/Monthly/Weekly
    /// accessor, then falls back to matching by product id.
    var package: Package? {
        guard let offering = PurchaseManager.shared.currentOffering else { return nil }
        let standard: Package?
        switch self {
        case .yearly:  standard = offering.annual
        case .monthly: standard = offering.monthly
        case .weekly:  standard = offering.weekly
        }
        if let standard { return standard }
        return offering.availablePackages.first { $0.storeProduct.productIdentifier == productID }
    }

    var price: String { package?.storeProduct.localizedPriceString ?? fallbackPrice }

    /// Free-trial length, if the product has one **and** the user can still use it.
    /// Denemesini harcamış kullanıcıda nil döner; CTA, özet ve küçük yazı buradan
    /// beslendiği için üçü birden düzelir.
    var freeTrial: String? {
        guard PurchaseManager.shared.trialEligible,
              let discount = package?.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial else { return nil }
        let period = discount.subscriptionPeriod
        switch period.unit {
        case .day:   return "\(period.value) gün"
        case .week:  return "\(period.value) hafta"
        case .month: return "\(period.value) ay"
        case .year:  return "\(period.value) yıl"
        @unknown default: return "\(period.value) gün"
        }
    }

    /// Yıllık planın aya düşen tutarı, ürünün kendi para biriminde.
    static var monthlyEquivalent: String? {
        guard let annual = ProPlan.yearly.package?.storeProduct,
              let formatter = annual.priceFormatter else { return nil }
        return formatter.string(from: NSDecimalNumber(decimal: annual.price / 12))
    }

    /// Yıllık planın aylığa göre tasarrufu (%). Offerings yüklenmeden de
    /// referans fiyatlarla hesaplanır, böylece rozet her zaman görünür.
    static var savingsPercent: Int? {
        // Decimal aritmetiği yerine Double: hesap tek satır ve yuvarlama net.
        let annual = double(ProPlan.yearly.package?.storeProduct.price) ?? 299.99
        let monthly = double(ProPlan.monthly.package?.storeProduct.price) ?? 49.99
        guard annual > 0, monthly > 0 else { return nil }
        let pct = Int((((1 - (annual / 12) / monthly)) * 100).rounded())
        return pct > 0 ? pct : nil
    }

    private static func double(_ value: Decimal?) -> Double? {
        value.map { NSDecimalNumber(decimal: $0).doubleValue }
    }
}

/// Where the paywall was opened from — drives the context-aware sub-headline so a
/// feature-gate prompt leads with the benefit the user was just reaching for.
enum PaywallContext: Identifiable {
    case general, onboarding, fund, portfolioLimit, ads

    var id: String { analyticsName }

    /// Stable identifier for analytics (independent of localized copy).
    var analyticsName: String {
        switch self {
        case .general:        return "general"
        case .onboarding:     return "onboarding"
        case .fund:           return "fund"
        case .portfolioLimit: return "portfolio_limit"
        case .ads:            return "ads"
        }
    }

    var headline: String {
        switch self {
        case .fund:           return "Fonlarını da\nburada takip et."
        case .portfolioLimit: return "Her hedefe\nayrı portföy."
        case .ads:            return "Reklamlar olmadan\ndaha rahat."
        case .onboarding, .general: return "Portföyünün\ntamamını gör."
        }
    }

    var subtitle: String {
        switch self {
        case .fund:
            return "TEFAS fonları Pro ile açılıyor — diğer iki özellikle birlikte."
        case .portfolioLimit:
            return "Portföy sınırı Pro ile kalkıyor — diğer iki özellikle birlikte."
        case .ads:
            return "Reklamlar Pro ile kapanıyor — diğer iki özellikle birlikte."
        case .onboarding, .general:
            return "Üç özellik şu an kilitli. Pro ile üçü birden açılıyor."
        }
    }
}

/// Reklam yerine paywall: "Reklamsız Deneyim" üç Pro özelliğinden en çok
/// karşılaşılanı ama tek tetikleyicisi yoktu. Sayaç *gösterilebilir interstitial
/// fırsatlarını* sayar (varlık eklemeyi değil) — eklemelerin çoğu 30 sn cooldown
/// ya da yüklü reklam olmaması yüzünden zaten reklama dönüşmüyor.
enum AdPaywallGate {
    /// ponytail: sabitler; Firebase'de `paywall_shown(context: ads)` dönüşümü
    /// görülünce Remote Config'e taşınabilir.
    static let everyNthAd = 3
    private static let cooldown: TimeInterval = 7 * 24 * 60 * 60

    private static let countKey = "ad_paywall_opportunity_count"
    private static let lastShownKey = "ad_paywall_last_shown"

    /// Bir interstitial fırsatında çağrılır ve fırsatı sayar. `true` dönerse o
    /// sefer reklam yerine paywall açılır.
    static func shouldShowPaywall(_ defaults: UserDefaults = .standard) -> Bool {
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)
        Logger.log("💎 AdPaywallGate: fırsat #\(count)")
        guard count % everyNthAd == 0 else { return false }
        // Haftalık tavan: engellenirse sayaç akmaya devam eder, bir sonraki
        // deneme 3 reklam sonra olur.
        if let last = defaults.object(forKey: lastShownKey) as? Date,
           Date().timeIntervalSince(last) < cooldown { return false }
        defaults.set(Date(), forKey: lastShownKey)
        return true
    }

    #if DEBUG
    /// Tek çalıştırılabilir kontrol: her 3. fırsatta true, haftalık tavan ikinciyi
    /// yutar. Test target'ı yok, bu yüzden launch'ta assert olarak koşuyor.
    static func selfCheck() {
        let suite = UserDefaults(suiteName: "ad-paywall-selfcheck")!
        defer { UserDefaults().removePersistentDomain(forName: "ad-paywall-selfcheck") }
        // Suite okumaları uygulamanın kendi domain'ine düşer, silmek yetmez —
        // temiz başlangıç için değerleri açıkça yazıyoruz.
        suite.set(0, forKey: countKey)
        suite.set(Date.distantPast, forKey: lastShownKey)

        let first = (1...3).map { _ in shouldShowPaywall(suite) }
        assert(first == [false, false, true], "3. fırsatta paywall çıkmalı: \(first)")

        // 4-6: sayaç yine 3'ün katına gelir ama hafta dolmadığı için engellenir.
        let second = (4...6).map { _ in shouldShowPaywall(suite) }
        assert(second == [false, false, false], "Haftalık tavan tutmadı: \(second)")

        // Tavan geçmişte kalınca tekrar açılır.
        suite.set(Date().addingTimeInterval(-8 * 24 * 60 * 60), forKey: lastShownKey)
        let third = (7...9).map { _ in shouldShowPaywall(suite) }
        assert(third == [false, false, true], "Tavan dolduktan sonra açılmalı: \(third)")
    }
    #endif
}

struct PaywallView: View {
    /// Called when the sheet should close (purchase completed or dismissed).
    var onClose: () -> Void
    /// Where this paywall was triggered from (defaults to a generic prompt).
    var context: PaywallContext = .general

    @Environment(\.openURL) private var openURL
    @StateObject private var userDefaults = UserDefaultsManager.shared
    @StateObject private var purchases = PurchaseManager.shared
    @State private var selectedPlan: ProPlan = .yearly
    @State private var alertMessage: String?
    @State private var showingPrivacy = false
    /// Paywall'ın açıldığı an — kapatmada "kaç saniye bakıldı" için.
    @State private var shownAt = Date()

    /// Apple's standard EULA — used unless a custom Terms of Use URL is provided.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("hand.thumbsup.fill", "Reklamsız Deneyim", "Kesintisiz, temiz bir arayüz"),
        ("chart.pie.fill", "Fon Ekleme", "TEFAS yatırım fonlarını takip et"),
        ("infinity", "Sınırsız Portföy", "İstediğin kadar portföy oluştur")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    closeRow
                    eyebrow
                    headline
                    featureList
                        .padding(.top, 28)
                    planPicker
                        .padding(.top, 28)
                    selectionSummary
                        .padding(.top, 12)
                    ctaButton
                        .padding(.top, 32)
                    finePrint
                        .padding(.top, 12)
                    legalLinks
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            if purchases.purchaseInProgress {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.4)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear {
            shownAt = Date()
            FirebaseAnalyticsHelper.shared.logPaywallShown(context: context.analyticsName)
        }
        .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
        .alert("Bilgi", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Header

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: {
                FirebaseAnalyticsHelper.shared.logPaywallDismissed(
                    context: context.analyticsName,
                    secondsShown: Int(Date().timeIntervalSince(shownAt))
                )
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }

    private var eyebrow: some View {
        HStack(spacing: 7) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12, weight: .bold))
            Text("VARLIK TAKİBİ PRO")
                .font(.system(size: 12, weight: .bold))
                .kerning(1.2)
        }
        .foregroundColor(ProStyle.accent)
        .padding(.top, 4)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(context.headline)
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Capsule()
                .fill(ProStyle.accent)
                .frame(width: 88, height: 3)

            Text(context.subtitle)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element.title) { index, feature in
                if index > 0 { Divider() }
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(ProStyle.tint)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: feature.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ProStyle.accent)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.system(size: 17, weight: .semibold))
                        Text(feature.subtitle).font(.system(size: 14)).foregroundColor(.secondary)
                    }
                    Spacer(minLength: 8)
                    // Kilit: bu üç özelliğin şu an kapalı olduğunu tek bakışta anlatır.
                    Image(systemName: "lock.open")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ProStyle.accent.opacity(0.7))
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Plans

    private var planPicker: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(ProPlan.allCases) { plan in
                planColumn(plan)
            }
        }
        .padding(.top, 12) // rozetin kartın dışına taşan yarısı için
    }

    private func planColumn(_ plan: ProPlan) -> some View {
        let isSelected = selectedPlan == plan
        let badge = (plan == .yearly) ? ProPlan.savingsPercent.map { "%\($0) avantajlı" } : nil
        return Button {
            FirebaseAnalyticsHelper.shared.logPaywallPlanSelected(plan: plan.rawValue)
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
        } label: {
            VStack(spacing: 3) {
                Text(plan.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)
                Text(plan.price)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(plan == .yearly ? (ProPlan.monthlyEquivalent.map { "ayda \($0)" } ?? plan.cadence) : plan.cadence)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            // Üstte fazladan boşluk: rozet başlığın üstüne binmesin (kartların
            // yükseklikleri eşit kalsın diye rozeti olmayanlarda da var).
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? ProStyle.accent.opacity(0.10) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ProStyle.accent : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(ProStyle.accent))
                        // Üst çizgi rozetin ortasından geçer; birkaç punto yukarı
                        // kaydırılınca çoğunluğu kartın dışında kalır.
                        .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Seçili planı ve gerçek maliyetini tek satırda özetler.
    private var selectionSummary: some View {
        Text(summaryText)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private var summaryText: String {
        let base = "\(selectedPlan.title) plan seçildi · \(selectedPlan.price)/\(selectedPlan.periodWord)"
        guard let trial = selectedPlan.freeTrial else { return base }
        return "\(base) · ilk \(trial) ücretsiz"
    }

    // MARK: - CTA

    private var ctaButton: some View {
        // Offerings must be loaded before a purchase can start.
        let ready = selectedPlan.package != nil
        return Button(action: startPurchase) {
            HStack(spacing: 8) {
                Text(ctaTitle)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(ProStyle.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ProStyle.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ProStyle.accent, lineWidth: 1.5)
            )
            .opacity(ready ? 1 : 0.5)
        }
        .disabled(purchases.purchaseInProgress || !ready)
    }

    private var ctaTitle: String {
        selectedPlan.freeTrial != nil ? "Ücretsiz Dene" : "Pro'ya Geç"
    }

    private var finePrint: some View {
        Text(finePrintText)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// Terms of Use (EULA) + Privacy Policy + restore — required by App Store Review
    /// Guideline 3.1.2 for auto-renewable subscriptions.
    private var legalLinks: some View {
        HStack(spacing: 18) {
            Button("Kullanım Şartları") { openURL(termsURL) }
            Button("Gizlilik Politikası") { showingPrivacy = true }
            Button("Geri Yükle") { restorePurchases() }
                .disabled(purchases.purchaseInProgress)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }

    /// Built from the live price + actual trial state, with the auto-renewal
    /// disclosure App Store Review requires.
    private var finePrintText: String {
        let renew = "Abonelik otomatik yenilenir; dönem bitiminden en az 24 saat önce iptal etmezsen aynı ücretle yenilenir."
        guard selectedPlan.package != nil else { return renew }
        let price = selectedPlan.price
        let period = selectedPlan.periodWord
        if let trial = selectedPlan.freeTrial {
            return "\(trial) ücretsiz, sonra \(price)/\(period). \(renew)"
        }
        return "\(price)/\(period). \(renew)"
    }

    // MARK: - Purchase actions

    private func startPurchase() {
        guard let package = selectedPlan.package else {
            alertMessage = "Abonelik seçenekleri yüklenemedi. Lütfen internet bağlantını kontrol edip tekrar dene."
            return
        }
        let plan = selectedPlan.rawValue
        let hadTrial = selectedPlan.freeTrial != nil
        FirebaseAnalyticsHelper.shared.logPaywallCtaTapped(plan: plan, hasTrial: hadTrial)
        Task {
            switch await purchases.purchase(package) {
            case .subscribed:
                // `PurchaseManager` already set `isPro` and hid the banner.
                FirebaseAnalyticsHelper.shared.logSubscriptionPurchased(plan: plan, hadTrial: hadTrial)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClose()
            case .cancelled:
                // Normal bir vazgeçiş; kullanıcıya uyarı gösterilmez.
                FirebaseAnalyticsHelper.shared.logSubscriptionPurchaseFailed(
                    plan: plan, reason: "cancelled", errorCode: nil
                )
            case .failed(let code, let message):
                FirebaseAnalyticsHelper.shared.logSubscriptionPurchaseFailed(
                    plan: plan, reason: "error", errorCode: code
                )
                // Gerçek hatada sessiz kalmak kullanıcıyı butona tekrar tekrar
                // bastırıyordu; ne olduğu söylenmeli.
                alertMessage = "Satın alma tamamlanamadı: \(message)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func restorePurchases() {
        Task {
            let success = await purchases.restore()
            if success {
                FirebaseAnalyticsHelper.shared.logSubscriptionRestored()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClose()
            } else {
                alertMessage = "Geri yüklenecek aktif bir abonelik bulunamadı."
            }
        }
    }
}
