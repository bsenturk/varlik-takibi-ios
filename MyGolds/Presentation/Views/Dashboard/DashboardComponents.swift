//
//  DashboardComponents.swift
//  MyGolds
//
//  Reusable building blocks for the redesigned Portföy dashboard (v3.0.0).
//

import SwiftUI

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
}

// MARK: - Icon tile

struct AssetIconTile: View {
    let icon: String
    let tintHex: String
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: tintHex).opacity(0.16))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundColor(Color(hex: tintHex))
            )
    }
}

// MARK: - Asset / category row

struct DashboardRowView: View {
    let item: DashboardRowItem
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

            SparklineView(
                values: item.sparkline,
                lineColor: isPositive ? .green : .red
            )
            .frame(width: 56, height: 32)

            VStack(alignment: .trailing, spacing: 3) {
                Text(PortfolioManager.shared
                    .convertToTargetCurrency(item.value, targetCurrency: selectedCurrency)
                    .formatAsCurrency(currency: selectedCurrency))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(changeText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isPositive ? .green : .red)
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
    @Binding var selectedCurrency: Currency
    @StateObject private var portfolioManager = PortfolioManager.shared

    private var convertedTotal: Double {
        portfolioManager.convertToTargetCurrency(metrics.totalValue, targetCurrency: selectedCurrency)
    }

    private var convertedChange: Double {
        portfolioManager.convertToTargetCurrency(metrics.dayChangeValue, targetCurrency: selectedCurrency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Toplam Bakiye")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                currencyMenu
            }

            Text(convertedTotal.formatAsCurrency(currency: selectedCurrency))
                .font(.system(size: 34, weight: .heavy))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if metrics.hasDayChange {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: metrics.isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text("%\(String(format: "%.2f", abs(metrics.dayChangePercent)).replacingOccurrences(of: ".", with: ","))")
                            .font(.system(size: 13, weight: .bold))
                        Text("·")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(metrics.isPositive ? "+" : "-")\(convertedChange.magnitude.formatAsCurrency(currency: selectedCurrency))")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                    Text("Bugün")
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

    private var currencyMenu: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { currency in
                Button {
                    withAnimation { selectedCurrency = currency }
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
            Text(portfolio.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            if isSelected && !portfolio.isGeneral && showsEditPencil {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .foregroundColor(isSelected ? .white : .primary)
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
