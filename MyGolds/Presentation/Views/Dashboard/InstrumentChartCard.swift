//
//  InstrumentChartCard.swift
//  MyGolds
//
//  Varlık ekleme akışının son adımındaki enstrüman detayı: güncel fiyat,
//  günlük değişim ve seçilebilir aralıklı fiyat grafiği.
//
//  Grafik verisi `price-chart` Edge Function'ından geliyor (Yahoo / CoinGecko /
//  TEFAS proxy'si). Altın ve dövizin geçmiş kaynağı olmadığı için bu kart
//  yalnızca dinamik kategorilerde gösteriliyor (`AssetCategory.isDynamic`).
//

import SwiftUI
import Charts

struct InstrumentChartCard: View {
    let symbol: String
    /// Hangi aralıkların gösterileceğini belirler (fonlarda TEFAS sınırı var).
    let category: AssetCategory
    /// Kategori rengi — seçili aralık kapsülünde kullanılıyor.
    let tint: Color
    /// TRY cinsinden güncel birim fiyat (uygulamanın her yerindeki fiyatla aynı).
    let currentPrice: Double
    /// Günlük değişim (%), yoksa rozet gizlenir.
    let dayChangePercent: Double?

    @State private var range: ChartRange = .month
    /// Aralık başına önbellek: kullanıcı 1A ↔ 1Y arasında gidip gelirken
    /// aynı veriyi tekrar çekmeyelim.
    @State private var seriesByRange: [ChartRange: PriceSeries] = [:]
    @State private var isLoading = false
    @State private var failed = false

    private let service = MarketDataService()

    private var series: PriceSeries? { seriesByRange[range] }

    /// TEFAS tek istekte en fazla ~30 gün veriyor ve art arda isteklerde 429
    /// dönüyor; fonlarda uzun aralıkları hiç göstermiyoruz ki kullanıcı boş
    /// grafiğe tıklamasın.
    private var ranges: [ChartRange] {
        category == .fund ? [.week, .month] : ChartRange.allCases
    }

    /// Seçili aralığın yönü — çizgi ve dolgu rengini belirler.
    private var trendColor: Color {
        guard let points = series?.points, let first = points.first?.c, let last = points.last?.c
        else { return tint }
        return last >= first ? Color(hex: "#34C759") : Color(hex: "#FF3B30")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chartArea
            rangePicker
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .task(id: range) { await load() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Güncel Fiyat")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(currentPrice.formatAsCurrency())
                    .font(.system(size: 26, weight: .heavy))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            if let change = dayChangePercent {
                changeBadge(change)
            }
        }
    }

    private func changeBadge(_ change: Double) -> some View {
        let isUp = change >= 0
        let color = Color(hex: isUp ? "#34C759" : "#FF3B30")
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
            Text("%\(String(format: "%.2f", abs(change)).replacingOccurrences(of: ".", with: ","))")
                .font(.system(size: 13, weight: .semibold))
            Text("Bugün")
                .font(.system(size: 12))
                .opacity(0.7)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartArea: some View {
        ZStack {
            if let points = series?.points, points.count > 1 {
                let domain = yDomain(points)
                VStack(alignment: .leading, spacing: 6) {
                    Chart(points) { point in
                        AreaMark(
                            x: .value("Tarih", point.date),
                            yStart: .value("Taban", domain.lowerBound),
                            yEnd: .value("Fiyat", point.c)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [trendColor.opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Tarih", point.date),
                            y: .value("Fiyat", point.c)
                        )
                        .foregroundStyle(trendColor)
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    // Fiyat serileri sıfırdan uzakta seyrettiği için ölçek veriye
                    // göre daraltılıyor; yoksa hareket düz çizgi gibi görünüyor.
                    .chartYScale(domain: domain)
                    .frame(height: 96)

                    if series?.currency == "USD" {
                        Text("Grafik USD fiyatı üzerinden")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else if isLoading {
                ProgressView()
            } else {
                Text(failed ? "Grafik verisi alınamadı." : "Bu varlık için grafik verisi yok.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 96)
        .frame(maxWidth: .infinity)
    }

    private func yDomain(_ points: [PricePoint]) -> ClosedRange<Double> {
        let values = points.map(\.c)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        guard high > low else { return (low * 0.99)...(high * 1.01 + 0.01) }
        let pad = (high - low) * 0.12
        return (low - pad)...(high + pad)
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(ranges) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { range = option }
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(range == option ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(range == option ? AnyShapeStyle(tint) : AnyShapeStyle(Color(.tertiarySystemFill)))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        guard seriesByRange[range] == nil else { return }
        isLoading = true
        failed = false
        defer { isLoading = false }
        do {
            let result = try await service.fetchPriceSeries(symbol: symbol, range: range)
            seriesByRange[range] = result
        } catch {
            failed = true
        }
    }
}
