//
//  FeedbackView.swift - v3.0.0 redesign
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
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 20) {
                    // Subtitle
                    Text("Düşüncelerinizi bizimle paylaşın")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)

                    // Category
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Kategori")
                            .font(.system(size: 16, weight: .bold))

                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button(category) { selectedCategory = category }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory)
                                    .font(.system(size: 17))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(card)
                        }
                    }

                    // Message
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mesajınız")
                            .font(.system(size: 16, weight: .bold))

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $feedbackText)
                                .font(.system(size: 17))
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if feedbackText.isEmpty {
                                Text("Mesajınızı buraya yazın...")
                                    .font(.system(size: 17))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                        .background(card)
                        .frame(maxHeight: .infinity)
                    }

                    // Send
                    Button(action: sendFeedback) {
                        Text("Gönder")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: feedbackText.isEmpty
                                        ? [Color.gray, Color.gray.opacity(0.8)]
                                        : [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(feedbackText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .navigationTitle("Geri Bildirim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
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
