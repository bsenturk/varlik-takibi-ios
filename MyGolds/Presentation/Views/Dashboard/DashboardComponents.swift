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
    /// Present only for single-asset rows (used for tap-to-detail / delete).
    let assetID: UUID?
    /// Pro bitince erişimi kapanan satır: tutarı gizlenir, dokunulunca paywall açılır.
    var isLocked: Bool = false
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

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: tintHex).opacity(0.16))
            .frame(width: size, height: size)
            .overlay(AssetGlyph(icon: icon, color: Color(hex: tintHex), size: size * 0.42))
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
            AssetIconTile(icon: item.icon, tintHex: item.tintHex)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
    @Binding var selectedCurrency: Currency
    @StateObject private var portfolioManager = PortfolioManager.shared
    @AppStorage(UserDefaultsManager.maskedPortfoliosKey) private var maskedPortfolios = ""

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

    private var currencyMenu: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { currency in
                Button {
                    // Zaten seçili olana tekrar basmak "değişim" değil; eskiden
                    // o da loglanıp currency_changed sayısını şişiriyordu.
                    guard currency != selectedCurrency else { return }
                    let previous = selectedCurrency
                    withAnimation { selectedCurrency = currency }
                    FirebaseAnalyticsHelper.shared.logCurrencyChanged(
                        from: previous.rawValue, to: currency.rawValue
                    )
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(currency.displayName, systemImage: selectedCurrency == currency ? "checkmark" : "")
                }
            }
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
