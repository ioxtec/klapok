//
//  EditorView.swift
//  Fluttro
//

import SwiftUI

#if os(macOS)
    import AppKit

    struct EditorView: View {
        @ObservedObject var viewModel: EditorViewModel
        @StateObject private var settings = AppSettings.shared

        var body: some View {
            VStack(spacing: 0) {
                // Main area with left panel and image
                HStack(spacing: 0) {
                    // Left panel with tools
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tools")
                            .font(.headline)
                            .padding(.bottom, 8)

                        Button("Copy") {
                            viewModel.copyToClipboard()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Save") {
                            viewModel.saveImage()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .frame(width: 200)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))

                    // Main content area with image
                    if let image = viewModel.image {
                        GeometryReader { geo in
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        }
                    } else {
                        VStack {
                            Spacer()
                            Text("No image")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }

                // Bottom toolbar
                HStack(spacing: 12) {
                    Button("Copy") {
                        viewModel.copyToClipboard()
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        viewModel.saveImage()
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .help("Save")

                    Button("Save As...") {
                        viewModel.saveImageAs()
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 800, minHeight: 600)
        }
    }

    #Preview {
        EditorView(viewModel: EditorViewModel())
    }

#endif
