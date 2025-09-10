//
//  ContentView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var showPanel = true

    var body: some View {
        EmptyView()
            .floatingPanel(isPresented: $showPanel) {
                PanelView()
            }
    }
}
#Preview {
    ContentView()
}
