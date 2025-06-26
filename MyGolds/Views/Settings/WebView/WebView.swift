//
//  WebView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 7.05.2024.
//

import SwiftUI
import WebKit

struct WebView: View {
    let url: String
    
    var body: some View {
        WebViewRepresentable(url: url)
    }
}

#Preview {
    WebView(url: "")
}

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    let url: String
    
    init(url: String) {
        webView = WKWebView(frame: .zero)
        self.url = url
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: url) else { return }
        webView.load(URLRequest(url: url))
    }
}
