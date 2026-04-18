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
        @StateObject private var profileManager = ProfileManager.shared
        @ObservedObject private var backgroundManager = BackgroundManager.shared

        var body: some View {
            NavigationSplitView {
                EditorSidebarView(
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
                EditorCommandToolbar(
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

    private struct EditorCommandToolbar: ToolbarContent {
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

    // MARK: - Sidebar

    private struct EditorSidebarView: View {
        @ObservedObject var viewModel: EditorViewModel
        @ObservedObject var profileManager: ProfileManager
        @ObservedObject var backgroundManager: BackgroundManager

        var body: some View {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    SidebarDisclosureSection(
                        id: "image.profiles",
                        title: "Profiles",
                        systemImage: "slider.horizontal.3",
                        subtitle: "Presets for canvas size, spacing, corners, and shadow."
                    ) {
                        profileControl
                    }

                    SidebarDisclosureSection(
                        id: "image.background",
                        title: "Background",
                        systemImage: "paintpalette",
                        subtitle: "Fill behind the screenshot."
                    ) {
                        BackgroundEditorView(backgroundManager: backgroundManager)
                    }

                    SidebarDisclosureSection(
                        id: "image.canvas",
                        title: "Canvas",
                        systemImage: "rectangle.dashed",
                        subtitle: "Outer frame, aspect ratio, and spacing."
                    ) {
                        if backgroundManager.collections.backgroundType == .none {
                            SidebarHintText("Turn on Gradient or Image to edit canvas settings.")
                        } else {
                            SidebarAspectRatioGrid(selectedRatio: $viewModel.selectedAspectRatio)

                            SidebarSliderControl(
                                title: "Outer padding",
                                valueText: "\(Int(viewModel.backgroundPadding)) px",
                                value: $viewModel.backgroundPadding,
                                range: 10...100,
                                step: 5
                            )

                            SidebarSliderControl(
                                title: "Canvas corner radius",
                                valueText: "\(Int(viewModel.backgroundCornerRadius)) px",
                                value: $viewModel.backgroundCornerRadius,
                                range: 0...50,
                                step: 1
                            )
                        }
                    }

                    SidebarDisclosureSection(
                        id: "image.screenshot",
                        title: "Screenshot",
                        systemImage: "photo",
                        subtitle: "Source image corners and shadow."
                    ) {
                        if let image = viewModel.image {
                            let sourceSize = image.pixelSize
                            let outputSize = viewModel.calculateOutputSize(for: image)

                            SidebarValueRow(
                                title: "Source size",
                                value: "\(Int(sourceSize.width)) x \(Int(sourceSize.height)) px"
                            )

                            SidebarValueRow(
                                title: "Output size",
                                value: "\(Int(outputSize.width)) x \(Int(outputSize.height)) px"
                            )
                        }

                        Toggle("Round screenshot corners", isOn: $viewModel.enableRoundedCorners)
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        if viewModel.enableRoundedCorners {
                            SidebarSliderControl(
                                title: "Screenshot corner radius",
                                valueText: "\(Int(viewModel.cornerRadius)) px",
                                value: $viewModel.cornerRadius,
                                range: 0...50,
                                step: 1
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        SidebarSliderControl(
                            title: "Screenshot shadow",
                            valueText: "\(Int(viewModel.shadowIntensity))%",
                            value: $viewModel.shadowIntensity,
                            range: 0...50,
                            step: 1
                        )
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.enableRoundedCorners)
                }
                .padding(.leading, 16)
                .padding(.trailing, 24)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.visible)
            .frame(width: 300)
            .background(Color(NSColor.windowBackgroundColor))
        }

        private var profileControl: some View {
            ProfileControlView<ImageEditingProfile>(
                profileManager: profileManager,
                profiles: profileManager.imageProfiles.profiles,
                activeProfile: profileManager.getActiveImageProfile(),
                profileTypeName: "Image",
                showsHeader: false,
                usesContainer: false,
                onProfileSelected: { profile in
                    profileManager.applyImageProfile(profile, to: viewModel)
                },
                onProfileAdded: { name in
                    let newProfile = profileManager.createImageProfileFromCurrentSettings(
                        name: name,
                        from: viewModel
                    )
                    profileManager.setActiveImageProfile(newProfile)
                },
                onProfileEdited: updateProfile,
                onProfileDeleted: { profile in
                    profileManager.removeImageProfile(withId: profile.id)
                },
                onImportProfiles: {
                    _ = profileManager.importImageProfiles()
                },
                onExportProfiles: {
                    _ = profileManager.exportImageProfiles()
                },
                onResetProfiles: {
                    profileManager.resetImageProfilesToDefaults()
                }
            )
        }

        private func updateProfile(_ profile: ImageEditingProfile, newName: String) {
            if newName == profile.name {
                let updatedProfile = ImageEditingProfile(
                    id: profile.id,
                    name: profile.name,
                    isDefault: profile.isDefault,
                    createdAt: profile.createdAt,
                    modifiedAt: Date(),
                    backgroundAspectRatio: viewModel.selectedAspectRatio,
                    backgroundPadding: viewModel.backgroundPadding,
                    backgroundCornerRadius: viewModel.backgroundCornerRadius,
                    shadowIntensity: viewModel.shadowIntensity
                )
                profileManager.updateImageProfile(updatedProfile)
            } else {
                var updatedProfile = profile
                updatedProfile.name = newName
                updatedProfile.modifiedAt = Date()
                profileManager.updateImageProfile(updatedProfile)
            }
        }
    }

    private struct SidebarAspectRatioGrid: View {
        @Binding var selectedRatio: BackgroundAspectRatio

        private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Aspect ratio")
                    .font(.callout)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(BackgroundAspectRatio.allCases, id: \.id) { ratio in
                        Button {
                            selectedRatio = ratio
                        } label: {
                            Text(ratio.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selectedRatio == ratio ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            selectedRatio == ratio
                                                ? Color.accentColor
                                                : Color(NSColor.controlBackgroundColor)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private struct SidebarSliderControl: View {
        let title: String
        let valueText: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        let step: Double

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.callout)

                    Spacer()

                    Text(valueText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $value, in: range, step: step)
            }
        }
    }

    private struct SidebarValueRow: View {
        let title: String
        let value: String

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.callout)

                Spacer()

                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private struct SidebarHintText: View {
        let text: String

        init(_ text: String) {
            self.text = text
        }

        var body: some View {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    #Preview {
        EditorView(viewModel: EditorViewModel())
    }

#endif
