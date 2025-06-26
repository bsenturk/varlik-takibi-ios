//
//  ViewExtension.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 25.02.2024.
//

import SwiftUI

extension View {
    func navigationBarColor(_ backgroundColor: UIColor, _ tintColor: UIColor) -> some View {
        self.modifier(NavigationBarColorModifier(backgroundColor: backgroundColor, tintColor: tintColor))
    }
}

struct NavigationBarColorModifier: ViewModifier {
    var backgroundColor: UIColor
    var tintColor: UIColor
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                let coloredAppearance = UINavigationBarAppearance()
                coloredAppearance.configureWithOpaqueBackground()
                coloredAppearance.titleTextAttributes = [.foregroundColor: tintColor]
                coloredAppearance.largeTitleTextAttributes = [.foregroundColor: tintColor]
                coloredAppearance.shadowColor = .clear
                coloredAppearance.backgroundColor = backgroundColor
                
                UINavigationBar.appearance().standardAppearance = coloredAppearance
                UINavigationBar.appearance().compactAppearance = coloredAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance
            }
    }
}
