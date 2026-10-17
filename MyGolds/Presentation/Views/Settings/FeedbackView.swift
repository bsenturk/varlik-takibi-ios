//
//  FeedbackView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//
//  Görünüm / Para Birimi ekranlarıyla aynı kalıp: tam ekran, sağ üstte kapatma,
//  gruplu kartlar. Kategori eskiden bir Menu'nün arkasındaydı; dört seçenek için
//  tek dokunuşla seçilen çipler daha az sürtünme. Gönder butonu başparmak
//  bölgesinde, klavyenin hemen üstünde durur.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var feedbackText = ""
    @State private var selectedCategory = Category.general
    @State private var showingMailFallback = false
    @FocusState private var isEditorFocused: Bool

    private let accent = Color(hex: "#0A84FF")
    private let email = "buraksenturktr@icloud.com"

    enum Category: String, CaseIterable, Identifiable {
        case general = "Genel"
        case bug = "Hata Bildirimi"
        case feature = "Özellik İsteği"
        case other = "Diğer"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "bubble.left.fill"
            case .bug:     return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .other:   return "ellipsis.circle.fill"
            }
        }

        var placeholder: String {
            switch self {
            case .general: return "Aklınızdakini yazın..."
            case .bug:     return "Ne oldu? Hangi ekranda, hangi adımlarla?"
            case .feature: return "Hangi özelliği görmek istersiniz?"
            case .other:   return "Mesajınızı buraya yazın..."
            }
        }
    }

    private var trimmedText: String {
        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture { isEditorFocused = false }

            VStack(spacing: 0) {
                SelectionScreenHeader(
                    title: "Bize Ulaşın",
                    subtitle: "Her mesajı okuyoruz, genellikle birkaç gün içinde dönüyoruz",
                    onClose: { dismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        categorySection
                        messageSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) { sendBar }
        .alert("Mail uygulaması bulunamadı", isPresented: $showingMailFallback) {
            Button("Adresi Kopyala") { UIPasteboard.general.string = email }
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Mesajınızı \(email) adresine gönderebilirsiniz.")
        }
    }

    // MARK: - Sections

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Konu")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Category.allCases) { chip($0) }
            }
        }
    }

    private func chip(_ category: Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            guard !isSelected else { return }
            withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = category }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? accent : .secondary)
                Text(category.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? accent : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Mesajınız")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $feedbackText)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 200)

                if feedbackText.isEmpty {
                    Text(selectedCategory.placeholder)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isEditorFocused ? accent.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.15), value: isEditorFocused)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Uygulama sürümü ve cihaz bilgisi mesaja eklenir.")
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
        }
    }

    private var sendBar: some View {
        Button(action: sendFeedback) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Mail ile Gönder")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(trimmedText.isEmpty ? .secondary : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(trimmedText.isEmpty ? Color(.tertiarySystemFill) : accent)
            )
        }
        .disabled(trimmedText.isEmpty)
        .animation(.easeInOut(duration: 0.15), value: trimmedText.isEmpty)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased(with: Locale(identifier: "tr_TR")))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
    }

    // MARK: - Send

    private func sendFeedback() {
        let device = UIDevice.current
        let body = """
        \(trimmedText)

        —
        \(AppVersionHelper.fullVersionString) · \(device.model) · iOS \(device.systemVersion)
        """

        // URLComponents her parçayı ayrı kodlar; eski düz string yöntemi
        // metindeki "&" karakterinde gövdeyi kesiyordu.
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Varlık Takibi - \(selectedCategory.rawValue)"),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { showingMailFallback = true; return }
        openURL(url) { accepted in
            // Mail açılamazsa sayfayı kapatmıyoruz ki yazılan mesaj kaybolmasın.
            if accepted { dismiss() } else { showingMailFallback = true }
        }
    }
}

#Preview {
    FeedbackView()
}
