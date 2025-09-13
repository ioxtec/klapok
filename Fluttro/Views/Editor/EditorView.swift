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
            HStack(spacing: 0) {
                // Left area with toolbars and preview
                VStack(spacing: 0) {
                    // Top toolbar
                    HStack(spacing: 12) {
                        // Navigation arrows
                        Button(action: {
                            // TODO: Previous image
                        }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .help("Previous")

                        Button(action: {
                            // TODO: Next image
                        }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.bordered)
                        .help("Next")

                        Spacer()

                        // Text tools
                        Button(action: {
                            // TODO: Add text
                        }) {
                            Image(systemName: "textformat")
                        }
                        .buttonStyle(.bordered)
                        .help("Add Text")

                        Button(action: {
                            // TODO: Add arrow
                        }) {
                            Image(systemName: "arrow.up.right")
                        }
                        .buttonStyle(.bordered)
                        .help("Add Arrow")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))

                    // Image preview area
                    GeometryReader { geometry in
                        if let image = viewModel.image {
                            // Background with gradient
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .ignoresSafeArea()

                            // Centered image with shadow - NO SCALING, original size only
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()

                                    // Use image.size directly - SwiftUI handles logical/physical pixel conversion
                                    let imageSize = image.size
                                    let availableWidth = geometry.size.width - 80  // 40px padding on each side
                                    let availableHeight = geometry.size.height - 80  // 40px padding on each side

                                    // Only scale down if image is too big for available space
                                    let scaleX =
                                        imageSize.width > availableWidth
                                        ? availableWidth / imageSize.width : 1.0
                                    let scaleY =
                                        imageSize.height > availableHeight
                                        ? availableHeight / imageSize.height : 1.0
                                    let scale = min(scaleX, scaleY, 1.0)  // Never scale up, only down if needed

                                    let finalWidth = imageSize.width * scale
                                    let finalHeight = imageSize.height * scale

                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.none)  // Disable interpolation for sharper pixels
                                        .frame(width: finalWidth, height: finalHeight)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

                                    Spacer()
                                }
                                Spacer()
                            }
                        } else {
                            // No image state
                            VStack {
                                Spacer()
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("No image")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        }
                    }

                    // Bottom toolbar
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.copyToClipboard()
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .help("Copy to Clipboard")

                        Button(action: {
                            viewModel.saveImage()
                        }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .help("Save")

                        Button(action: {
                            viewModel.saveImageAs()
                        }) {
                            Image(systemName: "square.and.arrow.down.on.square")
                        }
                        .buttonStyle(.bordered)
                        .help("Save As...")

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                }

                // Right sidebar
                VStack(alignment: .leading, spacing: 16) {
                    Text("Properties")
                        .font(.headline)
                        .padding(.bottom, 8)

                    // Image info section
                    if let image = viewModel.image {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Image Size")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("\(Int(image.size.width)) × \(Int(image.size.height)) px")
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                        }
                        .padding(.bottom, 8)
                    }

                    // Background options
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8
                        ) {
                            // Background color options
                            ForEach(backgroundColors, id: \.self) { color in
                                Rectangle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    Spacer()
                }
                .frame(width: 250)
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(minWidth: 1000, minHeight: 700)
        }

        // Background color options
        private var backgroundColors: [Color] {
            [
                .clear,
                .white,
                .black,
                .blue,
                .green,
                .red,
                .purple,
                .orange,
                .yellow,
            ]
        }
    }

    #Preview {
        EditorView(viewModel: EditorViewModel())
    }

#endif
