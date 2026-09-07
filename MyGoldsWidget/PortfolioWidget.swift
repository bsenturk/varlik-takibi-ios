//
//  PortfolioWidget.swift
//  MyGoldsWidget
//
//  Uygulamadaki bakiye kartının ana ekran hâli.
//
//  Veri akışı: uygulama App Group'a varlık listesini yazar (WidgetSharedStore),
//  widget fiyatları kendisi çeker ve toplamı kendisi hesaplar. Böylece kullanıcı
//  uygulamayı hiç açmasa da widget tazeleniyor.
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct PortfolioEntry: TimelineEntry {
    enum State {
        /// Pro değil. Kart varsa kullanıcının *kendi* portföyü tutarları maskeli
        /// çizilir — neyi kaçırdığını görmek jenerik bir kilitten güçlü.
        /// nil yalnızca hiç veri yazılmamışsa.
        case locked(Card?)
        /// Henüz veri yazılmamış (widget uygulama açılmadan eklendi).
        case needsApp
        case ready(Card)
    }

    struct Card {
        struct Row: Identifiable {
            var id: String { name }
            let name: String
            let value: String
            let percent: Double
            let icon: String
            let tintHex: String
        }

        let name: String
        let colorHex: String
        let isGeneral: Bool
        let masked: Bool
        let total: String
        let profitLoss: String
        let percent: Double
        let isPositive: Bool
        let hasProfitLoss: Bool
        let rows: [Row]
        /// Fiyatlar çekilemedi; uygulamanın yazdığı son bilinen fiyat kullanıldı.
        let stale: Bool
        /// Pro değil: aynı düzen çizilir, tutarların yerinde maske ve "Pro ile aç" durur.
        var isLocked = false
    }

    let date: Date
    let state: State
}

// MARK: - Provider

struct PortfolioProvider: TimelineProvider {

    /// WidgetKit'in yenileme bütçesi günde ~40-70 tur; yarım saat güvenli aralık.
    private static let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: Date(), state: .ready(.preview))
    }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        // Galeri önizlemesi gerçek veriyi beklememeli.
        guard !context.isPreview else {
            completion(PortfolioEntry(date: Date(), state: .ready(.preview)))
            return
        }
        Task { completion(await makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let next = Date().addingTimeInterval(Self.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func makeEntry() async -> PortfolioEntry {
        guard let payload = WidgetSharedStore.loadPayload(),
              let portfolio = payload.portfolio(id: nil) else {
            // Veri hiç yazılmamış: Pro'ya "uygulamayı aç" denir, değilse kilit.
            return PortfolioEntry(date: Date(), state: WidgetSharedStore.isPro ? .needsApp : .locked(nil))
        }

        guard WidgetSharedStore.isPro else {
            // Boş portföyde maskeli tutar yanıltıcı: "gizlenmiş bir rakam var"
            // der ama yoktur. Gizlenecek bir şey olmadığında jenerik kilit doğru.
            guard !portfolio.holdings.isEmpty else {
                return PortfolioEntry(date: Date(), state: .locked(nil))
            }
            // Kilitliyken fiyat çekilmiyor: tutarlar zaten maskeli, widget'ın kıt
            // yenileme bütçesi boşa harcanmasın.
            let card = makeCard(portfolio, currency: payload.currencyCode, quotes: .empty, forceMasked: true)
            return PortfolioEntry(date: Date(), state: .locked(card))
        }

        let symbols = Set(portfolio.holdings.map(\.symbol)).union([payload.currencyCode])
        let quotes = await WidgetPriceFetcher.fetch(symbols: symbols)

        return PortfolioEntry(
            date: Date(),
            state: .ready(makeCard(portfolio, currency: payload.currencyCode, quotes: quotes))
        )
    }

    /// `forceMasked`: kilitli kart — tutarlar gizlenir, "fiyat çekilemedi"
    /// uyarısı gösterilmez (fiyat zaten kasten çekilmedi).
    private func makeCard(
        _ portfolio: WidgetPortfolio,
        currency: String,
        quotes: WidgetPriceFetcher.Quotes,
        forceMasked: Bool = false
    ) -> PortfolioEntry.Card {
        var totalTRY = 0.0
        var costTRY = 0.0
        var valued: [(holding: WidgetPortfolio.Holding, value: Double, percent: Double)] = []

        for holding in portfolio.holdings {
            // Fiyat çekilemediyse uygulamanın en son yazdığı fiyata düş.
            let price = quotes.tryPrice(holding.symbol) ?? holding.lastPrice
            let value = max(0, holding.amount * price)
            // Maliyeti bilinmeyen varlık kâr/zarara 0 katkı versin diye güncel fiyata düşer.
            let cost = holding.costPerUnit > 0 ? holding.costPerUnit : price
            totalTRY += value
            costTRY += cost * holding.amount
            let percent = cost > 0 ? ((price - cost) / cost) * 100.0 : 0
            valued.append((holding, value, percent))
        }

        let profitTRY = totalTRY - costTRY
        let percent = costTRY > 0 ? (profitTRY / costTRY) * 100.0 : 0
        let masked = portfolio.masked || forceMasked

        let rows = valued
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { item in
                PortfolioEntry.Card.Row(
                    name: item.holding.name,
                    value: quotes.convert(item.value, to: currency).widgetCurrency(currency).masked(masked),
                    percent: item.percent,
                    icon: item.holding.icon,
                    tintHex: item.holding.tintHex
                )
            }

        return PortfolioEntry.Card(
            name: portfolio.name,
            colorHex: portfolio.colorHex,
            isGeneral: portfolio.isGeneral,
            masked: masked,
            total: quotes.convert(totalTRY, to: currency).widgetCurrency(currency).masked(masked),
            profitLoss: (profitTRY < 0 ? "-" : "+")
                + quotes.convert(abs(profitTRY), to: currency).widgetCurrency(currency).masked(masked),
            percent: percent,
            isPositive: profitTRY >= 0,
            hasProfitLoss: abs(profitTRY) > 0.01,
            rows: Array(rows),
            stale: !forceMasked && quotes.isEmpty && !portfolio.holdings.isEmpty,
            isLocked: forceMasked
        )
    }
}

// MARK: - Widget

struct PortfolioWidget: Widget {
    static let kind = "PortfolioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PortfolioProvider()) { entry in
            PortfolioWidgetView(entry: entry)
        }
        .configurationDisplayName("Portföy Bakiyesi")
        .description("Seçili portföyünün toplam değerini ve kâr/zararını ana ekranında gör. Varlık Pro gerektirir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MyGoldsWidgetBundle: WidgetBundle {
    var body: some Widget {
        PortfolioWidget()
    }
}
