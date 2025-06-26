//
//  LoaderView.swift
//  MyGolds
//
//  Created by Burak Ahmet Şentürk on 12.03.2024.
//

import SwiftUI

struct LoaderView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(2, anchor: .center)
            .progressViewStyle(.circular)
            .tint(.white)
    }
}
