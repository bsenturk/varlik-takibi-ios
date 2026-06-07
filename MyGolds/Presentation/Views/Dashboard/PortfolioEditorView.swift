//
//  PortfolioEditorView.swift
//  MyGolds
//
//  Centered card popup for creating / editing / deleting a portfolio.
//

import SwiftUI

struct PortfolioEditorView: View {
    /// `nil` → create mode, otherwise edit mode.
    let portfolio: Portfolio?

    let onSave: (String, PortfolioColor) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var name: String
    @State private var color: PortfolioColor
    @State private var appeared = false

    init(
        portfolio: Portfolio?,
        onSave: @escaping (String, PortfolioColor) -> Void,
        onDelete: (() -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.portfolio = portfolio
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _name = State(initialValue: portfolio?.name ?? "")
        _color = State(initialValue: portfolio?.color ?? .blue)
    }

    private var isEdit: Bool { portfolio != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            card
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(isEdit ? "Portföyü Düzenle" : "Yeni Portföy")
                    .font(.system(size: 19, weight: .bold))
                Text(isEdit ? "Adını ve rengini güncelleyin" : "Bir ad ve renk seçin")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            TextField("Portföy adı", text: $name)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(spacing: 14) {
                ForEach(PortfolioColor.allCases) { option in
                    Circle()
                        .fill(option.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.9), lineWidth: color == option ? 3 : 0)
                                .padding(-3)
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) { color = option }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
            }

            HStack(spacing: 12) {
                Button(action: dismiss) {
                    Text("Vazgeç")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button(action: {
                    guard canSave else { return }
                    onSave(name.trimmingCharacters(in: .whitespaces), color)
                }) {
                    Text("Kaydet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(colors: color.gradient, startPoint: .leading, endPoint: .trailing)
                                .opacity(canSave ? 1 : 0.4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSave)
            }

            if isEdit, let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Text("Portföyü Sil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 32)
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onCancel() }
    }
}
