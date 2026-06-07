//
//  RateAppView.swift - v3.0.0 redesign (compact bottom sheet)
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI

struct RateAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating = 0

    private let brandGradient = LinearGradient(
        colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            // Close
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            VStack(spacing: 0) {
                // Icon
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(brandGradient)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Image(systemName: "star.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 16, x: 0, y: 8)
                    .padding(.top, 20)

                Text("Uygulamayı Değerlendirin")
                    .font(.system(size: 23, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)

                Text("Deneyiminiz nasıldı? Görüşleriniz bizim için çok değerli.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 8)

                // Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                selectedRating = star
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundColor(star <= selectedRating ? Color(hex: "#FFB300") : Color.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22)

                // Submit
                Button(action: submit) {
                    Text("Gönder")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            selectedRating > 0
                                ? AnyShapeStyle(brandGradient)
                                : AnyShapeStyle(Color(.systemGray3))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedRating == 0)
                .padding(.horizontal, 24)
                .padding(.top, 26)

                Button(action: { dismiss() }) {
                    Text("Daha sonra")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
    }

    private func submit() {
        if selectedRating >= 4,
           let url = URL(string: "https://apps.apple.com/app/id6479618311?action=write-review") {
            UIApplication.shared.open(url)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
