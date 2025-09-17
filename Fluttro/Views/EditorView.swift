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
                            let imageSize = image.size
                            let availableSize = geometry.size
                            
                            // Calculate background size based on aspect ratio and padding
                            let backgroundSize = viewModel.calculateBackgroundSize(for: imageSize, in: availableSize)
                            
                            // Calculate image scale - only scale down if image doesn't fit
                            let imagePadding = viewModel.backgroundPadding
                            let maxImageWidth = backgroundSize.width - (imagePadding * 2)
                            let maxImageHeight = backgroundSize.height - (imagePadding * 2)
                            
                            // Only scale down if image is larger than available space
                            let scaleX = imageSize.width > maxImageWidth ? maxImageWidth / imageSize.width : 1.0
                            let scaleY = imageSize.height > maxImageHeight ? maxImageHeight / imageSize.height : 1.0
                            let scale = min(scaleX, scaleY) // Remove the 1.0 limit - we want to scale down when needed
                            
                            let finalImageWidth = imageSize.width * scale
                            let finalImageHeight = imageSize.height * scale
                            
                            ZStack {
                                // Background with gradient
                                LinearGradient(
                                    colors: viewModel.backgroundGradient.colors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .ignoresSafeArea()
                                
                                // Background canvas with aspect ratio
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        
                                        // Background canvas
                                        RoundedRectangle(cornerRadius: viewModel.backgroundCornerRadius)
                                            .fill(LinearGradient(
                                                colors: viewModel.backgroundGradient.colors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: backgroundSize.width, height: backgroundSize.height)
                                            .overlay(
                                                // Image centered within background with shadow
                                                Image(nsImage: image)
                                                    .resizable()
                                                    .interpolation(.none)
                                                    .frame(width: finalImageWidth, height: finalImageHeight)
                                                    .background(viewModel.selectedBackgroundColor)
                                                    .clipShape(
                                                        RoundedRectangle(
                                                            cornerRadius: viewModel.enableRoundedCorners
                                                                ? viewModel.cornerRadius : 0
                                                        )
                                                    )
                                                    .shadow(
                                                        color: .black.opacity(viewModel.shadowIntensity / 100.0), 
                                                        radius: viewModel.shadowIntensity, 
                                                        x: 0, 
                                                        y: viewModel.shadowIntensity / 2
                                                    )
                                            )
                                        
                                        Spacer()
                                    }
                                    Spacer()
                                }
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
                ScrollView {
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

                    // Corner Radius Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Corner Radius")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Rounded Corners", isOn: $viewModel.enableRoundedCorners)
                            .toggleStyle(.switch)

                        if viewModel.enableRoundedCorners {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Radius:")
                                    Spacer()
                                    Text("\(Int(viewModel.cornerRadius)) px")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 12, design: .monospaced))
                                }

                                Slider(
                                    value: $viewModel.cornerRadius,
                                    in: 0...50,
                                    step: 1
                                )
                            }
                            .padding(.leading, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.enableRoundedCorners)
                    .padding(.bottom, 16)

                    // Aspect Ratio Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ratio / Size")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // Aspect ratio buttons
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(BackgroundAspectRatio.allCases, id: \.id) { ratio in
                                Button(action: {
                                    viewModel.selectedAspectRatio = ratio
                                }) {
                                    Text(ratio.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(viewModel.selectedAspectRatio == ratio ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(viewModel.selectedAspectRatio == ratio ? 
                                                      Color.accentColor : Color(NSColor.controlBackgroundColor))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                    
                    // Padding Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Padding")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Padding:")
                            Spacer()
                            Text("\(Int(viewModel.backgroundPadding)) px")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        Slider(
                            value: $viewModel.backgroundPadding,
                            in: 10...100,
                            step: 5
                        )
                    }
                    .padding(.bottom, 16)
                    
                    // Rounded Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rounded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Radius:")
                            Spacer()
                            Text("\(Int(viewModel.backgroundCornerRadius)) px")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        Slider(
                            value: $viewModel.backgroundCornerRadius,
                            in: 0...50,
                            step: 1
                        )
                    }
                    .padding(.bottom, 16)
                    
                    // Shadow Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shadow")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Intensity:")
                            Spacer()
                            Text("\(Int(viewModel.shadowIntensity))%")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12, design: .monospaced))
                        }
                        
                        Slider(
                            value: $viewModel.shadowIntensity,
                            in: 0...50,
                            step: 1
                        )
                    }
                    .padding(.bottom, 16)
                    
                    // Background Gradient Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Background")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8
                        ) {
                            // Background gradient options
                            ForEach(BackgroundGradient.allCases, id: \.id) { gradient in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        gradient == .none ? 
                                        LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: gradient.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                viewModel.backgroundGradient == gradient
                                                    ? Color.accentColor
                                                    : Color.primary.opacity(0.2),
                                                lineWidth: viewModel.backgroundGradient == gradient ? 2 : 1
                                            )
                                    )
                                    .onTapGesture {
                                        viewModel.backgroundGradient = gradient
                                    }
                            }
                        }
                        
                        // Legacy background colors (for image background)
                        Text("Image Background")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                        
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
                                            .stroke(
                                                viewModel.selectedBackgroundColor == color
                                                    ? Color.accentColor
                                                    : Color.primary.opacity(0.2),
                                                lineWidth: viewModel.selectedBackgroundColor
                                                    == color ? 2 : 1
                                            )
                                    )
                                    .onTapGesture {
                                        viewModel.selectedBackgroundColor = color
                                    }
                            }
                        }
                        }

                        Spacer()
                    }
                    .padding()
                }
                .frame(width: 250)
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
