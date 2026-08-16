//
//  ScreenshotEditorView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
    import AppKit

    struct ScreenshotEditorView: View {
        @ObservedObject var viewModel: EditorViewModel
        @StateObject private var settings = AppSettings.shared
        @StateObject private var profileManager = ProfileManager.shared
        @ObservedObject private var backgroundManager = BackgroundManager.shared

        var body: some View {
            NavigationSplitView {
                ScreenshotEditorSidebarView(
                    viewModel: viewModel,
                    profileManager: profileManager,
                    backgroundManager: backgroundManager
                )
                .navigationSplitViewColumnWidth(300)
            } detail: {
                // Right side - preview area
                VStack(spacing: 0) {
                    // Top toolbar
                    HStack(spacing: 0) {
                        // Drawing tools on the left
                        AnnotationToolPickerView(annotationManager: viewModel.annotationManager)
                        .padding(.leading, 12)
                        
                        Divider()
                            .frame(height: 24)
                            .padding(.horizontal, 12)
                        
                        // Context-sensitive properties menu
                        AnnotationToolbarPropertiesView(annotationManager: viewModel.annotationManager)
                        
                        Spacer()
                    }
                    .frame(height: 48)
                    .background(Color(NSColor.controlBackgroundColor))

                    // Preview area
                    if let image = viewModel.image {
                        GeometryReader { geometry in
                            let availableSize = geometry.size
                            let imageSize = image.pixelSize
                            
                            // Calculate background size based on aspect ratio and padding
                            let backgroundSize = viewModel.calculateBackgroundSize(for: imageSize, in: availableSize)
                            
                            // Calculate image scale - only scale down if image doesn't fit
                            let imagePadding = viewModel.backgroundPadding
                            let maxImageWidth = max(1, backgroundSize.width - (imagePadding * 2))
                            let maxImageHeight = max(1, backgroundSize.height - (imagePadding * 2))
                            
                            // Only scale down if image is larger than available space
                            let scaleX = imageSize.width > maxImageWidth ? maxImageWidth / imageSize.width : 1.0
                            let scaleY = imageSize.height > maxImageHeight ? maxImageHeight / imageSize.height : 1.0
                            let scale = min(scaleX, scaleY) // Remove the 1.0 limit - we want to scale down when needed
                            
                            let finalImageWidth = max(1, imageSize.width * scale)
                            let finalImageHeight = max(1, imageSize.height * scale)

                            let directScaleX = imageSize.width > availableSize.width ? availableSize.width / imageSize.width : 1.0
                            let directScaleY = imageSize.height > availableSize.height ? availableSize.height / imageSize.height : 1.0
                            let directScale = min(directScaleX, directScaleY)
                            let directImageWidth = max(1, imageSize.width * directScale)
                            let directImageHeight = max(1, imageSize.height * directScale)
                            
                            // Validate dimensions to prevent invalid frames
                            let validBackgroundSize = CGSize(
                                width: max(1, backgroundSize.width),
                                height: max(1, backgroundSize.height)
                            )
                            
                            ZStack {
                                // Neutral background for preview area
                                Color(NSColor.controlBackgroundColor)
                                    .ignoresSafeArea()
                                
                                if backgroundManager.collections.backgroundType != .none {
                                    // Background canvas with aspect ratio
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            
                                            // Background canvas
                                            ZStack {
                                                // Background fill
                                                ZStack {
                                                    backgroundFill(for: backgroundManager)
                                                }
                                                .frame(width: validBackgroundSize.width, height: validBackgroundSize.height)
                                                .clipShape(RoundedRectangle(cornerRadius: viewModel.backgroundCornerRadius))
                                                
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
                                                
                                                // Drawing canvas overlay for annotations
                                                DrawingCanvasView(
                                                    annotationManager: viewModel.annotationManager,
                                                    canvasSize: CGSize(width: finalImageWidth, height: finalImageHeight),
                                                    sourceImageSize: imageSize
                                                )
                                            }
                                            
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                } else {
                                    // No background - show original image only
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            
                                            // Original image without background
                                            ZStack {
                                                Image(nsImage: image)
                                                    .resizable()
                                                    .interpolation(.none)
                                                    .frame(width: directImageWidth, height: directImageHeight)
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
                                                
                                                // Drawing canvas overlay for annotations
                                                DrawingCanvasView(
                                                    annotationManager: viewModel.annotationManager,
                                                    canvasSize: CGSize(width: directImageWidth, height: directImageHeight),
                                                    sourceImageSize: imageSize
                                                )
                                            }
                                            
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                }
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
            }
            .toolbar {
                ScreenshotEditorCommandToolbar(
                    viewModel: viewModel,
                    annotationManager: viewModel.annotationManager
                )
            }
            .frame(minWidth: 1180, minHeight: 720)
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

    // MARK: - Background Views
    
    @ViewBuilder
    private func backgroundFill(for backgroundManager: BackgroundManager) -> some View {
        let backgroundType = backgroundManager.collections.backgroundType
        
        switch backgroundType {
        case .gradient:
            if let selectedGradient = backgroundManager.collections.selectedGradient {
                LinearGradient(
                    gradient: Gradient(stops: selectedGradient.gradientStops),
                    startPoint: selectedGradient.direction.startPoint,
                    endPoint: selectedGradient.direction.endPoint
                )
            } else {
                Color.gray.opacity(0.1)
            }
            
        case .image:
            if let selectedImage = backgroundManager.collections.selectedImage,
               let image = selectedImage.image {
                BackgroundImageFillView(
                    image: image,
                    scaleMode: selectedImage.scaleMode,
                    opacity: selectedImage.opacity
                )
            } else {
                Color.gray.opacity(0.1)
            }
            
        case .none:
            Color.clear
        }
    }

    private struct BackgroundImageFillView: View {
        let image: NSImage
        let scaleMode: BackgroundScaleMode
        let opacity: Double

        var body: some View {
            GeometryReader { geometry in
                let size = geometry.size

                switch scaleMode {
                case .fit:
                    centeredImage(in: size, contentMode: .fit)

                case .fill:
                    centeredImage(in: size, contentMode: .fill)
                        .clipped()

                case .stretch:
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .opacity(opacity)

                case .tile:
                    Image(nsImage: image)
                        .resizable(resizingMode: .tile)
                        .frame(width: size.width, height: size.height)
                        .opacity(opacity)
                        .clipped()

                case .center:
                    Image(nsImage: image)
                        .frame(width: image.size.width, height: image.size.height)
                        .position(x: size.width / 2, y: size.height / 2)
                        .opacity(opacity)
                        .clipped()
                }
            }
        }

        private func centeredImage(in size: CGSize, contentMode: ContentMode) -> some View {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .frame(width: size.width, height: size.height)
                .opacity(opacity)
        }
    }

    // MARK: - Annotation Toolbar

    private struct AnnotationToolPickerView: View {
        @ObservedObject var annotationManager: AnnotationManager
        @Environment(\.colorScheme) private var colorScheme

        private let tools: [DrawingTool] = [
            .text,
            .arrow,
            .rectangle,
            .circle,
            .line,
            .freeDraw,
        ]

        var body: some View {
            HStack(spacing: 4) {
                ForEach(tools, id: \.displayName) { tool in
                    ToolButton(
                        tool: tool,
                        currentTool: annotationManager.currentTool,
                        selectedAnnotationType: annotationManager.selectedAnnotation?.type,
                        action: { annotationManager.selectTool(tool) }
                    )
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private struct ScreenshotEditorCommandToolbar: ToolbarContent {
        @ObservedObject var viewModel: EditorViewModel
        @ObservedObject var annotationManager: AnnotationManager

        var body: some ToolbarContent {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    annotationManager.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!annotationManager.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo")

                Button {
                    annotationManager.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!annotationManager.canRedo)
                .keyboardShortcut("Z", modifiers: [.command, .shift])
                .help("Redo")

                Button {
                    annotationManager.clearAllAnnotations()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(!annotationManager.hasAnnotations)
                .help("Clear all annotations")

                Button {
                    viewModel.copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Copy to Clipboard")

                Button {
                    viewModel.saveImageAs()
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
                .help("Save As...")

                Button {
                    viewModel.saveImage()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .help("Save")
            }
        }
    }

#endif
