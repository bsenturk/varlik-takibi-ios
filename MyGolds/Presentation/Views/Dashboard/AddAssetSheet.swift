//
//  AddAssetSheet.swift
//  MyGolds
//
//  Multi-step "Varlık Ekle" flow: category grid → searchable type list →
//  custom-keypad amount entry + portfolio picker.
//

import SwiftUI
import SwiftData

struct AddAssetSheet: View {
    let targetPortfolio: Portfolio?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager
    @Query(sort: \Portfolio.sortOrder) private var portfolios: [Portfolio]
    @StateObject private var formViewModel = AssetsFormViewModel()
    @ObservedObject private var marketData = MarketDataManager.shared

    /// A selectable instrument — either a legacy gold/FX `AssetType` or a live
    /// catalog row (crypto / stock) identified by `symbol`.
    struct Instrument: Equatable, Hashable {
        let type: AssetType
        let category: AssetCategory
        let symbol: String
        let name: String
        let unit: String
        let iconName: String
        let tintHex: String

        static func legacy(_ t: AssetType) -> Instrument {
            Instrument(type: t, category: t.category, symbol: t.supabaseSymbol,
                       name: t.displayName, unit: t.unit,
                       iconName: t.tileIcon, tintHex: t.tileTintHex)
        }

        static func dynamic(_ row: AssetsPrice, category: AssetCategory) -> Instrument {
            Instrument(type: category.dynamicAssetType ?? .crypto,
                       category: category,
                       symbol: row.code ?? row.name,
                       name: row.name,
                       unit: category == .crypto ? "adet" : "lot",
                       iconName: category.iconName, tintHex: category.tintHex)
        }
    }

    private enum Step: Equatable {
        case category
        case typeList(AssetCategory)
        case amount(Instrument)

        /// Adımın ait olduğu kategori. Arama sorgusunun ömrü buna bağlı.
        var category: AssetCategory? {
            switch self {
            case .category: return nil
            case .typeList(let category): return category
            case .amount(let instrument): return instrument.category
            }
        }
    }

    private enum InputField: Hashable { case amount, purchasePrice }

    @State private var step: Step = .category
    @State private var searchText = ""
    @State private var amount = ""
    @State private var purchasePrice = ""
    /// Nerede tutulduğu. Kategori değişince sıfırlanır (öneriler kategoriye özel).
    @State private var location = ""
    /// Elle girilen varlıklara verilen isim ("Kadıköy daire"). Boşsa tür adı.
    @State private var customName = ""
    @FocusState private var focusedField: InputField?
    @State private var selectedPortfolio: Portfolio?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingPaywall = false

    // MARK: Huni ölçümü
    /// Kaydedildi mi — `dismiss()` hem kayıtta hem vazgeçişte çağrıldığı için
    /// `add_asset_abandoned`'ı ayırmanın tek yolu bu.
    @State private var didSave = false
    /// Ulaşılan **en derin** adım. Kullanıcı geri dönebildiği için anlık `step`
    /// değil bu loglanır; yoksa tutar ekranından geri dönüp kapatan biri
    /// "kategoride bıraktı" görünürdü.
    @State private var furthestStep = "category"
    /// Vazgeçiş olayına bağlam: en son hangi kategoriye girildi.
    @State private var lastCategory: String?

    private var flowSource: String { AddAssetPresenter.shared.source }

    /// Adımlar sıralı; yalnızca ileri gidildiğinde işaretlenir.
    private func markStep(_ name: String) {
        let rank = ["category": 0, "type_list": 1, "amount": 2]
        if (rank[name] ?? 0) > (rank[furthestStep] ?? 0) { furthestStep = name }
    }

    // Debounced TEFAS fund search (funds the user types that aren't cached locally).
    @State private var fundSearchTask: Task<Void, Never>?
    @State private var isSearchingFunds = false

