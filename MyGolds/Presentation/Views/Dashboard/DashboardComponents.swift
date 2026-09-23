//
//  DashboardComponents.swift
//  MyGolds
//
//  Reusable building blocks for the redesigned Portföy dashboard (v3.0.0).
//

import SwiftUI
import UIKit

// MARK: - Row item view models

/// One row in the dashboard list — either a single asset or an aggregated category.
struct DashboardRowItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let value: Double
    let changePercent: Double
    let sparkline: [Double]
    let icon: String
    let tintHex: String
    /// Enstrümanın kendi logosu. Yalnızca tek varlık satırlarında dolu;
    /// kategori satırları (Genel görünümü) tek bir enstrümana ait değil.
    var logoURL: URL? = nil
    /// Present only for single-asset rows (used for tap-to-detail / delete).
    let assetID: UUID?
    /// Pro bitince erişimi kapanan satır: tutarı gizlenir, dokunulunca paywall açılır.
    var isLocked: Bool = false
    /// Nerede tutulduğu. Alt başlığa eklenmiyor: sol sütun dar, "10 gram · Ba…"
    /// diye kırpılıyordu — varsa ayrı küçük bir satır.
    var location: String? = nil
}

// MARK: - Icon tile

/// SF Symbol adı ya da emoji basar — dövizler ikon yerine bayrak emojisi kullanıyor.
struct AssetGlyph: View {
    let icon: String
    let color: Color
    let size: CGFloat

    var body: some View {
        if UIImage(systemName: icon) != nil {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
        } else {
            Text(icon).font(.system(size: size * 1.2))
        }
    }
}

struct AssetIconTile: View {
    let icon: String
    let tintHex: String
    var size: CGFloat = 44
    /// Enstrümanın kendi logosu. nil ise — ya da indirilemezse — kategori
    /// ikonuna düşülür: her kripto satırında aynı ₿ durmasın diye eklendi.
    var logoURL: URL? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Kategori ikonu, ait olduğu kategorinin renk tonunda oturur. Logolar ise
    /// kendi renklerini taşıyor: turuncu kripto zemini Cardano'nun mavisiyle ya
    /// da Polkadot'un siyahıyla çakışıyordu. Logo varken nötr zemin.
    private var background: AnyShapeStyle {
        logoURL == nil
            ? AnyShapeStyle(Color(hex: tintHex).opacity(0.16))
            : AnyShapeStyle(Color(.secondarySystemFill))
    }

    @ViewBuilder
    private var content: some View {
        if let logoURL {
            AsyncImage(url: logoURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(size * 0.18)
                } else {
                    // Yükleniyor ya da başarısız. Boş kutu göstermek satırı bir
                    // an kimliksiz bırakıyor; kategori ikonu her hâlükârda doğru.
                    glyph
                }
            }
        } else {
            glyph
        }
    }

    private var glyph: some View {
        AssetGlyph(icon: icon, color: Color(hex: tintHex), size: size * 0.42)
    }
}

// MARK: - Asset / category row

struct DashboardRowView: View {
    let item: DashboardRowItem
    /// Bulunduğu portföyün gözü kapalıysa tutarlar maskelenir.
    var valuesMasked: Bool = false
    @AppStorage("selectedCurrency") private var selectedCurrency: Currency = .TRY

