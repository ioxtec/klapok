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
        VStack(spacing: 12) {
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
        }
        .padding()
        .frame(minWidth: 640, minHeight: 420)
    }
}

#Preview {
    EditorView(viewModel: EditorViewModel())
}

#endif

