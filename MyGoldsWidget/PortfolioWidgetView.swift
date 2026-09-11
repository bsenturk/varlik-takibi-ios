//
//  PortfolioWidgetView.swift
//  MyGoldsWidget
//
//  Uygulamadaki `BalanceCardView`in widget karşılığı — aynı degrade, aynı
//  hiyerarşi. Pro değilse aynı çerçevede kilit ekranı çizilir.
//

import WidgetKit
import SwiftUI

struct PortfolioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PortfolioEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        // Kilitli kart doğrudan paywall'ı açar; uygulamayı açıp kullanıcıyı
        // "nereye basacaktım" diye aramaya bırakmıyor.
        case .locked(let card):
            Group {
                // Hazır kartla birebir aynı düzen — tek fark maskeli tutarlar ve
                // kâr/zarar hapının yerindeki "Pro ile aç".
                if let card { cardView(card) } else { LockedView() }
            }
            .widgetURL(URL(string: "mygolds://paywall"))
        case .needsApp:
            MessageView(icon: "arrow.down.app.fill", text: "Portföyünü görmek için uygulamayı bir kez aç.")
        case .ready(let card):
            cardView(card)
        }
    }

    @ViewBuilder
    private func cardView(_ card: PortfolioEntry.Card) -> some View {
        if family == .systemMedium {
            MediumCardView(card: card)
        } else {
            SmallCardView(card: card)
        }
    }

    private var background: some View {
        let colors: [Color] = {
            switch entry.state {
            // Kilitli kart da portföyün kendi degradesini kullanır: kullanıcı
            // tam olarak neyi açacağını görüyor.
            case .ready(let card), .locked(.some(let card)):
                return Color.widgetGradient(hex: card.colorHex)
            // Gösterilecek veri yokken nötr gri — renkli kart gibi görünüp
            // sonra boş çıkmasın.
            case .locked(.none), .needsApp:
                return [Color(white: 0.22), Color(white: 0.13)]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Ready

private struct SmallCardView: View {
    let card: PortfolioEntry.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PortfolioTitle(card: card)
            Spacer(minLength: 0)
            Text(card.total)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            if card.isLocked {
                UnlockPill()
            } else if card.hasProfitLoss {
                ProfitPill(card: card, compact: true)
            }
            Spacer(minLength: 0)
            StaleNote(card: card)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumCardView: View {
    let card: PortfolioEntry.Card

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                PortfolioTitle(card: card)
                Spacer(minLength: 0)
                Text(card.total)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if card.isLocked {
                    UnlockPill()
                } else if card.hasProfitLoss {
                    ProfitPill(card: card, compact: false)
                }
                Spacer(minLength: 0)
                StaleNote(card: card)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !card.rows.isEmpty {
                VStack(spacing: 6) {
                    ForEach(card.rows) { row in
                        HoldingRow(row: row, masked: card.masked)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: 140)
            }
        }
    }
}

private struct PortfolioTitle: View {
    let card: PortfolioEntry.Card

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: card.isGeneral ? "square.stack.3d.up.fill" : "creditcard.fill")
                .font(.system(size: 10, weight: .bold))
            Text(card.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

private struct ProfitPill: View {
    let card: PortfolioEntry.Card
    let compact: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: card.isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
            Text("%\(card.percent.widgetPercent)")
                .font(.system(size: compact ? 11 : 12, weight: .bold))
            if !compact {
                Text("·").font(.system(size: 12, weight: .bold))
                Text(card.profitLoss).font(.system(size: 12, weight: .bold))
            }
        }
        // Tek satırda kalsın: sarınca hap iki satıra bölünüp kartı bozuyordu.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.18), in: Capsule())
    }
}

private struct HoldingRow: View {
    let row: PortfolioEntry.Card.Row
    let masked: Bool

    var body: some View {
        HStack(spacing: 7) {
            WidgetGlyph(icon: row.icon, tintHex: row.tintHex)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(row.value)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !masked {
                Text("%\(row.percent.widgetPercent)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(row.percent >= 0 ? 0.95 : 0.7))
            }
        }
    }
}

/// SF Symbol adı ya da emoji basar — dövizler bayrak emojisi kullanıyor
/// (uygulamadaki `AssetGlyph` ile aynı kural).
private struct WidgetGlyph: View {
    let icon: String
    let tintHex: String

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(.white.opacity(0.16))
            .frame(width: 24, height: 24)
            .overlay {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(icon).font(.system(size: 13))
                }
            }
    }
}

/// Fiyat çekilemediğinde tutarın bayat olduğunu söyler — sessizce eski değeri
/// göstermek kullanıcıyı yanıltır.
private struct StaleNote: View {
    let card: PortfolioEntry.Card

    var body: some View {
        if card.stale {
            Text("Fiyatlar güncellenemedi")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}

// MARK: - Kilitli / boş

/// Kilitli kartta kâr/zarar hapının yerini alır.
private struct UnlockPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
            Text("Pro ile aç")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.22), in: Capsule())
    }
}