    private var isPositive: Bool { item.changePercent >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            AssetIconTile(icon: item.icon, tintHex: item.tintHex, logoURL: item.logoURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let location = item.location {
                    Label(location, systemImage: "mappin")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if !item.isLocked {
                SparklineView(
                    values: item.sparkline,
                    lineColor: isPositive ? .green : .red
                )
                .frame(width: 56, height: 32)
            }

            if item.isLocked {
                // Tutar hiç yazılmaz: kilit "gösterme" değil "erişim" kısıtı.
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Pro")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(ProStyle.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(ProStyle.tint))
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(PortfolioManager.shared
                        .convertToTargetCurrency(item.value, targetCurrency: selectedCurrency)
                        .formatAsCurrency(currency: selectedCurrency)
                        .maskedIfNeeded(valuesMasked))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        // "₺5.000.00…" gibi kırpılmasın; ev/arsa tutarları uzun.
                        .minimumScaleFactor(0.7)
                    Text(changeText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isPositive ? .green : .red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var changeText: String {
        let sign = isPositive ? "+" : "-"
        return "\(sign)%\(String(format: "%.2f", abs(item.changePercent)).replacingOccurrences(of: ".", with: ","))"
    }
}

// MARK: - Balance card

struct BalanceCardView: View {
    let portfolioColor: PortfolioColor
    let metrics: PortfolioMetrics
    /// Göz ikonunun hangi portföyü gizleyeceği. nil ise ikon gösterilmez (onboarding mock'ları).
    var portfolioID: UUID? = nil
    /// Portföyün değer hedefi (TRY). 0 → çubuk yerine "Hedef belirle" kısayolu.
    var targetValue: Double = 0
    /// Hedef düzenleyiciyi açar. nil ise hedef salt okunur: "Genel"de hedef
    /// alt portföylerden türetilir, onboarding mock'larında hiç yoktur.
    var onSetTarget: (() -> Void)? = nil
    @Binding var selectedCurrency: Currency
    @StateObject private var portfolioManager = PortfolioManager.shared
    @AppStorage(UserDefaultsManager.maskedPortfoliosKey) private var maskedPortfolios = ""
    @State private var showingCurrencyPicker = false

    private var valuesMasked: Bool {
        UserDefaultsManager.isPortfolioMasked(maskedPortfolios, portfolioID)
    }

    private var convertedTotal: Double {
        portfolioManager.convertToTargetCurrency(metrics.totalValue, targetCurrency: selectedCurrency)
    }

    private var convertedChange: Double {
        portfolioManager.convertToTargetCurrency(metrics.profitLoss, targetCurrency: selectedCurrency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Toplam Bakiye")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if let portfolioID { maskToggle(portfolioID) }
                currencyMenu
            }

            Text(convertedTotal.formatAsCurrency(currency: selectedCurrency).maskedIfNeeded(valuesMasked))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if metrics.hasProfitLoss {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: metrics.isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text("%\(String(format: "%.2f", abs(metrics.profitLossPercent)).replacingOccurrences(of: ".", with: ","))")
                            .font(.system(size: 13, weight: .bold))
                        Text("·")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(metrics.isPositive ? "+" : "-")\(convertedChange.magnitude.formatAsCurrency(currency: selectedCurrency).maskedIfNeeded(valuesMasked))")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                    Text("Kâr / Zarar")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Düzenlenebiliyorsa her zaman (boşken "Hedef belirle" kısayolu),
            // salt okunur hâlde yalnızca gerçekten bir hedef varsa.
            if onSetTarget != nil || targetValue > 0 { targetSection }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: portfolioColor.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .offset(x: 60, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: portfolioColor.color.opacity(0.35), radius: 18, x: 0, y: 10)
        .fullScreenCover(isPresented: $showingCurrencyPicker) { CurrencySelectionView() }
    }

    // MARK: - Hedef

    private var targetProgress: Double {
        guard targetValue > 0 else { return 0 }
        return max(0, metrics.totalValue / targetValue)
    }

    @ViewBuilder
    private var targetSection: some View {
        if targetValue > 0 {
            VStack(spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: targetProgress >= 1 ? "checkmark.seal.fill" : "target")
                        .font(.system(size: 11, weight: .bold))
                    // "Genel"de etiket her hâlükârda "Toplam hedef" kalıyor:
                    // oranın türetilmiş bir toplamdan geldiği kaybolmasın.
                    Text(onSetTarget == nil
                         ? "Toplam hedef"
                         : (targetProgress >= 1 ? "Hedefe ulaşıldı" : "Hedef"))
                        .font(.system(size: 13))
                    Spacer(minLength: 4)
                    Text("%\(Self.percentText(targetProgress))")
                        .font(.system(size: 13, weight: .heavy))
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    Text(portfolioManager
                            .convertToTargetCurrency(targetValue, targetCurrency: selectedCurrency)
                            .formatAsCurrency(currency: selectedCurrency)
                            .maskedIfNeeded(valuesMasked))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(.white.opacity(0.9))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.22))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(1, targetProgress)) * geo.size.width)
                    }
                }
                .frame(height: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSetTarget?() }
            .allowsHitTesting(onSetTarget != nil)
        } else {
            Button { onSetTarget?() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .bold))
                    Text("Hedef belirle")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
            }
        }
    }

    /// %0,4 gibi küçük oranlar 0 görünmesin diye iki basamağa kadar iniyor.
    private static func percentText(_ ratio: Double) -> String {
        let pct = ratio * 100
        let decimals = pct >= 10 ? 0 : (pct >= 1 ? 1 : 2)
        return String(format: "%.\(decimals)f", pct).replacingOccurrences(of: ".", with: ",")
    }

    /// Göz ikonu: yalnızca bu portföyün tutarlarını gizler/gösterir (tercih kalıcı).
    private func maskToggle(_ portfolioID: UUID) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                maskedPortfolios = UserDefaultsManager.togglingPortfolioMask(maskedPortfolios, portfolioID)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: valuesMasked ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.18))
                .clipShape(Circle())
        }
        .accessibilityLabel(valuesMasked ? "Tutarları göster" : "Tutarları gizle")
    }

    /// Para birimi seçimi artık ayrı bir ekranda: on beş döviz açılır menüye
    /// sığmıyordu ve menüde kur bilgisi gösterilemiyordu.
    private var currencyMenu: some View {
        Button {
            showingCurrencyPicker = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 4) {
                Text(selectedCurrency.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.18))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Portfolio chip

struct PortfolioChip: View {
    let portfolio: Portfolio
    let isSelected: Bool
    /// Shows the colored dot + pencil affordance once the user has interacted (manage mode).
    let showsEditAffordance: Bool
    /// Whether tapping the selected chip edits it (shows a pencil). Off on the Analiz page.
    var showsEditPencil: Bool = true
    /// Pro bitince ücretsiz sınırın dışında kalan portföy: seçilemez, dokununca paywall.
    var isLocked: Bool = false
    let onTap: () -> Void

    var body: some View {
        // A tap gesture (rather than Button) is used because Buttons inside a horizontal
        // ScrollView nested in a vertical ScrollView don't reliably receive taps.
        HStack(spacing: 6) {
            // Unselected, non-Genel chips show their portfolio color as a leading dot.
            if !isSelected && !portfolio.isGeneral {
                Circle()
                    .fill(portfolio.color.color)
                    .frame(width: 8, height: 8)
            }
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(portfolio.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            if isSelected && !portfolio.isGeneral && showsEditPencil {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundColor(isSelected ? .white : (isLocked ? .secondary : .primary))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(chipBackground)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSelected {
            LinearGradient(
                colors: portfolio.color.gradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Color(.systemGray5)
        }
    }
}

// MARK: - Tutulduğu yer

/// "Nerede tutuluyor?" — serbest metin + kategoriye göre öneri çipleri.
/// Çipe dokunmak alanı doldurur, seçili çipe tekrar dokunmak temizler.
/// Varlık ekleme ve düzenleme ekranları ortak kullanıyor.
struct LocationPicker: View {
    @Binding var location: String
    let suggestions: [String]

    /// Karşılaştırma ve kayıt aynı temizlenmiş biçimi kullanıyor.
    static func normalized(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Nerede tutuluyor?")
                    .font(.system(size: 15, weight: .medium))
                Text("(Opsiyonel)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Örn. \(suggestions.prefix(2).joined(separator: ", "))", text: $location)
                    .font(.system(size: 16))
                    .submitLabel(.done)
                    .onChange(of: location) { _, new in
                        if new.count > 30 { location = String(new.prefix(30)) }
                    }
                if !location.isEmpty {
                    Button { location = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { chip($0) }
                }
            }
        }
    }

    private func chip(_ title: String) -> some View {
        let selected = Self.normalized(location) == title
        return Button {
            location = selected ? "" : title
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Elle girilen varlığın ismi

/// Ev/araba gibi elle girilen varlıklara isim ("Kadıköy daire"): iki ev
/// listede ikisi de "Ev" diye görünmesin. Boş bırakılırsa tür adı kullanılır.
struct ManualNameField: View {
    @Binding var name: String
    /// Tür adı ("Ev", "Araba") — örnek metni buna göre kuruluyor.
    let typeName: String

    static let maxLength = 40

    private var example: String {
        typeName == "Araba" ? "Aile arabası"
            : "Kadıköy'deki \(typeName.lowercased(with: Locale(identifier: "tr_TR")))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("İsim")
                    .font(.system(size: 15, weight: .medium))
                Text("(Opsiyonel)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            TextField("Örn. \(example)", text: $name)
                .font(.system(size: 16))
                // Yer/özel isimleri ("Kadıköy") otomatik düzeltme bozuyor.
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onChange(of: name) { _, new in
                    if new.count > Self.maxLength { name = String(new.prefix(Self.maxLength)) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
