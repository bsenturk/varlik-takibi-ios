//
//  PaywallView.swift
//  MyGolds
//
//  "Varlık Pro" paywall — UI only for now, backed by a local `isPro` flag.
//

import SwiftUI

struct PaywallView: View {
    /// Called when the sheet should close (purchase completed or dismissed).
    var onClose: () -> Void

    @StateObject private var userDefaults = UserDefaultsManager.shared
    @State private var selectedPlan: Plan = .yearly

    private enum Plan { case yearly, monthly }

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("infinity", "Sınırsız Portföy Ekleme", "İstediğiniz kadar portföy oluşturun"),
        ("hand.thumbsup.fill", "Reklamsız Deneyim", "Kesintisiz, temiz bir arayüz")
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
                    ctaButton
                    finePrint
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
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
            Text("Varlık Pro")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(brandGradient)
            Text("Tüm özelliklerin kilidini açın,\nvarlıklarınızı tam kontrol edin.")
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
            planCard(
                plan: .yearly,
                title: "Yıllık",
                subtitle: "Aylık yalnızca ₺24,99",
                price: "₺299,99",
                period: "/yıl",
                badge: "%50 Avantajlı"
            )
            planCard(
                plan: .monthly,
                title: "Aylık",
                subtitle: "İlk 7 gün ücretsiz",
                price: "₺49,99",
                period: "/ay",
                badge: nil
            )
        }
    }

    private func planCard(plan: Plan, title: String, subtitle: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
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

    private var ctaButton: some View {
        Button(action: startTrial) {
            Text("Ücretsiz Denemeyi Başlat")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    private var finePrint: some View {
        Text(selectedPlan == .yearly
             ? "7 gün ücretsiz, sonra ₺299,99/yıl. İstediğiniz zaman iptal edin."
             : "7 gün ücretsiz, sonra ₺49,99/ay. İstediğiniz zaman iptal edin.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }

    private func startTrial() {
        // UI-only: flip the local entitlement flag. Real StoreKit purchase wires in later.
        userDefaults.isPro = true
        // Immediately remove the banner now that the user is Pro.
        AdMobManager.shared.hideBanner()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onClose()
    }
}