private struct LockedView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text("Varlık Pro")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
            Text("Portföy widget'ı Pro üyelere açık. Açmak için dokun.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MessageView: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Biçimlendirme yardımcıları

extension Double {
    /// `Double.formatAsCurrency(currency:)` ile aynı çıktı — uygulama tarafındaki
    /// dosya app target'ına ait olduğu için burada küçük bir kopyası duruyor.
    func widgetCurrency(_ code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        switch code {
        case "USD": formatter.currencySymbol = "$"; formatter.locale = Locale(identifier: "en_US")
        case "EUR": formatter.currencySymbol = "€"; formatter.locale = Locale(identifier: "en_US")
        case "GBP": formatter.currencySymbol = "£"; formatter.locale = Locale(identifier: "en_GB")
        default:    formatter.currencySymbol = "₺"; formatter.locale = Locale(identifier: "tr_TR")
        }
        return formatter.string(from: NSNumber(value: self)) ?? "0,00"
    }

    var widgetPercent: String {
        String(format: "%.2f", abs(self)).replacingOccurrences(of: ".", with: ",")
    }
}

extension String {
    func masked(_ isMasked: Bool) -> String { isMasked ? "••••••" : self }
}

extension Color {
    init(widgetHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        guard cleaned.count == 6 else { self = .blue; return }
        self.init(
            .sRGB,
            red: Double(int >> 16 & 0xFF) / 255,
            green: Double(int >> 8 & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }

    /// `PortfolioColor.gradient` ile aynı çiftler — widget kart, uygulamadaki
    /// bakiye kartıyla birebir aynı görünsün diye.
    static func widgetGradient(hex: String) -> [Color] {
        let pairs: [String: (String, String)] = [
            "#007AFF": ("#0A84FF", "#5E5CE6"),
            "#AF52DE": ("#AF52DE", "#BF5AF2"),
            "#FF2D55": ("#FF2D55", "#FF375F"),
            "#34C759": ("#34C759", "#30D158"),
            "#FF9500": ("#FF9F0A", "#FF9500"),
            "#FF3B30": ("#FF3B30", "#FF453A")
        ]
        guard let pair = pairs[hex.uppercased()] else {
            let base = Color(widgetHex: hex)
            return [base, base.opacity(0.75)]
        }
        return [Color(widgetHex: pair.0), Color(widgetHex: pair.1)]
    }
}

// MARK: - Önizleme verisi

extension PortfolioEntry.Card {
    static let preview = PortfolioEntry.Card(
        name: "Portföyüm",
        colorHex: "#AF52DE",
        isGeneral: false,
        masked: false,
        total: "₺124.500,00",
        profitLoss: "+₺8.240,00",
        percent: 7.09,
        isPositive: true,
        hasProfitLoss: true,
        rows: [
            .init(name: "Gram Altın", value: "₺62.400,00", percent: 4.2, icon: "circle.hexagongrid.fill", tintHex: "#FFB300"),
            .init(name: "Dolar", value: "₺38.100,00", percent: 1.1, icon: "🇺🇸", tintHex: "#2A9D8F"),
            .init(name: "Bitcoin", value: "₺24.000,00", percent: -2.4, icon: "bitcoinsign.circle.fill", tintHex: "#F7931A")
        ],
        stale: false
    )
}
