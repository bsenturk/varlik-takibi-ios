//
//  SettingsView.swift
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
    @State private var shareItem: ShareItem?
    
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
                    
                    // Settings Items
                    VStack(spacing: 12) {
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
                    
                    // App Info
                    VStack(spacing: 8) {
                        Text("Varlık Takibi")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Sürüm 2.0.0")
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
        .sheet(item: $shareItem) { item in
            if let url = item.url {
                ActivityViewController(activityItems: [item.text, url])
            } else {
                ActivityViewController(activityItems: [item.text])
            }
        }
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
            
            Button("🔄 Schedule Next") {
                notificationManager.scheduleNextNotificationOnAppLaunch()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
