//
//  AddAssetView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 23.02.2024.
//

import SwiftUI

struct AddAssetView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AddAssetViewModel
    @State private var isLoaderHidden = false
    @State private var showInputFieldsEmptyPopup = false
    
    init(viewModel: AddAssetViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            Color.primaryBrown.ignoresSafeArea()
            GeometryReader { geometry in
                VStack {
                    AddAssetTextFieldView(title: "Varlık Türü", text: $viewModel.selectedAsset, placeholder: "Seçiniz", stackWidth: abs(geometry.size.width - 24), tag: 0, isKeyboardDisabled: true, action: {
                        viewModel.assetTypeSelection = true
                    })
                    
                    .popover(isPresented: $viewModel.assetTypeSelection) {
                        VStack {
                            Picker("Varlık seçin", selection: $viewModel.selectedAsset) {
                                ForEach(viewModel.currencies, id: \.self) {
                                    Text($0)
                                }
                            }
                            .pickerStyle(.wheel)
                            .presentationDetents([.height(200)])
                        }
                    }
                    .clipShape(.rect(cornerRadius: 8))
                    AddAssetTextFieldView(title: "Adet", text: $viewModel.assetQuantity, placeholder: "1000", stackWidth: abs(geometry.size.width - 24), tag: 1, keyboardType: .numberPad, isKeyboardDisabled: false, action: {
                        
                    })
                    .padding(.top)
                    Spacer()
                    Button {
                        guard !viewModel.isInputFieldsEmpty else {
                            withAnimation {
                                showInputFieldsEmptyPopup.toggle()
                            }
                            return
                        }
                        
                        isLoaderHidden = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isLoaderHidden = false
                            viewModel.saveButtonAction()
                            presentationMode.wrappedValue.dismiss()
                        }
                        
                    } label: {
                        Text("Kaydet")
                            .font(.workSansBold(size: 16))
                            .frame(width: abs(geometry.size.width - 24), height: 50)
                            .background(Color.primaryOrange)
                            .foregroundStyle(Color.primaryBrown)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }, label: {
                                Image(systemName: "xmark")
                                    .tint(.white)
                            })
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("Varlık Ekle")
            .navigationBarBackButtonHidden()
            .navigationBarTitleDisplayMode(.large)
            if isLoaderHidden {
                LoaderView()
            }
            
            if showInputFieldsEmptyPopup {
                PopupView(
                    title: "Uyarı",
                    message: "Lütfen tüm alanları doldurun.",
                    firstButtonTitle: "Tamam",
                    secondButtonTitle: nil,
                    firstAction: {
                        withAnimation {
                            showInputFieldsEmptyPopup.toggle()
                        }
                    },
                    secondAction: {}
                )
                .transition(.asymmetric(insertion: .scale, removal: .opacity))
            }
        }
    }
}

struct AddAssetTextFieldView: View {
    var title: String
    @Binding var text: String
    var placeholder: String
    var stackWidth: CGFloat
    var tag: Int
    @FocusState private var isFocused: Bool
    @State var keyboardType: UIKeyboardType = .default
    @State var isKeyboardDisabled: Bool
    var action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(.white)
                .font(.workSansSemiBold(size: 16))
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .disabled($isKeyboardDisabled.wrappedValue)
                .padding(.leading, 10)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 56)
                .keyboardType(keyboardType)
                .font(.workSansSemiBold(size: 14))
                .foregroundStyle(.white)
                .background(Color.secondaryBrown)
                .clipShape(.rect(cornerRadius: 8))
                .onTapGesture(perform: action)
                .onChange(of: text) { text in
                    if let firstChar = text.first, tag == 1 {
                        if String(firstChar) == "0" {
                            self.text = ""
                            return
                        }
                    }
                    
                    if tag != 0 {
                        self.text = String(text.prefix(6))
                    }
                }
                .tag(tag)
                .toolbar {
                    ToolbarItem(placement: .keyboard) {
                        if tag != 0 {
                            HStack {
                                Spacer()
                                Button(action: {
                                    isFocused = false
                                }, label: {
                                    Text("Tamam")
                                        .font(.workSansSemiBold(size: 16))
                                        .foregroundStyle(.black)
                                })
                            }
                        }
                    }
                }
        }
        .frame(width: stackWidth)
    }
}

#Preview {
    AddAssetView(viewModel: AddAssetViewModel())
}
