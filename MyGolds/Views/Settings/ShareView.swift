//
//  ShareView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct ShareView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Uygulamayı Paylaş")
                    .font(.title2.bold())
                
                Text("Arkadaşlarınızla Varlık Takibi uygulamasını'ı paylaşın ve onların da varlıklarını takip etmelerini sağlayın.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // App Info
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "app.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Varlık Takibi")
                            .font(.headline)
                        Text("Altın ve döviz takip uygulaması")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Share Button
            Button(action: shareApp) {
                Text("Paylaş")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.green)
                    .cornerRadius(12)
            }
            
            Spacer()
            
            Button("Kapat") { dismiss() }
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private func shareApp() {
        //dismiss()
        
        let text = "Varlık Takibi uygulamasını keşfedin! Altın ve döviz varlıklarınızı kolayca takip edin. https://apps.apple.com/us/app/varlık-defterim/id6479618311"
        
        let activityController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}
