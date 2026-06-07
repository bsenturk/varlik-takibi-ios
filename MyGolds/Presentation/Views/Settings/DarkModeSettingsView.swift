//
//  DarkModeSettingsView.swift - v3.0.0 redesign
//  MyGolds
//
//  Created by Burak Şentürk on 1.07.2025.
//

import SwiftUI

struct DarkModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userDefaults = UserDefaultsManager.shared

    private let brandGradient = LinearGradient(
        colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 22) {
                    header

                    VStack(spacing: 12) {
                        ForEach(UserDefaultsManager.DarkModePreference.allCases, id: \.self) { preference in
                            darkModeOption(
                                preference: preference,
                                isSelected: userDefaults.darkModePreference == preference
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                            Text("Geri").font(.system(size: 17))
                        }
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(brandGradient)
                .frame(width: 86, height: 86)
                .overlay(
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                )
                .shadow(color: Color(hex: "#AF52DE").opacity(0.35), radius: 16, x: 0, y: 8)

            VStack(spacing: 6) {
                Text("Görünüm Modu")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.primary)
                Text("Uygulamanın tema rengini seçin")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Option card

    @ViewBuilder
    private func darkModeOption(preference: UserDefaultsManager.DarkModePreference, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                userDefaults.darkModePreference = preference
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 14) {
                // Icon tile
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(brandGradient) : AnyShapeStyle(Color(.systemGray5)))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: preference.iconName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(preference.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text(descriptionText(for: preference))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Color(hex: "#0A84FF") : Color.secondary.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color(hex: "#0A84FF") : Color.primary.opacity(0.06),
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func descriptionText(for preference: UserDefaultsManager.DarkModePreference) -> String {
        switch preference {
        case .system: return "Sistem ayarlarını takip eder"
        case .light: return "Her zaman açık tema kullanır"
        case .dark: return "Her zaman koyu tema kullanır"
        }
    }
}
