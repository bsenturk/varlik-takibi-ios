//
//  AssetsView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 16.02.2024.
//

import SwiftUI

struct AssetsView: View {
    
    @Environment(\.managedObjectContext) var viewContext
    @State var addAssetViewNavigate = false
    @State var isShowingPopupForRemovingAsset = false
    @StateObject private var viewModel = AssetsViewModel()
    @State private var selectedAsset: AssetEntity?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBrown
                VStack {
                    HStack {
                        Text(viewModel.totalAssetValue)
                            .foregroundStyle(.white)
                            .padding(.leading)
                            .font(.workSansBold(size: 28))
                        Spacer()
                    }
                    Spacer()
                    
                    List {
                        ForEach(viewModel.assets, id: \.self) { asset in
                            NavigationLink {
                                AddAssetView(viewModel: AddAssetViewModel(
                                    selectedAsset: asset.currencyName ?? "",
                                    assetQuantity: String(asset.quantity), 
                                    assetEntity: asset
                                )
                                )
                                .toolbar(.hidden, for: .tabBar)
                            } label: {
                                AssetRow(
                                    currency: Binding.constant(asset.currencySymbol ?? ""),
                                    assetName: Binding.constant(asset.currencyName ?? ""),
                                    assetQuantity: Binding.constant(String(asset.quantity)),
                                    assetTotalValue: Binding.constant(viewModel.calculateAssetValue(asset: asset))
                                )
                                .swipeActions {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            isShowingPopupForRemovingAsset.toggle()
                                        }
                                        self.selectedAsset = asset
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .tint(Color.red)
                                }
                            }
                            .overlay {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .foregroundStyle(Color.primaryBrown)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 10, leading: 5, bottom: 5, trailing: 5))
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.primaryBrown)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                addAssetViewNavigate = true
                            }, label: {
                                Image(systemName: "plus")
                                    .tint(.white)
                            })
                        }
                    }
                    .navigationDestination(isPresented: $addAssetViewNavigate) {
                        AddAssetView(viewModel: AddAssetViewModel())
                            .toolbar(.hidden, for: .tabBar)
                    }
                }
                if viewModel.isLoaderShown {
                    LoaderView()
                }
                
                if CoreDataStack.shared.fetch(entityName: "AssetEntity").isEmpty {
                    EmptyView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(.hidden, for: .tabBar)
                        .transition(.opacity)
                }
                
                if isShowingPopupForRemovingAsset {
                    PopupView(
                        title: "Uyarı",
                        message: "Varlığınızı silmek istediğinizden emin misiniz?",
                        firstButtonTitle: "Evet",
                        secondButtonTitle: "Vazgeç",
                        firstAction: { 
                            guard let selectedAsset else { return }
                            withAnimation {
                                isShowingPopupForRemovingAsset.toggle()
                            }
                            
                            viewModel.removeAsset(asset: selectedAsset)
                            viewModel.viewOnAppear()
                        },
                        secondAction: {
                            withAnimation {
                                isShowingPopupForRemovingAsset.toggle()
                            }
                        }
                    )
                    .transition(.scale)
                }
            }
            .navigationTitle("Varlıklarım")
            .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.large)
            .navigationBarColor(.primaryBrown, .white)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.requestTrackingAuthorization()
                }
                viewModel.viewOnAppear()
            }
        }
    }
}

#Preview {
    AssetsView()
}
