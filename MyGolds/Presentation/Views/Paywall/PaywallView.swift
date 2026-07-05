//
//  PaywallView.swift
//  MyGolds
//
//  "Varlık Pro" paywall — backed by RevenueCat offerings + a local `isPro` flag.
//

import SwiftUI
import RevenueCat

/// Where the paywall was opened from — drives the context-aware sub-headline so a
/// feature-gate prompt leads with the benefit the user was just reaching for.
enum PaywallContext {
    case general, onboarding, fund, portfolioLimit

    /// Stable identifier for analytics (independent of localized copy).
    var analyticsName: String {
        switch self {
        case .general:        return "general"
        case .onboarding:     return "onboarding"
        case .fund:           return "fund"
        case .portfolioLimit: return "portfolio_limit"
        }
    }

    var subtitle: String {
        switch self {
        case .fund:
            return "TEFAS yatırım fonlarını da portföyüne ekle —\nVarlık Takibi Pro ile kilidi aç."
        case .portfolioLimit:
            return "Her hedefe ayrı portföy oluştur —\nVarlık Takibi Pro ile portföy sınırını kaldır."
        case .onboarding, .general:
            return "Tüm özelliklerin kilidini aç,\nvarlıklarını tam kontrol et."
        }
    }
}

struct PaywallView: View {
    /// Called when the sheet should close (purchase completed or dismissed).
    var onClose: () -> Void
    /// Where this paywall was triggered from (defaults to a generic prompt).
    var context: PaywallContext = .general

    @Environment(\.openURL) private var openURL
    @StateObject private var userDefaults = UserDefaultsManager.shared
    @StateObject private var purchases = PurchaseManager.shared
    @State private var selectedPlan: Plan = .yearly
    @State private var alertMessage: String?
    @State private var showingPrivacy = false

    /// Apple's standard EULA — used unless a custom Terms of Use URL is provided.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private enum Plan { case yearly, monthly, weekly }

    /// Stable analytics identifier for a plan (independent of localized copy).
    private func planName(_ plan: Plan) -> String {
        switch plan {
        case .yearly:  return "yearly"
        case .monthly: return "monthly"
        case .weekly:  return "weekly"
        }
    }

    /// Exact App Store product identifiers — used to locate the right package by
    /// product when the offering doesn't use RevenueCat's standard package types.
    private func productID(for plan: Plan) -> String {
        switch plan {
        case .yearly:  return "com.xptapps.assetbook.premium.yearly"
        case .monthly: return "com.xptapps.assetbook.premium.monthly"
        case .weekly:  return "com.xptapps.assetbook.premium.weekly"
        }
    }

