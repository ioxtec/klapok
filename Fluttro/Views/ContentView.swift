//
//  ContentView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var editorViewModel = EditorViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Fluttro - Zrzuty Ekranu")
                .font(.title)
                .padding()

            VStack(spacing: 15) {
                Button("Zrzut całego ekranu") {
                    Task {
                        await editorViewModel.captureFullScreen()
                    }
                }
                .disabled(editorViewModel.isCapturing)

                Button("Zrzut wybranego obszaru") {
                    // Area selection is now handled by FloatingPanelView
                    print("Use FloatingPanelView for area selection")
                }
                .disabled(true)

                Button("Zrzut okna aplikacji") {
                    // Window selection is now handled by FloatingPanelView
                    print("Use FloatingPanelView for window selection")
                }
                .disabled(true)
            }
            .buttonStyle(.borderedProminent)

            if editorViewModel.isCapturing {
                ProgressView("Robię zrzut...")
                    .padding()
            }
        }
        .frame(width: 300, height: 250)
        .sheet(isPresented: $editorViewModel.isPresented) {
            if editorViewModel.image != nil {
                EditorView(viewModel: editorViewModel)
            }
        }
    }
}
#Preview {
    ContentView()
}
