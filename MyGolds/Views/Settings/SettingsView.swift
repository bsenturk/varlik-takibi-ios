//
//  SettingsView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 4.05.2024.
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.requestReview) var requestReview
    @State var isPrivacyPolicyClicked = false
    @State var isUserCanSendMail = false
    @State var isUserCantSendMail = false
    @State var result: Result<MFMailComposeResult, Error>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.primaryBrown
                VStack {
                    List {
                        ForEach(viewModel.sections, id: \.hashValue) { section in
                            Section() {
                                Text(section.title)
                                    .font(.workSansBold(size: 14))
                                    .foregroundStyle(Color.white)
                                ForEach(section.rows, id: \.hashValue) { row in
                                    SettingsRow(model: SettingsRowModel(image: row.image, title: row.title))
                                        .onTapGesture {
                                            getRowActions(row: row)
                                        }
                                }
                                .listRowBackground(Color.secondaryBrown)
                                .listRowSeparator(.hidden)
                            }
                            .listRowBackground(Color.secondaryBrown)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    Spacer()
                    Text(viewModel.getAppVersion())
                        .font(.workSansRegular(size: 16))
                        .foregroundStyle(Color.gray)
                        .padding(.bottom, 12)
                }
                if isUserCantSendMail {
                    PopupView(
                        title: "Hata",
                        message: "Mail uygulamanız ayarlı olmadığından şuan mail gönderme işlemi gerçekleştiremiyorsunuz.",
                        firstButtonTitle: "Tamam",
                        secondButtonTitle: nil,
                        firstAction: {
                            withAnimation {
                                isUserCantSendMail.toggle()
                            }
                        },
                        secondAction: {}
                    )
                    .transition(.asymmetric(insertion: .scale, removal: .opacity))
                }
            }
            .navigationDestination(isPresented: $isPrivacyPolicyClicked) {
                WebView(url: Constants.URLs.privacyPolicyUrl)
                    .toolbar(.hidden, for: .tabBar)
            }
            .sheet(isPresented: $isUserCanSendMail) {
                MailView(isShowing: $isUserCanSendMail, result: $result)
            }
            .navigationTitle("Ayarlar")
            .navigationBarColor(.primaryBrown, .white)
        }
    }
    
    private func getRowActions(row: SettingsViewModel.RowType) {
        switch row {
        case .sendFeedback:
            if MFMailComposeViewController.canSendMail() {
                isUserCanSendMail = true
            } else {
                withAnimation {
                    isUserCantSendMail = true
                }
            }
            
        case .writeReview:
            requestReview()
        case .shareApp:
            guard let data = URL(string: viewModel.getAppStoreUrl) else { return }
            let av = UIActivityViewController(activityItems: [data], applicationActivities: nil)
            let root = UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .first { $0.isKeyWindow }?.rootViewController
            root?.present(av, animated: true)
        case .privacyPolicy:
            isPrivacyPolicyClicked = true
        }
    }

}

#Preview {
    SettingsView()
}
