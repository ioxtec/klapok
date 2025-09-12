//
//  EditorView.swift
//  Fluttro
//

import SwiftUI
#if os(macOS)
import AppKit

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left panel
            VStack {
                Text("Opcje")
                    .font(.headline)
                    .padding()
                
                Button("Opcja 1") { /* akcja */ }
                Button("Opcja 2") { /* akcja */ }
                
                Spacer()
            }
            .frame(width: 150)
            .background(Color.gray.opacity(0.1))
            .border(Color.gray)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Edytor Zrzutu")
                        .font(.headline)
                    Spacer()
                    Button("Zamknij") { 
                        viewModel.close()
                    }
                }
               .padding()
               .frame(height: 40)
                
                Divider()
                
                if let image = viewModel.image {
                    GeometryReader { geo in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                    }
                } else {
                    Text("No image")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Divider()
                
                HStack {
                    Button("Zapisz") { /* akcja zapisu */ }
                    Spacer()
                    Button("Udostępnij") { /* akcja udostępniania */ }
                }
                .padding()
                .frame(height: 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 400)
        .border(Color.black)
    }
        
}

#Preview {
    EditorView(viewModel: EditorViewModel())
}

#endif

