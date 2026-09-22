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

    let onSave: (String, PortfolioColor, Double) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var name: String
    @State private var color: PortfolioColor
    @State private var targetText: String
    @State private var appeared = false

    init(
        portfolio: Portfolio?,
        onSave: @escaping (String, PortfolioColor, Double) -> Void,
        onDelete: (() -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.portfolio = portfolio
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _name = State(initialValue: portfolio?.name ?? "")
        _color = State(initialValue: portfolio?.color ?? .blue)
        let target = portfolio?.targetValue ?? 0
        _targetText = State(initialValue: target > 0 ? String(Int(target)) : "")
    }

    private var isEdit: Bool { portfolio != nil }
    /// "Genel" silinemez ve adı/rengi sabit — orada yalnızca hedef düzenlenir.
    private var isGeneral: Bool { portfolio?.isGeneral ?? false }
    /// Boş bırakmak hedefi kaldırır, o yüzden 0 geçerli bir değer.
    private var parsedTarget: Double { Double(targetText) ?? 0 }
    private var canSave: Bool { isGeneral || !name.trimmingCharacters(in: .whitespaces).isEmpty }

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
                Text(isGeneral ? "Hedef Belirle" : (isEdit ? "Portföyü Düzenle" : "Yeni Portföy"))
                    .font(.system(size: 19, weight: .bold))
                Text(isGeneral ? "Tüm varlıklarının toplamı için bir hedef koy"
                               : (isEdit ? "Adını, rengini ve hedefini güncelleyin" : "Bir ad, renk ve hedef seçin"))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !isGeneral {
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
            }

            targetField

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
                    onSave(name.trimmingCharacters(in: .whitespaces), color, parsedTarget)
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

            if isEdit, !isGeneral, let onDelete {
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

    /// Hedef tutarı (₺). Boş = hedef yok.
    ///
    /// ponytail: alanın içinde binlik ayracı YOK. Formatlanmış metni `onChange`
    /// içinden binding'e geri yazmak, hızlı yazarken/yapıştırırken henüz
    /// işlenmemiş tuş vuruşlarını eziyordu ("5000000" → "50.000"). Ham rakam
    /// girilir, okunabilirliği alanın altındaki önizleme sağlar.
    private var targetField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hedef (opsiyonel)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 6) {
                Text("₺")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("0", text: $targetText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .bold))
                    .onChange(of: targetText) { _, new in
                        // Yalnızca eleme: uzunluk değişmediğinde binding'e
                        // dokunulmaz, yarış da böyle önlenir.
                        let digits = String(new.filter(\.isNumber).prefix(15))
                        if digits != new { targetText = digits }
                    }
                if !targetText.isEmpty {
                    Button {
                        targetText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if parsedTarget > 0 {
                Text(parsedTarget.formatAsCurrency())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onCancel() }
    }
}
