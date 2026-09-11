//
//  DarkModeSettingsView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 1.07.2025.
//
//  Para Birimi ekranıyla aynı kalıp: tam ekran, sağ üstte kapatma, tek gruplu
//  liste, yalnızca seçilide işaret. Eskiden degrade bir ikon başlığı ve üç ayrı
//  gölgeli kart vardı; üç seçenek için gereksiz ağırlıktı ve uygulamanın geri
//  kalanındaki liste diliyle uyuşmuyordu.
//

import SwiftUI

struct DarkModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userDefaults = UserDefaultsManager.shared

    private let accent = Color(hex: "#0A84FF")

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                SelectionScreenHeader(
                    title: "Görünüm",
                    subtitle: "Uygulamanın teması bu ayara göre değişir",
                    onClose: { dismiss() }
                )

                VStack(spacing: 0) {
                    let options = UserDefaultsManager.DarkModePreference.allCases
                    ForEach(Array(options.enumerated()), id: \.element) { index, preference in
                        row(preference)
                        if index < options.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
        }
    }

    private func row(_ preference: UserDefaultsManager.DarkModePreference) -> some View {
        let isSelected = userDefaults.darkModePreference == preference
        return Button {
            guard !isSelected else { dismiss(); return }
            withAnimation(.easeInOut(duration: 0.2)) {
                userDefaults.darkModePreference = preference
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: preference.iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preference.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description(for: preference))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func description(for preference: UserDefaultsManager.DarkModePreference) -> String {
        switch preference {
        case .system: return "Cihaz ayarını takip eder"
        case .light:  return "Her zaman açık tema"
        case .dark:   return "Her zaman koyu tema"
        }
    }
}