    /// Live RevenueCat package backing a plan card. Prefers the standard
    /// Annual/Monthly/Weekly accessor, then falls back to matching by product id
    /// so the card works whether packages use standard or custom identifiers.
    private func package(for plan: Plan) -> Package? {
        guard let offering = purchases.currentOffering else { return nil }
        let standard: Package?
        switch plan {
        case .yearly:  standard = offering.annual
        case .monthly: standard = offering.monthly
        case .weekly:  standard = offering.weekly
        }
        if let standard { return standard }
        return offering.availablePackages.first { $0.storeProduct.productIdentifier == productID(for: plan) }
    }

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("hand.thumbsup.fill", "Reklamsız Deneyim", "Kesintisiz, temiz bir arayüz"),
        ("chart.pie.fill", "Fon Ekleme", "TEFAS yatırım fonlarını takip et"),
        ("infinity", "Sınırsız Portföy", "İstediğin kadar portföy oluştur")
    ]

    private let brandGradient = LinearGradient(
        colors: [Color(hex: "#007AFF"), Color(hex: "#AF52DE"), Color(hex: "#FF2D55")],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: "#EAF0FF"), Color(.systemBackground)],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    closeRow
                    crown
                    titleBlock
                    featureList
                    planCards
                    if selectedTrial != nil { trialBadge }
                    ctaButton
                    finePrint
                    legalLinks
                    restoreButton
                }
                .padding(.horizontal, 22)
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
        .onAppear { FirebaseAnalyticsHelper.shared.logPaywallShown(context: context.analyticsName) }
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

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: {
                FirebaseAnalyticsHelper.shared.logPaywallDismissed(context: context.analyticsName)
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }

    private var crown: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(brandGradient)
            .frame(width: 86, height: 86)
            .overlay(
                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            )
            .shadow(color: Color(hex: "#AF52DE").opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text("Varlık Takibi Pro")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(brandGradient)
            Text(context.subtitle)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(spacing: 16) {
            ForEach(features, id: \.title) { feature in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(brandGradient).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.system(size: 16, weight: .semibold))
                        Text(feature.subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            planCard(plan: .yearly,  title: "Yıllık",   period: "/yıl",    fallbackPrice: "₺299,99")
            planCard(plan: .monthly, title: "Aylık",    period: "/ay",     fallbackPrice: "₺49,99")
            planCard(plan: .weekly,  title: "Haftalık", period: "/hafta",  fallbackPrice: "₺14,99")
        }
    }

    private func planCard(plan: Plan, title: String, period: String, fallbackPrice: String) -> some View {
        let isSelected = selectedPlan == plan
        // Prefer the live App Store price from RevenueCat; fall back to static copy
        // only until offerings load (or in previews).
        let price = package(for: plan)?.storeProduct.localizedPriceString ?? fallbackPrice
        let subtitle = planSubtitle(for: plan)
        let badge = (plan == .yearly) ? savingsBadge() : nil
        return Button {
            FirebaseAnalyticsHelper.shared.logPaywallPlanSelected(plan: planName(plan))
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "#AF52DE") : .secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 17, weight: .bold))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(hex: "#FF2D55"))
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle).font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(price).font(.system(size: 18, weight: .heavy))
                    Text(period).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#AF52DE") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Trial reassurance shown right above the CTA — surfaces the free-trial length
    /// (e.g. "3 gün") at the decision point. Only rendered when the selected plan
    /// actually carries a trial, so the messaging stays App Store-honest.
    private var trialBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: "gift.fill")
                .font(.system(size: 13, weight: .bold))
            Text(selectedTrial.map { "İlk \($0) ücretsiz · Dilediğin an iptal et" } ?? "")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(brandGradient)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#AF52DE").opacity(0.1))
        )
    }

    private var ctaButton: some View {
        // Offerings must be loaded before a purchase can start; keep the CTA inert
        // (and honest about a trial only when the product actually has one) until then.
        let ready = package(for: selectedPlan) != nil
        return Button(action: startPurchase) {
            Text(ctaTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 12, x: 0, y: 6)
                .opacity(ready ? 1 : 0.5)
        }
        .disabled(purchases.purchaseInProgress || !ready)
    }

    private var restoreButton: some View {
        Button(action: restorePurchases) {
            Text("Satın Alımları Geri Yükle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .disabled(purchases.purchaseInProgress)
    }

    private var finePrint: some View {
        Text(finePrintText)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }

    /// Terms of Use (EULA) + Privacy Policy links — required by App Store Review
    /// Guideline 3.1.2 for auto-renewable subscriptions.
    private var legalLinks: some View {
        HStack(spacing: 8) {
            Button("Kullanım Şartları") { openURL(termsURL) }
            Text("·").foregroundColor(.secondary)
            Button("Gizlilik Politikası") { showingPrivacy = true }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)
    }

    // MARK: - Dynamic pricing / trial helpers

    /// The free-trial length of the currently selected plan, if any.
    private var selectedTrial: String? { freeTrial(for: selectedPlan) }

    /// CTA copy honestly reflects whether the selected plan carries a free trial.
    private var ctaTitle: String {
        selectedTrial != nil ? "Deneme Sürümünü Başlat" : "Pro'ya Geç"
    }

    /// Per-plan subtitle. Yearly anchors on its monthly-equivalent price; the others
    /// describe their flexibility. The free-trial line is intentionally NOT repeated
    /// here — it's shown once, canonically, in `trialBadge` above the CTA.
    private func planSubtitle(for plan: Plan) -> String {
        switch plan {
        case .yearly:
            if let monthly = monthlyEquivalentString() { return "Aylık yalnızca \(monthly)" }
            return "En avantajlı plan"
        case .monthly:
            return "Esnek, dilediğin zaman iptal et"
        case .weekly:
            return "Kısa vadeli, esnek seçenek"
        }
    }

    /// The yearly price expressed per-month, in the product's own locale/currency.
    private func monthlyEquivalentString() -> String? {
        guard let annual = package(for: .yearly)?.storeProduct,
              let formatter = annual.priceFormatter else { return nil }
        let perMonth = annual.price / 12
        return formatter.string(from: NSDecimalNumber(decimal: perMonth))
    }

    /// Savings of the annual plan vs paying monthly, as a whole percentage. Uses the
    /// live App Store prices when available and otherwise falls back to the static
    /// reference prices (kept in sync with `planCards`) so the value badge always
    /// renders — even before offerings load.
    private func savingsBadge() -> String? {
        let annualPrice: Decimal
        let monthlyPrice: Decimal
        if let annual = package(for: .yearly)?.storeProduct,
           let monthly = package(for: .monthly)?.storeProduct,
           monthly.price > 0 {
            annualPrice = annual.price
            monthlyPrice = monthly.price
        } else {
            annualPrice = 299.99   // ₺299,99 / yıl
            monthlyPrice = 49.99   // ₺49,99 / ay
        }
        let annualPerMonth = annualPrice / 12
        let pct = (1 - annualPerMonth / monthlyPrice) * 100
        let value = NSDecimalNumber(decimal: pct).intValue
        return value > 0 ? "%\(value) avantajlı" : nil
    }

    /// Free-trial length for a plan, if its product is configured with one.
    private func freeTrial(for plan: Plan) -> String? {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial else { return nil }
        return localizedPeriod(discount.subscriptionPeriod)
    }

    private func localizedPeriod(_ period: SubscriptionPeriod) -> String {
        let n = period.value
        switch period.unit {
        case .day:   return "\(n) gün"
        case .week:  return "\(n) hafta"
        case .month: return "\(n) ay"
        case .year:  return "\(n) yıl"
        @unknown default: return "\(n) gün"
        }
    }

    private func periodWord(for plan: Plan) -> String {
        switch plan {
        case .yearly:  return "yıl"
        case .monthly: return "ay"
        case .weekly:  return "hafta"
        }
    }

    /// Built from the live price + actual trial state, with the auto-renewal
    /// disclosure App Store Review requires.
    private var finePrintText: String {
        let renew = "Abonelik otomatik yenilenir; dönem bitiminden en az 24 saat önce iptal etmezsen aynı ücretle yenilenir. İstediğin zaman iptal edebilirsin."
        guard let pkg = package(for: selectedPlan) else { return renew }
        let price = pkg.storeProduct.localizedPriceString
        let period = periodWord(for: selectedPlan)
        if let trial = freeTrial(for: selectedPlan) {
            return "\(trial) ücretsiz, sonra \(price)/\(period). \(renew)"
        }
        return "\(price)/\(period). \(renew)"
    }

    // MARK: - Purchase actions

    private func startPurchase() {
        guard let package = package(for: selectedPlan) else {
            alertMessage = "Abonelik seçenekleri yüklenemedi. Lütfen internet bağlantını kontrol edip tekrar dene."
            return
        }
        let plan = planName(selectedPlan)
        let hadTrial = selectedTrial != nil
        FirebaseAnalyticsHelper.shared.logPaywallCtaTapped(plan: plan, hasTrial: hadTrial)
        Task {
            let success = await purchases.purchase(package)
            if success {
                // `PurchaseManager` already set `isPro` and hid the banner.
                FirebaseAnalyticsHelper.shared.logSubscriptionPurchased(plan: plan, hadTrial: hadTrial)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClose()
            } else {
                // Covers both store errors and user cancellation (drop-off signal).
                FirebaseAnalyticsHelper.shared.logSubscriptionPurchaseFailed(plan: plan)
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
