//
//  AddAssetViewModel.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 3.03.2024.
//

import SwiftUI

final class AddAssetViewModel: ObservableObject {
    
    // MARK: - Properties
    var currenciesDict = ["": "", "Gram Altın": "aux", "Çeyrek Altın": "aux", "Yarım Altın": "aux", "Tam Altın": "aux", "Cumhuriyet Altını": "aux", "Gram Gümüş": "agx", "Dolar": "usd", "Euro": "euro", "Sterlin": "gbp"]
    var currencies = ["", "Gram Altın", "Çeyrek Altın", "Yarım Altın", "Tam Altın", "Cumhuriyet Altını", "Gram Gümüş", "Dolar", "Euro", "Sterlin"]
    @Published var selectedAsset = ""
    @Published var assetTypeSelection = false
    @Published var assetQuantity = ""
    var assetEntity: AssetEntity?
    
    convenience init(selectedAsset: String, assetQuantity: String, assetEntity: AssetEntity) {
        self.init()
        self.selectedAsset = selectedAsset
        self.assetQuantity = assetQuantity
        self.assetEntity = assetEntity
    }
    
    // MARK: - Helpers
    var isInputFieldsEmpty: Bool {
        selectedAsset.isEmpty || assetQuantity.isEmpty
    }
    
    func saveButtonAction() {
        assetEntity == nil ? saveAssetToCoreData() : updateAsset()
    }
    
    private func saveAssetToCoreData() {
        guard let entity = CoreDataStack.shared.create(entityName: "AssetEntity") as? AssetEntity else { return }
        entity.currencyName = selectedAsset
        entity.quantity = Int64(assetQuantity) ?? .zero
        entity.currencySymbol = currenciesDict[selectedAsset]
        
        CoreDataStack.shared.saveContext()
    }
    
    private func updateAsset() {
        guard let assetEntity,
              let object = CoreDataStack.shared.getObject(object: assetEntity) else { return }
        object.currencyName = selectedAsset
        object.quantity = Int64(assetQuantity) ?? .zero
        object.currencySymbol = currenciesDict[selectedAsset]
        CoreDataStack.shared.saveContext()
    }
}
