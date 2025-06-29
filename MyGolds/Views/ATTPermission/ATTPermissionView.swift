//
//  ATTPermissionView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import AppTrackingTransparency

struct ATTPermissionView: View {
    let onPermissionGranted: (Bool) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "shield.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
            
            // Content
            VStack(spacing: 16) {
                Text("Gizlilik İzni")
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text("Size daha iyi hizmet verebilmek için uygulamanın performansını analiz etmemize izin verin. Verileriniz güvende kalacak.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 80)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: { requestATTPermission() }) {
                    Text("İzin Ver")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.blue)
                        .cornerRadius(16)
                }
                
                Button(action: { onPermissionGranted(false) }) {
                    Text("İzin Verme")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    private func requestATTPermission() {
        ATTrackingManager.requestTrackingAuthorization { status in
            DispatchQueue.main.async {
                let granted = status == .authorized
                onPermissionGranted(granted)
            }
        }
    }
}
