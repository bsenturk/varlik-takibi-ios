//
//  EmptyView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 27.02.2024.
//

import SwiftUI

struct EmptyView: View {
    @State var addAssetViewNavigate = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBrown.ignoresSafeArea()
                GeometryReader{ geometry in
                    VStack {
                        getHeaderImage(width: geometry.size.width)
                        getTitleText(width: geometry.size.width)
                        getInfoText(width: geometry.size.width)
                        Spacer()
                        getAddAssetButton(width: geometry.size.width)
                    }
                    .foregroundStyle(.white)
                }
                .navigationDestination(isPresented: $addAssetViewNavigate) {
                    AddAssetView(viewModel: AddAssetViewModel())
                }
            }
            .navigationBarColor(.primaryBrown, .white)
        }
    }
    
    private func getHeaderImage(width: Double) -> some View {
        Image(.moneyMan)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: 300)
    }
    
    private func getTitleText(width: Double) -> some View {
        Text("Varlıklarınızı takip etmeye başlayın")
            .font(.workSansBold(size: 32))
            .frame(width: abs(width - 24), alignment: .leading)
            .padding(.top, -15)
    }
    
    private func getInfoText(width: Double) -> some View {
        Text("İlk varlığınızı ekleyin ve güncel kur karşılığını görün")
            .font(.workSansRegular(size: 20))
            .frame(width: abs(width - 24), alignment: .leading)
            .padding(1)
    }
    
    private func getAddAssetButton(width: Double) -> some View {
        Button {
            addAssetViewNavigate = true
        } label: {
            Text("Varlık Ekle")
                .font(.workSansBold(size: 18))
                .frame(width: abs(width - 24), height: 50)
                .background(Color.primaryOrange)
                .foregroundStyle(Color.primaryBrown)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.bottom, 12)
        }
    }
}

#Preview {
    EmptyView()
}
