//
//  FeedbackView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var selectedCategory = "Genel"
    
    private let categories = ["Genel", "Hata Bildirimi", "Özellik İsteği", "Diğer"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Geri Bildirim")
                        .font(.title2.bold())
                    
                    Text("Düşüncelerinizi bizimle paylaşın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Category Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kategori")
                        .font(.headline)
                    
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Feedback Text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mesajınız")
                        .font(.headline)
                    
                    TextEditor(text: $feedbackText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // Send Button
                Button(action: sendFeedback) {
                    Text("Gönder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(feedbackText.isEmpty ? .gray : .blue)
                        .cornerRadius(12)
                }
                .disabled(feedbackText.isEmpty)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
    
    private func sendFeedback() {
        let subject = "Varlık Takibi - \(selectedCategory)"
        let body = feedbackText
        let encoded = "mailto:buraksenturktr@icloud.com?subject=\(subject)&body=\(body)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: encoded) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}
