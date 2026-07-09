//
//  NotificationPermissionView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    let onPermissionGranted: (Bool) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 32)
            
            // Content
            VStack(spacing: 16) {
                Text("Bildirim İzni")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("Varlıklarınızı takip etmenizi hatırlatmak ve güncel kur bilgileri için bildirim gönderebilir miyiz?")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: { onPermissionGranted(false) }) {
                    Text("İzin Verme")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                
                Button(action: requestNotificationPermission) {
                    Text("İzin Ver")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.blue)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                onPermissionGranted(granted)
            }
        }
    }
}
