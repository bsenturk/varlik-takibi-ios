//
//  DarkModeSettingsView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 1.07.2025.
//

import SwiftUI

struct DarkModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userDefaults = UserDefaultsManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding(.bottom, 8)
                    
                    Text("Görünüm Modu")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Uygulamanın tema rengini seçin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Options
                VStack(spacing: 12) {
                    ForEach(UserDefaultsManager.DarkModePreference.allCases, id: \.self) { preference in
                        darkModeOption(
                            preference: preference,
                            isSelected: userDefaults.darkModePreference == preference
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.headline.weight(.medium))
                            Text("Geri")
                                .font(.headline)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func darkModeOption(preference: UserDefaultsManager.DarkModePreference, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                userDefaults.darkModePreference = preference
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: preference.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(preference.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(descriptionText(for: preference))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: isSelected ? 8 : 2,
                        x: 0,
                        y: isSelected ? 4 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.blue.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func descriptionText(for preference: UserDefaultsManager.DarkModePreference) -> String {
        switch preference {
        case .system:
            return "Sistem ayarlarını takip eder"
        case .light:
            return "Her zaman açık tema kullanır"
        case .dark:
            return "Her zaman koyu tema kullanır"
        }
    }
}