    /// Hedef olarak seçilebilecek portföyler. Kilitli olanlar listelenmez; aksi
    /// hâlde kullanıcı kilidin arkasına yeni varlık yazabilirdi.
    private var realPortfolios: [Portfolio] {
        let lockedIDs = ProLock.lockedPortfolioIDs(portfolios)
        return portfolios.filter { !$0.isGeneral && !lockedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider().opacity(0.4)

            switch step {
            case .category:
                categoryGrid
            case .typeList(let category):
                typeList(for: category)
            case .amount(let instrument):
                amountEntry(for: instrument)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // Arama sorgusu kategoriye aittir. Kullanıcı "ALT" yazıp geri çıkıp
        // Kripto'ya girdiğinde eski sorgu duruyor ve liste boş açılıyordu —
        // arama kutusu ekranın üstünde olduğu için sebebi de görünmüyordu.
        //
        // Her adım değişiminde değil, yalnızca kategori değiştiğinde
        // temizleniyor: miktar adımından geri dönen kullanıcı aynı listeye
        // döndüğü için sorgusunu kaybetmemeli.
        .onChange(of: step) { previous, current in
            guard previous.category != current.category else { return }
            searchText = ""
            location = ""
            customName = ""
        }
        .onAppear {
            selectedPortfolio = targetPortfolio ?? realPortfolios.first
            FirebaseAnalyticsHelper.shared.logAddAssetOpened(source: flowSource)
            // No ad on open — the interstitial is shown after a successful add, when
            // the sheet closes (see AddAssetPresenter.scheduleInterstitialAfterClose).
        }
        .onDisappear {
            guard !didSave else { return }
            FirebaseAnalyticsHelper.shared.logAddAssetAbandoned(
                step: furthestStep, category: lastCategory, source: flowSource
            )
        }
        .alert("Hata", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) {}
        } message: { Text(alertMessage) }
        .fullScreenCover(isPresented: $showingPaywall) {
            PaywallView(onClose: { showingPaywall = false }, context: .fund)
        }
    }

    /// Opens a category, or the paywall when a non-Pro user taps a premium category.
    private func openCategory(_ category: AssetCategory) {
        if category.isPremium && !UserDefaultsManager.shared.isPro {
            FirebaseAnalyticsHelper.shared.logPremiumCategoryLocked(category: String(describing: category))
            showingPaywall = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            let name = String(describing: category)
            lastCategory = name
            markStep("type_list")
            FirebaseAnalyticsHelper.shared.logAddAssetCategorySelected(category: name, source: flowSource)
            // Tek seçenekli kategoride (BES) tek satırlık bir liste göstermenin
            // anlamı yok: doğrudan değer ekranına.
            if let only = Self.singleType(of: category) {
                selectInstrument(.legacy(only))
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { step = .typeList(category) }
            }
        }
    }

    /// Kategorinin tek bir sabit türü varsa o tür (liste adımı atlanır).
    private static func singleType(of category: AssetCategory) -> AssetType? {
        guard !category.isDynamic, category.assetTypes.count == 1 else { return nil }
        return category.assetTypes.first
    }

    private func selectInstrument(_ instrument: Instrument) {
        amount = ""
        purchasePrice = ""
        markStep("amount")
        FirebaseAnalyticsHelper.shared.logAddAssetInstrumentSelected(
            category: String(describing: instrument.category),
            symbol: instrument.symbol,
            source: flowSource
        )
        withAnimation(.easeInOut(duration: 0.2)) { step = .amount(instrument) }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))

