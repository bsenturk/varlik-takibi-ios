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
                        
                        SettingsItemView(
                            icon: "square.and.arrow.up.fill",
                            iconColor: .green,
                            title: "Uygulamayı Paylaş",
                            subtitle: "Arkadaşlarınızla paylaşın",
                            action: { showingShare = true }
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
                        Text("Varlık Defterim")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Sürüm 2.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("© 2024 Varlık Defterim. Tüm hakları saklıdır.")
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
        .sheet(isPresented: $showingShare) {
            ShareView()
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    private func openNotificationSettings() {
        guard let settingsURL = URL(string: UIApplication.openNotificationSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

