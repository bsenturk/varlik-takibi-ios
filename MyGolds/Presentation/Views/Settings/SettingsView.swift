//
//  SettingsView.swift - Updated with Dynamic Version
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var showingRateApp = false
    @State private var showingFeedback = false
    @State private var showingShare = false
    @State private var showingPrivacyPolicy = false
    @State private var showingDarkModeSettings = false
    @State private var showingPaywall = false
    @State private var shareItem: ShareItem?
    @StateObject private var userDefaults = UserDefaultsManager.shared
    @StateObject private var revenueCat = RevenueCatManager.shared
    
    // Share için struct
    struct ShareItem: Identifiable {
        let id = UUID()
        let text: String
        let url: URL?
    }
    
    // Debug için
    @StateObject private var appOpenAdManager = AppOpenAdManager.shared
    @StateObject private var adManager = AdMobManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Ayarlar")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // DEBUG SECTION - Sadece debug modda görünür
                    #if DEBUG
                    debugSection
                    notificationDebugSection
                    #endif
                    
                    // Premium Banner (if not premium)
                    if !revenueCat.isPremium {
                        premiumBanner
                    }

                    // Settings Items
                    VStack(spacing: 12) {
                        // Premium Status / Upgrade Button
                        if revenueCat.isPremium {
                            SettingsItemView(
                                icon: "crown.fill",
                                iconColor: .yellow,
                                title: "Premium Üye",
                                subtitle: "Tüm özellikler aktif",
                                action: {}
                            )
                        } else {
                            SettingsItemView(
                                icon: "crown.fill",
                                iconColor: .orange,
                                title: "Premium'a Yükselt",
                                subtitle: "Reklamları kaldır ve daha fazlası",
                                action: { showingPaywall = true }
                            )
                        }

                        SettingsItemView(
                            icon: getCurrentThemeIcon(),
                            iconColor: .indigo,
                            title: "Görünüm Modu",
                            subtitle: getCurrentThemeDescription(),
                            action: { showingDarkModeSettings = true }
                        )
                        
                        SettingsItemView(
                            icon: "message.fill",
                            iconColor: .purple,
                            title: "Bildirim Tercihleri",
                            subtitle: "Bildirim tercihlerinizi yönetin",
                            action: { openNotificationSettings() }
                        )
                        
                        SettingsItemView(
                            icon: "star.fill",
                            iconColor: .yellow,
                            title: "Uygulamaya Puan Ver",
                            subtitle: "App Store'da değerlendirin",
                            action: { showingRateApp = true }
                        )
                        
                        SettingsItemView(
                            icon: "envelope.fill",
                            iconColor: .blue,
                            title: "Geri Bildirim Gönder",
                            subtitle: "Görüş ve önerilerinizi paylaşın",
                            action: { showingFeedback = true }
                        )
                        
                        // Direkt iOS Native Share Sheet
                        SettingsItemView(
                            icon: "square.and.arrow.up.fill",
                            iconColor: .green,
                            title: "Uygulamayı Paylaş",
                            subtitle: "Arkadaşlarınızla paylaşın",
                            action: {
                                shareItem = ShareItem(
                                    text: "Varlık Takibi uygulamasını keşfedin! Altın ve döviz varlıklarınızı kolayca takip edin.",
                                    url: URL(string: "https://apps.apple.com/app/id6479618311")
                                )
                            }
                        )
                        
                        SettingsItemView(
                            icon: "shield.fill",
                            iconColor: .gray,
                            title: "Gizlilik Politikası",
                            subtitle: "Verileriniz nasıl korunur",
                            action: { showingPrivacyPolicy = true }
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // App Info - Dynamic Version
                    VStack(spacing: 8) {
                        Text(AppVersionHelper.appName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(AppVersionHelper.displayVersionString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("© 2024 Varlık Takibi. Tüm hakları saklıdır.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                }
            }
        }
        .sheet(isPresented: $showingRateApp) {
            RateAppView()
        }
        .sheet(isPresented: $showingFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingDarkModeSettings) {
            DarkModeSettingsView()
        }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $shareItem) { item in
            if let url = item.url {
                ActivityViewController(activityItems: [item.text, url])
            } else {
                ActivityViewController(activityItems: [item.text])
            }
        }
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        Button(action: { showingPaywall = true }) {
            HStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Premium'a Geçin")
                        .font(.custom("WorkSans-Bold", size: 18))
                        .foregroundColor(.white)

                    Text("Reklamları kaldırın ve daha fazlası")
                        .font(.custom("WorkSans-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "FFD700"),
                        Color(hex: "FFA500")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(hex: "FFA500").opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
    
    // MARK: - Dark Mode Helper Methods
    
    private func getCurrentThemeIcon() -> String {
        return userDefaults.darkModePreference.iconName
    }
    
    private func getCurrentThemeDescription() -> String {
        return "\(userDefaults.darkModePreference.displayName) tema aktif"
    }
    
    #if DEBUG
    private var debugSection: some View {
        VStack(spacing: 12) {
            Text("🐛 DEBUG - App Open Ad Test")
                .font(.headline)
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Ad Loaded:")
                    Spacer()
                    Text(appOpenAdManager.isAdLoaded ? "✅ YES" : "❌ NO")
                        .foregroundColor(appOpenAdManager.isAdLoaded ? .green : .red)
                }
                
                HStack {
                    Text("Ad Loading:")
                    Spacer()
                    Text(appOpenAdManager.isLoadingAd ? "⏳ YES" : "⏹️ NO")
                        .foregroundColor(appOpenAdManager.isLoadingAd ? .orange : .gray)
                }
                
                HStack {
                    Text("Can Show:")
                    Spacer()
                    Text(appOpenAdManager.canShowAd ? "✅ YES" : "❌ NO")
                        .foregroundColor(appOpenAdManager.canShowAd ? .green : .red)
                }
                
                HStack {
                    Text("Currently Showing:")
                    Spacer()
                    Text(appOpenAdManager.isAdShowing ? "📱 YES" : "💤 NO")
                        .foregroundColor(appOpenAdManager.isAdShowing ? .blue : .gray)
                }
                
                HStack {
                    Text("Banner Showing:")
                    Spacer()
                    Text(adManager.shouldShowBanner ? "📰 YES" : "🚫 NO")
                        .foregroundColor(adManager.shouldShowBanner ? .green : .red)
                }
            }
            .font(.caption)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("🔄 Load Ad") {
                    appOpenAdManager.loadAd()
                }
                .buttonStyle(.bordered)
                
                Button("📱 Force Show") {
                    appOpenAdManager.forceShowAd()
                }
                .buttonStyle(.borderedProminent)
                
                Button("⏰ Reset Timer") {
                    appOpenAdManager.resetAdInterval()
                }
                .buttonStyle(.bordered)
            }
            
            Button("🧪 Simulate App Return") {
                // Simulate returning from background
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    appOpenAdManager.showAdIfAvailable()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    private var notificationDebugSection: some View {
        VStack(spacing: 12) {
            Text("🔔 DEBUG - Notification Test")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Authorized:")
                    Spacer()
                    Text(notificationManager.isAuthorized ? "✅ YES" : "❌ NO")
                        .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                }
                
                HStack {
                    Text("Status:")
                    Spacer()
                    Text("\(notificationManager.authorizationStatus.rawValue)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("📱 Request Permission") {
                    notificationManager.requestNotificationPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("⏰ Test (5s)") {
                    notificationManager.scheduleTestNotification()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("📊 Debug Status") {
                    notificationManager.debugNotificationStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 12) {
                Button("🔄 Schedule Next") {
                    notificationManager.handleAppLaunch()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("🗑️ Remove All") {
                    notificationManager.cancelAllPortfolioNotifications()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                
                Button("🧹 Cleanup Old") {
                    notificationManager.cleanupOldNotifications()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    #endif
    
    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