            HStack {
                if !isFirstStep {
                    Button(action: goBack) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                            Text("Geri").font(.system(size: 16))
                        }
                        .foregroundColor(.primary)
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var title: String {
        switch step {
        case .category: return "Varlık Ekle"
        case .typeList(let category): return category.displayName
        case .amount: return "Varlık Ekle"
        }
    }

    private var isFirstStep: Bool {
        if case .category = step { return true }
        return false
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch step {
            case .amount(let instrument):
                step = Self.singleType(of: instrument.category) == nil ? .typeList(instrument.category) : .category
            case .typeList:
                step = .category
            case .category:
                break
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Step 1: category grid

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(AssetCategory.allCases) { category in
                    Button {
                        openCategory(category)
                    } label: {
                        VStack(spacing: 12) {
                            AssetIconTile(icon: category.iconName, tintHex: category.tintHex, size: 56)
                            Text(category.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(alignment: .topTrailing) {
                            // Pro badge on premium categories (until the user subscribes).
                            if category.isPremium && !UserDefaultsManager.shared.isPro {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .padding(10)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Step 2: type list

    /// All selectable instruments for a category — legacy enum types or live
    /// catalog rows (crypto / stocks).
    private func instrumentsForCategory(_ category: AssetCategory) -> [Instrument] {
        if category.isDynamic {
            return marketData.instruments(for: category).map { Instrument.dynamic($0, category: category) }
        }
        return category.assetTypes.map { Instrument.legacy($0) }
    }

    private func typeList(for category: AssetCategory) -> some View {
        let items = instrumentsForCategory(category).filter {
            $0.name.searchMatches(searchText) || $0.symbol.searchMatches(searchText)
        }
        return VStack(spacing: 0) {
            // Birkaç sabit seçenekte arama kutusu gürültü.
            if !category.isManual { searchBar(for: category) }
            if category == .fund { fundSearchHint }
            ScrollView {
                LazyVStack(spacing: 10) {
                    if items.isEmpty {
                        if isSearchingFunds {
                            ProgressView()
                                .padding(.top, 40)
                            Text("Fon aranıyor…")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else if category.isDynamic && searchText.isEmpty {
                            ProgressView()
                                .padding(.top, 40)
                            Text("Fiyatlar yükleniyor…")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else if category == .fund && searchText.count >= 2 {
                            Text("“\(searchText)” için fon bulunamadı.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 40)
                                .padding(.horizontal, 24)
                        }
                    }
                    ForEach(items, id: \.self) { instrument in
                        Button {
                            selectInstrument(instrument)
                        } label: {
                            HStack(spacing: 12) {
                                AssetIconTile(
                                    icon: instrument.iconName,
                                    tintHex: instrument.tintHex,
                                    size: 40,
                                    logoURL: marketData.logoURL(forSymbol: instrument.symbol)
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instrument.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(priceLabel(for: instrument))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: searchText) { _, newValue in
            scheduleFundSearch(category: category, query: newValue)
        }
        .onDisappear {
            fundSearchTask?.cancel()
            isSearchingFunds = false
        }
    }

    /// Debounced TEFAS search. When the user types a query in the fund list that
    /// isn't already matched by a locally-cached fund, ask the backend to fetch
    /// it live (~400ms after they stop typing). Results flow back through
    /// `marketData.fundPrices`, so the list updates automatically.
    private func scheduleFundSearch(category: AssetCategory, query: String) {
        fundSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard category == .fund, trimmed.count >= 2 else {
            isSearchingFunds = false
            return
        }
        // Skip the round-trip if a cached fund already matches the query.
        let hasLocalMatch = marketData.instruments(for: .fund).contains {
            $0.name.searchMatches(trimmed) || ($0.code ?? "").searchMatches(trimmed)
        }
        if hasLocalMatch { isSearchingFunds = false; return }

        fundSearchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingFunds = true }
            await marketData.searchRemoteFunds(query: trimmed)
            await MainActor.run { isSearchingFunds = false }
        }
    }

    /// Fon listesi TEFAS'ın tamamını içermiyor — yalnızca `assets_prices`'a daha
    /// önce girmiş fonlar listeleniyor. Kullanıcı aradığı fonu listede
    /// bulamayınca "bu uygulama o fonu desteklemiyor" sanıyordu; oysa arama
    /// kutusuna kodunu yazınca `search-tefas` fonu canlı çekip ekliyor.
    ///
    /// Yalnızca fonlarda gösteriliyor: canlı arama yalnızca bu kategoride var,
    /// hisse/kripto listelerinde aynı sözü vermek yanlış olurdu.
    private var fundSearchHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ProStyle.accent)
            Text("Listede tüm fonlar yok. Aradığın fonu göremiyorsan kodunu ya da adını yukarıya yaz — TEFAS'tan getirelim.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ProStyle.accent.opacity(0.08))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func searchBar(for category: AssetCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            // Fonlarda ipucu somut olsun: aranacak şey kod ya da ad.
            TextField(category == .fund ? "Fon kodu veya adı" : "Ara", text: $searchText)
                .font(.system(size: 16))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func priceLabel(for instrument: Instrument) -> String {
        if instrument.type.isManual { return "Değerini sen gir" }
        let price = currentMarketPrice(for: instrument)
        guard price > 0 else { return instrument.unit }
        // Locale'e uygun biçim: "%.2f" tüm listede nokta ayraç yazıyordu.
        return "\(price.formatAsCurrency()) / \(instrument.unit)"
    }

    // MARK: - Step 3: amount entry

    private func amountEntry(for instrument: Instrument) -> some View {
        ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        AssetIconTile(
                            icon: instrument.iconName,
                            tintHex: instrument.tintHex,
                            size: 34,
                            logoURL: marketData.logoURL(forSymbol: instrument.symbol)
                        )
                        Text(instrument.name)
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding(.top, 8)

                    // Enstrüman detayı: güncel fiyat + geçmiş grafik. Yalnızca
                    // dinamik kategorilerde — altın/dövizin geçmiş kaynağı yok.
                    if instrument.category.isDynamic {
                        InstrumentChartCard(
                            symbol: instrument.symbol,
                            category: instrument.category,
                            tint: Color(hex: instrument.tintHex),
                            currentPrice: currentMarketPrice(for: instrument),
                            dayChangePercent: marketData.dayChangePercent(forSymbol: instrument.symbol)
                        )
                    }

                    // Miktar — sistem klavyesi (decimalPad). Klavye yalnızca alana
                    // dokunulunca açılıyor; kapalıyken grafik ve tüm alanlar tek
                    // ekranda görünüyor.
                    // Elle girilen varlıklarda alan miktar değil, TL değer.
                    VStack(spacing: 4) {
                        Text(instrument.type.isManual ? "Güncel Değer" : "Miktar")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 44, weight: .heavy))
                                .fixedSize()
                                .focused($focusedField, equals: .amount)
                            Text(instrument.type.isManual ? "₺" : instrument.unit)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Rectangle()
                            .fill(focusedField == .amount ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 120, height: 2)
                        // Büyük ham sayılar ("5000000") tek bakışta okunmuyor.
                        if instrument.type.isManual, let value = parsedAmount, value > 0 {
                            Text(value.formatAsCurrency())
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .amount }

                    portfolioPicker

                    if instrument.type.isManual {
                        ManualNameField(name: $customName, example: instrument.type.manualNameExample)
                        purchasePriceField(for: instrument)
                        profitLossPreview(for: instrument)
                    } else {
                        LocationPicker(location: $location, suggestions: instrument.category.locationSuggestions)

                        // Türk Lirası has no purchase rate (it's the base currency).
                        if instrument.symbol != "TRY" {
                            purchasePriceField(for: instrument)
                            liveValuePreview(for: instrument, showsUnitPrice: !instrument.category.isDynamic)
                            profitLossPreview(for: instrument)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                // Boşluğa dokunmak da klavyeyi kapatır (kaydırma da).
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: amount) { _, new in
            let clean = new.sanitizedDecimal(maxDecimals: 4)
            if clean != new { amount = clean }
        }
        .onChange(of: purchasePrice) { _, new in
            let clean = new.sanitizedDecimal(maxDecimals: 2)
            if clean != new { purchasePrice = clean }
        }
        // Alt çubuk `safeAreaInset` ile veriliyor: VStack'in içindeyken kaydırma
        // alanı çubuğun varlığından habersizdi ve klavye açıldığında odaklanan
        // alan Kaydet'in altında kalıyordu.
        .safeAreaInset(edge: .bottom) {
            // decimalPad'de return tuşu yok; sistemin `.keyboard` toolbar'ı ise
            // iOS 26'da yüzen bir kapsül olarak Kaydet'in üstüne biniyordu —
            // kapatma düğmesi bu yüzden burada, yalnızca bir alan odaklıyken.
            HStack(spacing: 10) {
                if focusedField != nil {
                    Button { focusedField = nil } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 54, height: 54)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Klavyeyi kapat")
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                saveButton(for: instrument)
            }
            .animation(.easeInOut(duration: 0.2), value: focusedField)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(.bar)
        }
    }

    // Optional cost-basis input. For stocks/crypto/funds it's the "average cost";
    // for gold/FX it's the "purchased rate". Left empty -> current price is used.
    private func purchasePriceField(for instrument: Instrument) -> some View {
        let label = instrument.type.isManual ? instrument.type.manualCostLabel
            : (instrument.category.isDynamic ? "Ortalama Maliyet" : "Satın Alınan Kur")
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    Text("(Opsiyonel)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                // ₺ ile sayı bitişik durmalı: ayrı elemanlarken alan sağa
                // hizalandığı için arada boşluk kalıyordu.
                HStack(spacing: 2) {
                    if !purchasePrice.isEmpty {
                        Text("₺")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    TextField(instrument.type.isManual ? "Güncel değer" : "Güncel fiyat", text: $purchasePrice)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 16, weight: purchasePrice.isEmpty ? .regular : .semibold))
                        .fixedSize()
                        .focused($focusedField, equals: .purchasePrice)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(focusedField == .purchasePrice ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .purchasePrice }

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(instrument.type.isManual
                     ? "Belirtmezseniz kâr/zarar hesaplanmaz."
                     : "Belirtmezseniz güncel fiyattan alınmış kabul edilir.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    /// Live summary under the purchase-rate field: the current market price per
    /// unit and the entered amount × that price (total value), updated as the user
    /// types the quantity.
    /// `showsUnitPrice`: birim fiyat satırı. Grafik kartı gösterilen
    /// enstrümanlarda fiyat zaten kartın başlığında — burada tekrarlanmıyor.
    @ViewBuilder
    private func liveValuePreview(for instrument: Instrument, showsUnitPrice: Bool = true) -> some View {
        let unitPrice = currentMarketPrice(for: instrument)
        if unitPrice > 0 {
            let qty = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
            VStack(spacing: 0) {
                if showsUnitPrice {
                    HStack {
                        Text("Güncel Fiyat")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(unitPrice.formatAsCurrency()) / \(instrument.unit)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 12)

                    Divider()
                }

                HStack {
                    Text("Toplam Değer")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text((qty * unitPrice).formatAsCurrency())
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private func profitLossPreview(for instrument: Instrument) -> some View {
        if let pl = estimatedProfitLoss(for: instrument) {
            HStack(spacing: 6) {
                Image(systemName: pl.value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                Text("Tahmini Kâr/Zarar:")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("\(pl.value >= 0 ? "+" : "-")\(abs(pl.value).formatAsCurrency()) (%\(String(format: "%.2f", abs(pl.percent)).replacingOccurrences(of: ".", with: ",")))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(pl.value >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var portfolioPicker: some View {
        Menu {
            ForEach(realPortfolios) { portfolio in
                Button {
                    selectedPortfolio = portfolio
                } label: {
                    Label(portfolio.name, systemImage: selectedPortfolio?.id == portfolio.id ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Text("Portföy").foregroundColor(.secondary)
                Spacer()
                if let selected = selectedPortfolio {
                    Circle().fill(selected.color.color).frame(width: 8, height: 8)
                    Text(selected.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.primary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func saveButton(for instrument: Instrument) -> some View {
        Button(action: { save(instrument: instrument) }) {
            Text("Kaydet")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: isValidAmount
                            ? [Color(hex: "#0A84FF"), Color(hex: "#AF52DE")]
                            : [.gray, .gray.opacity(0.8)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!isValidAmount)
    }

    // MARK: - Sayı girişi

    private var isValidAmount: Bool {
        (Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 && selectedPortfolio != nil
    }

    private func currentMarketPrice(for instrument: Instrument) -> Double {
        if instrument.symbol == "TRY" { return 1.0 }
        return marketData.tryPrice(forSymbol: instrument.symbol) ?? 0.0
    }

    private var parsedAmount: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }

    /// Kaydedilecek miktar ve birim fiyat. Elle girilen varlıklarda alan TL
    /// değeri tutuyor: 1 adet × girilen değer.
    private func quantityAndPrice(for instrument: Instrument) -> (qty: Double, price: Double)? {
        guard let entered = parsedAmount, entered > 0 else { return nil }
        if instrument.type.isManual { return (1, entered) }
        return (entered, currentMarketPrice(for: instrument))
    }

    /// Live profit/loss estimate from the entered purchase rate vs the current market rate.
    private func estimatedProfitLoss(for instrument: Instrument) -> (value: Double, percent: Double)? {
        guard let (amountValue, current) = quantityAndPrice(for: instrument),
              let purchase = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")), purchase > 0,
              current > 0
        else { return nil }
        let value = (current - purchase) * amountValue
        let percent = (current - purchase) / purchase * 100.0
        return (value, percent)
    }

    // MARK: - Save

    private func save(instrument: Instrument) {
        guard let (amountValue, currentPrice) = quantityAndPrice(for: instrument) else {
            alertMessage = instrument.type.isManual ? "Lütfen geçerli bir değer girin." : "Lütfen geçerli bir miktar girin."
            showAlert = true
            return
        }
        guard let portfolio = selectedPortfolio else {
            alertMessage = "Lütfen bir portföy seçin."
            showAlert = true
            return
        }

        // Use the entered purchase rate as the cost basis when provided; otherwise the current rate.
        let enteredPurchase = Double(purchasePrice.replacingOccurrences(of: ",", with: "."))
        let costBasis = (enteredPurchase != nil && enteredPurchase! > 0) ? enteredPurchase! : currentPrice

        // Merge into an existing holding of the same instrument *at the same place*
        // in this portfolio — "evde 10 gram" ile "bankada 20 gram" ayrı varlıklar.
        // Elle girilenler hiç birleşmez: her ev/araba ayrı bir varlık.
        let place = LocationPicker.normalized(location)
        let existing = instrument.type.isManual ? nil : (portfolio.assets ?? []).first(where: {
            // Tür de eşit olmalı: Trabzon hasır fiyat sembolünü 14 ayar /
            // gram altınla paylaşıyor, onlarla birleşmemeli.
            $0.symbol == instrument.symbol && $0.type == instrument.type && $0.location == place
        })

        if let existing {
            let oldAmount = existing.amount
            PortfolioManager.shared.updatePurchasePrice(
                for: existing.id,
                oldAmount: oldAmount,
                newAmount: oldAmount + amountValue,
                newPrice: costBasis
            )
            existing.amount += amountValue
            existing.currentPrice = currentPrice
            existing.lastUpdated = Date()
            try? modelContext.save()

            AssetHistoryManager.shared.recordDailySnapshot(for: existing, modelContext: modelContext)
            AssetHistoryManager.shared.recordTransaction(
                for: existing, transactionType: .add,
                amount: amountValue, totalAmount: existing.amount,
                price: costBasis, context: modelContext
            )
        } else {
            let newAsset = Asset(
                type: instrument.type, symbol: instrument.symbol,
                name: instrument.name, unit: instrument.unit,
                amount: amountValue, currentRate: 0.0, currentPrice: currentPrice
            )
            newAsset.portfolio = portfolio
            if instrument.type.isManual {
                newAsset.symbol = AssetType.manualSymbol(for: newAsset.id)
                let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { newAsset.name = String(name.prefix(40)) }
            } else {
                newAsset.location = place
            }
            PortfolioManager.shared.storePurchasePrice(for: newAsset.id, price: costBasis)
            modelContext.insert(newAsset)
            try? modelContext.save()

            // Elle girilende bu geçmiş "değer" geçmişi — Analiz'in yeniden kurması
            // onu okuyor; ilk nokta alış fiyatı olursa bugün eksik değerlenirdi.
            // Alış fiyatı zaten maliyet olarak saklanıyor.
            AssetHistoryManager.shared.createInitialSnapshot(
                for: newAsset,
                purchasePrice: instrument.type.isManual ? currentPrice : costBasis,
                modelContext: modelContext
            )
            AssetHistoryManager.shared.recordTransaction(
                for: newAsset, transactionType: .initial,
                amount: amountValue, totalAmount: amountValue,
                price: costBasis, context: modelContext
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let all = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
            PortfolioManager.shared.forceUpdate(with: all)
        }
        // Privacy-safe: only the instrument class/symbol + behavioural flags — never
        // the amount, value, or entered purchase price.
        didSave = true
        FirebaseAnalyticsHelper.shared.logAssetAdded(
            category: String(describing: instrument.category),
            symbol: instrument.symbol,
            isMerge: existing != nil,
            hasPurchasePrice: enteredPurchase != nil && enteredPurchase! > 0,
            source: flowSource
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Show the interstitial at the natural transition after this sheet closes,
        // not on open. Gated/frequency-capped by the ad managers (and skipped for
        // Pro). MainTabView shows it once the sheet has dismissed.
        AddAssetPresenter.shared.scheduleInterstitialAfterClose()
        dismiss()
    }
}
