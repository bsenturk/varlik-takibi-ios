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
    
    @State private var selectedAssetType: AssetType
    @State private var amount: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isAmountFocused: Bool
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
            // Whole number - show without decimal
            amountString = String(format: "%.0f", asset.amount)
        } else {
            // Has decimal - show with appropriate precision
            amountString = String(format: "%.2f", asset.amount).replacingOccurrences(of: ".00", with: "")
        }
        self._amount = State(initialValue: amountString)
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
                .background(Color(.systemGray6))
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
                        // Mevcut basit filtrelerine ek olarak decimal control ekle
                        var processedValue = newValue.replacingOccurrences(of: ",", with: ".")
                        
                        // Tek decimal point kontrolü
                        let components = processedValue.components(separatedBy: ".")
                        if components.count > 2 {
                            processedValue = components[0] + "." + components[1]
                        }
                        
                        // 3 hane küsurat limiti
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
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isAmountFocused ? .blue : .clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.2), value: isAmountFocused)
            )
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
                colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
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
                
                try modelContext.save()
                
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
                    
                    // Store old amount for weighted average calculation
                    let oldAmount = existingAsset.amount
                    
                    // Update purchase price with weighted average
                    PortfolioManager.shared.updatePurchasePrice(
                        for: existingAsset.id,
                        oldAmount: oldAmount,
                        newAmount: oldAmount + amountValue,
                        newPrice: currentPrice
                    )
                    
                    // Add new amount to existing asset
                    existingAsset.amount += amountValue
                    existingAsset.currentPrice = currentPrice
                    existingAsset.lastUpdated = Date()
                    
                    try modelContext.save()
                    
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
                    
                    let newAsset = Asset(
                        type: selectedAssetType,
                        amount: amountValue,
                        currentRate: 0.0,
                        currentPrice: currentPrice
                    )
                    
                    // Store purchase price for new asset
                    PortfolioManager.shared.storePurchasePrice(for: newAsset.id, price: currentPrice)
                    
                    modelContext.insert(newAsset)
                    try modelContext.save()
                    
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
