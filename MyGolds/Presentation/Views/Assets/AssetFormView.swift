//
//  AssetFormView.swift
//  MyGolds
//
//  Created by Burak Şentürk on 27.06.2025.
//

import SwiftUI
import SwiftData

struct AssetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var interstitialAdManager: InterstitialAdManager

    @State private var selectedAssetType: AssetType
    @State private var amount: String
    @State private var purchasePrice: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isPurchasePriceFocused: Bool
    @StateObject private var viewModel = AssetsFormViewModel()
    
    // Edit mode properties
    private let asset: Asset?
    private let isEditMode: Bool
    
    // MARK: - Initializers
    
    // For adding new asset
    init() {
        self.asset = nil
        self.isEditMode = false
        self._selectedAssetType = State(initialValue: .gold)
        self._amount = State(initialValue: "")
    }
    
    // For editing existing asset
    init(asset: Asset) {
        self.asset = asset
        self.isEditMode = true
        self._selectedAssetType = State(initialValue: asset.type)
        
        // Format amount properly - remove .0 if it's a whole number
        let amountString: String
        if asset.amount.truncatingRemainder(dividingBy: 1) == 0 {
            amountString = String(format: "%.0f", asset.amount)
        } else {
            amountString = String(format: "%.2f", asset.amount).replacingOccurrences(of: ".00", with: "")
        }
        self._amount = State(initialValue: amountString)
        
        // Load purchase price if available
        if let storedPrice = PortfolioManager.shared.assetPurchasePrices[asset.id] {
            let priceString = String(format: "%.2f", storedPrice).replacingOccurrences(of: ".00", with: "")
            self._purchasePrice = State(initialValue: priceString)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Asset Type Selection
                assetTypeSection
                
                // Amount Input
                amountInputSection
                
                // Purchase Price Input (Opsiyonel)
                purchasePriceSection
                
                currentRateSection(rate: viewModel.getSelectedAsset(from: selectedAssetType.displayName)?.sellPrice ?? "")
                
                Spacer()
                
                // Action Buttons
                actionButtonsSection
            }
            .padding(.horizontal, 24)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .alert("Hata", isPresented: $showingAlert) {
                Button("Tamam") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // Show interstitial ad when form opens
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    interstitialAdManager.showAdIfAvailable()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                Text(isEditMode ? "Varlık Düzenle" : "Varlık Ekle")
                    .font(.title2.bold())
                
                Text(isEditMode ? "Varlık bilgilerinizi güncelleyin" : "Yeni bir varlık ekleyerek portföyünüzü genişletin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
        }
    }
    
    private var assetTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Varlık Türü")
                .font(.headline)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(AssetType.allCases, id: \.self) { assetType in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAssetType = assetType
                        }
                    }) {
                        HStack {
                            Image(systemName: assetType.iconName)
                            Text(assetType.displayName)
                            Spacer()
                            if selectedAssetType == assetType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedAssetType.iconName)
                        .foregroundColor(Color(selectedAssetType.color))
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedAssetType.displayName)
                            .foregroundColor(.primary)
                            .font(.headline)
                        
                        Text("Birim: \(selectedAssetType.unit)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6))
                )
                .cornerRadius(12)
            }
        }
    }
    
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Miktar")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .font(.title2)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: amount) { newValue, _ in
                        var processedValue = newValue.replacingOccurrences(of: ",", with: ".")
                        
                        let components = processedValue.components(separatedBy: ".")
                        if components.count > 2 {
                            processedValue = components[0] + "." + components[1]
                        }
                        
                        if let dotIndex = processedValue.firstIndex(of: ".") {
                            let afterDot = processedValue.distance(from: dotIndex, to: processedValue.endIndex) - 1
                            if afterDot > 3 {
                                let endIndex = processedValue.index(dotIndex, offsetBy: 4)
                                processedValue = String(processedValue[..<endIndex])
                            }
                        }
                        
                        if processedValue != newValue {
                            amount = processedValue
                        }
                    }
                
                Text(selectedAssetType.unit)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6))
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAmountFocused ? .blue : .clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.2), value: isAmountFocused)
            )
        }
    }
    
    // MARK: - Purchase Price Section
    
    private var purchasePriceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Satın Alınan Kur")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("(Opsiyonel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField("", text: $purchasePrice)
                    .keyboardType(.decimalPad)
                    .focused($isPurchasePriceFocused)
                    .font(.body)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: purchasePrice) { newValue, _ in
                        var processedValue = newValue.replacingOccurrences(of: ",", with: ".")
                        
                        let components = processedValue.components(separatedBy: ".")
                        if components.count > 2 {
                            processedValue = components[0] + "." + components[1]
                        }
                        
                        if let dotIndex = processedValue.firstIndex(of: ".") {
                            let afterDot = processedValue.distance(from: dotIndex, to: processedValue.endIndex) - 1
                            if afterDot > 2 {
                                let endIndex = processedValue.index(dotIndex, offsetBy: 3)
                                processedValue = String(processedValue[..<endIndex])
                            }
                        }
                        
                        if processedValue != newValue {
                            purchasePrice = processedValue
                        }
                    }
                
                if !purchasePrice.isEmpty {
                    Button(action: {
                        purchasePrice = ""
                        isPurchasePriceFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray6))
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPurchasePriceFocused ? .blue : .clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.2), value: isPurchasePriceFocused)
            )
            
            // Info text
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Bu alan boş bırakılırsa varlık eklenirken güncel kur kullanılır")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func currentRateSection(rate: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Güncel Kur")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(rate)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Calculate total value using parseToDouble
                if let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
                   amountValue > 0,
                   let priceValue = rate.parseToDouble() {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Toplam Değer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text((amountValue * priceValue).formatAsCurrency())
                            .font(.title2.weight(.bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Kurlar anlık olarak değişebilir")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: colorScheme == .dark ?
                [Color.blue.opacity(0.15), Color.purple.opacity(0.15)] :
                [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(colorScheme == .dark ? 0.4 : 0.2), lineWidth: 1)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: saveAsset) {
                HStack {
                    if isEditMode {
                        Image(systemName: "checkmark.circle.fill")
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    
                    Text(isEditMode ? "Güncelle" : "Varlık Ekle")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: isValidInput ? [.blue, .blue.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: isValidInput ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!isValidInput)
            .scaleEffect(isValidInput ? 1.0 : 0.98)
            .animation(.easeInOut(duration: 0.2), value: isValidInput)
            
            Button(action: { dismiss() }) {
                Text("İptal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Helper Properties & Functions
    
    private var isValidInput: Bool {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            return false
        }
        return amountValue > 0
    }
    
    // MARK: - Asset Saving Logic
    
    private func saveAsset() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), amountValue > 0 else {
            alertMessage = "Lütfen geçerli bir miktar girin."
            showingAlert = true
            return
        }
        
        do {
            if isEditMode {
                // Update existing asset
                guard let asset = asset else {
                    alertMessage = "Güncellenecek varlık bulunamadı."
                    showingAlert = true
                    return
                }

                // Önceki miktarı kaydet
                let previousAmount = asset.amount

                asset.type = selectedAssetType
                asset.amount = amountValue
                asset.name = selectedAssetType.displayName
                asset.unit = selectedAssetType.unit
                asset.lastUpdated = Date()

                // Update currentPrice with market data
                if let currentPriceString = viewModel.getSelectedAsset(from: selectedAssetType.displayName)?.sellPrice,
                   let priceValue = currentPriceString.parseToDouble() {
                    asset.currentPrice = priceValue
                }

                // Update purchase price if provided
                if !purchasePrice.isEmpty,
                   let customPurchasePrice = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) {
                    PortfolioManager.shared.storePurchasePrice(for: asset.id, price: customPurchasePrice)
                }

                try modelContext.save()

                // Bugünün snapshot'ını güncelle
                AssetHistoryManager.shared.recordDailySnapshot(for: asset, modelContext: modelContext)

                // İşlem geçmişi kaydet - Miktar değişimine göre add veya remove
                let amountDifference = amountValue - previousAmount
                let transactionType: AssetTransactionHistory.TransactionType

                if amountDifference > 0 {
                    transactionType = .add
                } else if amountDifference < 0 {
                    transactionType = .remove
                } else {
                    // Miktar değişmedi, işlem geçmişi kaydetme
                    transactionType = .edit
                }

                // Sadece miktar değiştiyse transaction kaydet
                if amountDifference != 0 {
                    AssetHistoryManager.shared.recordTransaction(
                        assetType: asset.type,
                        transactionType: transactionType,
                        amount: abs(amountDifference),  // Mutlak değer
                        totalAmount: amountValue,       // Yeni toplam miktar
                        price: asset.currentPrice,
                        context: modelContext
                    )
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let allAssets = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                    PortfolioManager.shared.forceUpdate(with: allAssets)
                }
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
            } else {
                // Check if asset type already exists
                let existingAssets = try modelContext.fetch(FetchDescriptor<Asset>())
                
                if let existingAsset = existingAssets.first(where: { $0.type == selectedAssetType }) {
                    // Get current price for calculation
                    let currentPriceString = viewModel.getSelectedAsset(from: selectedAssetType.displayName)?.sellPrice ?? "0"
                    let currentPrice = currentPriceString.parseToDouble() ?? 0.0
                    
                    // Determine purchase price to use
                    let priceToUse: Double
                    if !purchasePrice.isEmpty,
                       let customPurchasePrice = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) {
                        priceToUse = customPurchasePrice
                    } else {
                        priceToUse = currentPrice
                    }
                    
                    // Store old amount for weighted average calculation
                    let oldAmount = existingAsset.amount
                    
                    // Update purchase price with weighted average
                    PortfolioManager.shared.updatePurchasePrice(
                        for: existingAsset.id,
                        oldAmount: oldAmount,
                        newAmount: oldAmount + amountValue,
                        newPrice: priceToUse
                    )
                    
                    // Add new amount to existing asset
                    existingAsset.amount += amountValue
                    existingAsset.currentPrice = currentPrice
                    existingAsset.lastUpdated = Date()
                    
                    try modelContext.save()
                    
                    // Bugünün snapshot'ını güncelle
                    AssetHistoryManager.shared.recordDailySnapshot(for: existingAsset, modelContext: modelContext)
                    
                    // İşlem geçmişi kaydet (Add)
                    AssetHistoryManager.shared.recordTransaction(
                        assetType: existingAsset.type,
                        transactionType: .add,
                        amount: amountValue,
                        totalAmount: existingAsset.amount,
                        price: currentPrice,
                        context: modelContext
                    )
                    
                    // Force immediate portfolio update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let allAssets = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                        PortfolioManager.shared.forceUpdate(with: allAssets)
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                } else {
                    // Create new asset
                    let currentPriceString = viewModel.getSelectedAsset(from: selectedAssetType.displayName)?.sellPrice ?? "0"
                    let currentPrice = currentPriceString.parseToDouble() ?? 0.0
                    
                    // Determine purchase price to use
                    let priceToUse: Double
                    if !purchasePrice.isEmpty,
                       let customPurchasePrice = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) {
                        priceToUse = customPurchasePrice
                    } else {
                        priceToUse = currentPrice
                    }
                    
                    let newAsset = Asset(
                        type: selectedAssetType,
                        amount: amountValue,
                        currentRate: 0.0,
                        currentPrice: currentPrice
                    )
                    
                    // Store purchase price for new asset
                    PortfolioManager.shared.storePurchasePrice(for: newAsset.id, price: priceToUse)
                    
                    modelContext.insert(newAsset)
                    try modelContext.save()
                    
                    // İlk kez eklenen varlık için initial snapshot oluştur
                    AssetHistoryManager.shared.createInitialSnapshot(
                        for: newAsset,
                        purchasePrice: priceToUse,
                        modelContext: modelContext
                    )
                    
                    // İşlem geçmişi kaydet (Initial)
                    AssetHistoryManager.shared.recordTransaction(
                        assetType: newAsset.type,
                        transactionType: .initial,
                        amount: amountValue,
                        totalAmount: amountValue,
                        price: currentPrice,
                        context: modelContext
                    )
                    
                    // Force immediate portfolio update
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let allAssets = (try? modelContext.fetch(FetchDescriptor<Asset>())) ?? []
                        PortfolioManager.shared.forceUpdate(with: allAssets)
                    }
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            }
            
            dismiss()
            
        } catch {
            alertMessage = "Varlık kaydedilirken bir hata oluştu: \(error.localizedDescription)"
            showingAlert = true
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
}
