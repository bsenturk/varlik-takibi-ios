//
//  PaywallView.swift
//  MyGolds
//
//  Created by Claude on 27.10.2025.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var revenueCat = RevenueCatManager.shared
    @State private var selectedPackageType: PackageType = .annual
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "FFD700"),
                        Color(hex: "FFA500")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Close button
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.trailing)
                        }
                        .padding(.top, 8)

                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)

                            Text("Varlık Takibi Premium")
                                .font(.custom("WorkSans-Bold", size: 28))
                                .foregroundColor(.white)

                            Text("Reklamlardan kurtulun ve tüm özelliklere erişin")
                                .font(.custom("WorkSans-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)

                        // Features
                        VStack(spacing: 16) {
                            ForEach(SubscriptionProduct.features, id: \.self) { feature in
                                FeatureRow(text: feature)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)

                        // Packages
                        if let offerings = revenueCat.offerings?.current {
                            VStack(spacing: 12) {
                                if let yearlyPackage = offerings.annual {
                                    PackageCard(
                                        package: yearlyPackage,
                                        isSelected: selectedPackageType == .annual,
                                        isPopular: true
                                    ) {
                                        selectedPackageType = .annual
                                    }
                                }

                                if let monthlyPackage = offerings.monthly {
                                    PackageCard(
                                        package: monthlyPackage,
                                        isSelected: selectedPackageType == .monthly,
                                        isPopular: false
                                    ) {
                                        selectedPackageType = .monthly
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            ProgressView()
                                .tint(.white)
                        }

                        // Purchase Button
                        Button(action: purchaseSelected) {
                            HStack {
                                if revenueCat.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Premium'a Başla")
                                        .font(.custom("WorkSans-Bold", size: 18))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(Color(hex: "FFA500"))
                            .cornerRadius(16)
                        }
                        .disabled(revenueCat.isLoading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Restore button
                        Button(action: restorePurchases) {
                            Text("Satın Alımları Geri Yükle")
                                .font(.custom("WorkSans-Medium", size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.bottom, 8)

                        // Terms
                        VStack(spacing: 4) {
                            Text("Abonelik otomatik olarak yenilenir.")
                                .font(.custom("WorkSans-Regular", size: 12))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 4) {
                                Button(action: { /* Privacy policy */ }) {
                                    Text("Gizlilik Politikası")
                                }
                                Text("•")
                                Button(action: { /* Terms */ }) {
                                    Text("Kullanım Koşulları")
                                }
                            }
                            .font(.custom("WorkSans-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Başarılı!", isPresented: $showSuccess) {
                Button("Tamam", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Premium aboneliğiniz başarıyla aktif edildi!")
            }
        }
    }

    private func purchaseSelected() {
        guard let offering = revenueCat.offerings?.current else {
            errorMessage = "Paketler yüklenemedi. Lütfen tekrar deneyin."
            showError = true
            return
        }

        let package: Package?
        switch selectedPackageType {
        case .annual:
            package = offering.annual
        case .monthly:
            package = offering.monthly
        default:
            package = nil
        }

        guard let package = package else {
            errorMessage = "Seçilen paket bulunamadı."
            showError = true
            return
        }

        Task {
            do {
                _ = try await revenueCat.purchase(package: package)
                showSuccess = true

                // Notify ad manager to hide ads
                AdMobManager.shared.hideBanner()

            } catch {
                errorMessage = "Satın alma işlemi başarısız oldu: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                let customerInfo = try await revenueCat.restorePurchases()

                if customerInfo.entitlements[RevenueCatManager.entitlementId]?.isActive == true {
                    showSuccess = true
                } else {
                    errorMessage = "Geri yüklenecek satın alım bulunamadı."
                    showError = true
                }
            } catch {
                errorMessage = "Geri yükleme başarısız: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)

            Text(text)
                .font(.custom("WorkSans-Medium", size: 16))
                .foregroundColor(.white)

            Spacer()
        }
    }
}

// MARK: - Package Card

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let isPopular: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Popular badge
                if isPopular {
                    HStack {
                        Spacer()
                        Text("EN POPÜLER")
                            .font(.custom("WorkSans-Bold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FF6B6B"))
                            .cornerRadius(8)
                        Spacer()
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(packageTitle)
                            .font(.custom("WorkSans-Bold", size: 20))
                            .foregroundColor(isSelected ? Color(hex: "FFA500") : .primary)

                        Text(packageDescription)
                            .font(.custom("WorkSans-Regular", size: 14))
                            .foregroundColor(isSelected ? Color(hex: "FFA500").opacity(0.8) : .secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(package.localizedPriceString)
                            .font(.custom("WorkSans-Bold", size: 24))
                            .foregroundColor(isSelected ? Color(hex: "FFA500") : .primary)

                        if let savings = calculateSavings() {
                            Text(savings)
                                .font(.custom("WorkSans-Medium", size: 12))
                                .foregroundColor(.green)
                        }
                    }
                }

                if isSelected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "FFA500"))
                        Text("Seçildi")
                            .font(.custom("WorkSans-Medium", size: 14))
                            .foregroundColor(Color(hex: "FFA500"))
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "FFA500") : Color.clear, lineWidth: 3)
            )
            .shadow(color: isSelected ? Color(hex: "FFA500").opacity(0.3) : .black.opacity(0.1), radius: 8)
        }
        .buttonStyle(.plain)
    }

    private var packageTitle: String {
        switch package.packageType {
        case .annual:
            return "Yıllık Premium"
        case .monthly:
            return "Aylık Premium"
        default:
            return "Premium"
        }
    }

    private var packageDescription: String {
        switch package.packageType {
        case .annual:
            return "Yılda bir yenilenir"
        case .monthly:
            return "Her ay yenilenir"
        default:
            return ""
        }
    }

    private func calculateSavings() -> String? {
        if package.packageType == .annual {
            // Calculate monthly equivalent
            let yearlyPrice = package.storeProduct.price.doubleValue
            let monthlyEquivalent = yearlyPrice / 12.0

            // Assuming monthly is around 49.99
            let monthlySaving = 49.99 - monthlyEquivalent

            if monthlySaving > 0 {
                return String(format: "Ayda ~₺%.0f tasarruf", monthlySaving)
            }
        }
        return nil
    }
}

#Preview {
    PaywallView()
}
