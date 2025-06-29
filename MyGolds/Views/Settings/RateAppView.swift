//
//  RateAppView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RateAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Uygulamayı Değerlendirin")
                        .font(.title2.bold())
                    
                    Text("Deneyiminiz nasıldı? Görüşleriniz bizim için çok değerli.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                // Star Rating
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { selectedRating = star }) {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(star <= selectedRating ? .yellow : .gray)
                        }
                    }
                }
                .padding()
                
                // Action Button
                if selectedRating > 0 {
                    Button(action: openAppStore) {
                        Text("App Store'da Değerlendir")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
    
    private func openAppStore() {
        if let url = URL(string: "https://apps.apple.com/us/app/varlık-defterim/id6479618311") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}
