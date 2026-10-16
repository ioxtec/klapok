//
//  BackgroundEditorView.swift
//  Klapok
//
//  Background editor with gradient and image options
//

import SwiftUI
import AppKit

@MainActor
private final class BackgroundEditorViewState: ObservableObject {
    @Published var showingGradientEditor = false
    @Published var showingImageImporter = false
    @Published var showingImageLibrary = false
    @Published var showingDeleteAlert = false
    @Published var deleteItemType: BackgroundEditorView.DeleteItemType?
}

struct BackgroundEditorView: View {
    @ObservedObject var backgroundManager: BackgroundManager
    var onBackgroundTypeSelected: (BackgroundType, BackgroundType) -> Void = { _, _ in }
    @StateObject private var viewState = BackgroundEditorViewState()
    
    enum DeleteItemType {
        case gradient(UUID)
        case image(UUID)
    }

    private var showingGradientEditor: Bool {
        get { viewState.showingGradientEditor }
        nonmutating set { viewState.showingGradientEditor = newValue }
    }

    private var showingImageImporter: Bool {
        get { viewState.showingImageImporter }
        nonmutating set { viewState.showingImageImporter = newValue }
    }

    private var showingImageLibrary: Bool {
        get { viewState.showingImageLibrary }
        nonmutating set { viewState.showingImageLibrary = newValue }
    }

    private var showingDeleteAlert: Bool {
        get { viewState.showingDeleteAlert }
        nonmutating set { viewState.showingDeleteAlert = newValue }
    }

    private var deleteItemType: DeleteItemType? {
        get { viewState.deleteItemType }
        nonmutating set { viewState.deleteItemType = newValue }
    }

    private var showingGradientEditorBinding: Binding<Bool> {
        Binding(get: { showingGradientEditor }, set: { showingGradientEditor = $0 })
    }

    private var showingImageImporterBinding: Binding<Bool> {
        Binding(get: { showingImageImporter }, set: { showingImageImporter = $0 })
    }

    private var showingImageLibraryBinding: Binding<Bool> {
        Binding(get: { showingImageLibrary }, set: { showingImageLibrary = $0 })
    }

    private var showingDeleteAlertBinding: Binding<Bool> {
        Binding(get: { showingDeleteAlert }, set: { showingDeleteAlert = $0 })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
                Picker("Fill", selection: Binding(
                    get: { backgroundManager.collections.backgroundType },
                    set: { newType in
                        onBackgroundTypeSelected(backgroundManager.collections.backgroundType, newType)
                        backgroundManager.setBackgroundType(newType)
                        backgroundManager.saveCollections()
                    }
                )) {
                    ForEach(BackgroundType.allCases, id: \.id) { type in
                        Text(type.displayName.localized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("editor.backgroundType")
            
            if backgroundManager.collections.backgroundType == .gradient {
                SidebarDivider()
                gradientSection
            }
            
            if backgroundManager.collections.backgroundType == .image {
                SidebarDivider()
                imageSection
            }

            if backgroundManager.collections.backgroundType == .none {
                SidebarDivider()
                SidebarHintText("The screenshot is exported without a decorative background.")
            }
        }
        .sheet(isPresented: showingGradientEditorBinding) {
            GradientEditorView(backgroundManager: backgroundManager)
        }
        .sheet(isPresented: showingImageImporterBinding) {
            ImageImporterView(backgroundManager: backgroundManager)
        }
        .alert("Delete Item", isPresented: showingDeleteAlertBinding) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let itemType = deleteItemType {
                    switch itemType {
                    case .gradient(let id):
                        backgroundManager.deleteCustomGradient(withId: id)
                    case .image(let id):
                        backgroundManager.deleteBackgroundImage(withId: id)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
    
    // MARK: - Gradient Section
    
    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            BackgroundAssetHeader(
                title: "Gradient presets",
                buttonHelp: "Add new gradient",
                action: { showingGradientEditor = true }
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(backgroundManager.collections.customGradients) { gradient in
                    GradientThumbnailView(
                        gradient: gradient,
                        isSelected: backgroundManager.collections.selectedGradientId == gradient.id,
                        onSelect: {
                            backgroundManager.selectGradient(withId: gradient.id)
                        },
                        onLongPress: {
                            deleteItemType = .gradient(gradient.id)
                            showingDeleteAlert = true
                        }
                    )
                }
            }

            if backgroundManager.collections.customGradients.isEmpty {
                SidebarHintText("Add a gradient to use this background type.")
            }
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            BackgroundAssetHeader(
                title: "Images",
                buttonHelp: "Add new background image",
                action: { showingImageImporter = true }
            )

            if backgroundManager.collections.backgroundImages.isEmpty {
                SidebarHintText("Add an image to use this background type.")
            } else {
                BackgroundImageStrip(
                    images: backgroundManager.collections.backgroundImages,
                    selectedImageId: backgroundManager.collections.selectedImageId,
                    isLibraryPresented: showingImageLibraryBinding,
                    onSelect: { image in
                        backgroundManager.selectImage(withId: image.id)
                    },
                    onDelete: { image in
                        deleteItemType = .image(image.id)
                        showingDeleteAlert = true
                    }
                )
            }

            if let selectedImage = backgroundManager.collections.selectedImage {
                SidebarDivider()

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .center) {
                        SidebarSubheading("Selected image")

                        Spacer()

                        Button(role: .destructive) {
                            requestDeleteImage(selectedImage)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .foregroundStyle(.secondary)
                        .help("Delete selected image")
                    }

                    SidebarControlRow(title: "Name", systemImage: "textformat") {
                        TextField("", text: Binding(
                            get: { selectedImage.name },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.name = newValue
                                updatedImage.modifiedAt = Date()
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(SidebarStyle.bodyFont)
                        .controlSize(.small)
                        .frame(width: 132)
                    }

                    SidebarDivider()

                    SidebarSliderControl(
                        title: "Image opacity",
                        valueText: "\(Int(selectedImage.opacity * 100))%",
                        systemImage: "circle.lefthalf.filled",
                        value: Binding(
                            get: { selectedImage.opacity },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.opacity = newValue
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        ),
                        range: 0.1...1.0,
                        step: 0.1, unit: "%", displayMultiplier: 100
                    )

                    SidebarDivider()

                    SidebarSliderControl(
                        title: "Background blur".localized,
                        valueText: "\(Int(selectedImage.blurRadius)) px",
                        systemImage: "drop.halffull",
                        value: Binding(
                            get: { selectedImage.blurRadius },
                            set: { radius in
                                var updatedImage = selectedImage
                                updatedImage.blurRadius = radius
                                updatedImage.modifiedAt = Date()
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        ),
                        range: BackgroundImageBlur.range, step: 1, unit: "px"
                    )

                    SidebarDivider()

                    SidebarControlRow(title: "Image scale", systemImage: "arrow.up.left.and.arrow.down.right") {
                        Picker("", selection: Binding(
                            get: { selectedImage.scaleMode },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.scaleMode = newValue
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        )) {
                            ForEach(BackgroundScaleMode.allCases, id: \.id) { mode in
                                Text(mode.displayName.localized).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 104)
                    }
                }
            }
        }
    }

    private func requestDeleteImage(_ image: BackgroundImage) {
        deleteItemType = .image(image.id)
        showingDeleteAlert = true
    }
}

private struct BackgroundImageStrip: View {
    let images: [BackgroundImage]
    let selectedImageId: UUID?
    @Binding var isLibraryPresented: Bool
    let onSelect: (BackgroundImage) -> Void
    let onDelete: (BackgroundImage) -> Void

    private let visibleCount = 3
    private let thumbnailSize = CGSize(width: 58, height: 46)

    private var visibleImages: [BackgroundImage] {
        Array(images.prefix(visibleCount))
    }

    private var showsLibraryButton: Bool {
        images.count > visibleCount
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(visibleImages) { image in
                ImageThumbnailView(
                    backgroundImage: image,
                    isSelected: selectedImageId == image.id,
                    size: thumbnailSize,
                    onSelect: {
                        onSelect(image)
                    },
                    onLongPress: {
                        onDelete(image)
                    }
                )
            }

            if showsLibraryButton {
                Button {
                    isLibraryPresented.toggle()
                } label: {
                    SidebarChevronButtonLabel(height: thumbnailSize.height)
                }
                .buttonStyle(.plain)
                .help("Show all background images")
                .popover(isPresented: $isLibraryPresented, arrowEdge: .trailing) {
                    BackgroundImageLibraryPopover(
                        images: images,
                        selectedImageId: selectedImageId,
                        onSelect: { image in
                            onSelect(image)
                            isLibraryPresented = false
                        },
                        onDelete: onDelete
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

private struct BackgroundImageLibraryPopover: View {
    let images: [BackgroundImage]
    let selectedImageId: UUID?
    let onSelect: (BackgroundImage) -> Void
    let onDelete: (BackgroundImage) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var popoverHeight: CGFloat {
        let rowCount = CGFloat((images.count + 2) / 3)
        return min(286, max(132, 52 + rowCount * 62))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Images")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("\(images.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .opacity(0.55)

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(images) { image in
                        ImageThumbnailView(
                            backgroundImage: image,
                            isSelected: selectedImageId == image.id,
                            fillsWidth: true,
                            size: CGSize(width: 0, height: 54),
                            onSelect: {
                                onSelect(image)
                            },
                            onLongPress: {
                                onDelete(image)
                            }
                        )
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(12)
        .frame(width: 320, height: popoverHeight)
    }
}

// MARK: - Background Panel Controls

private struct BackgroundAssetHeader: View {
    let title: String
    let buttonHelp: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            SidebarSubheading(title)

            Spacer()

            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(buttonHelp.localized)
        }
    }
}

// MARK: - Gradient Thumbnail View

struct GradientThumbnailView: View {
    let gradient: CustomGradient
    let isSelected: Bool
    let onSelect: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    gradient: Gradient(stops: gradient.gradientStops),
                    startPoint: gradient.direction.startPoint,
                    endPoint: gradient.direction.endPoint
                ))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .overlay(
                    Text(gradient.name)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1)
                        .padding(4)
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Gradient", role: .destructive) {
                onLongPress()
            }
        }
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Image Thumbnail View

struct ImageThumbnailView: View {
    let backgroundImage: BackgroundImage
    let isSelected: Bool
    let fillsWidth: Bool
    let size: CGSize
    let onSelect: () -> Void
    let onLongPress: () -> Void
    @StateObject private var hoverState = ImageThumbnailHoverState()

    private var isHovering: Bool {
        get { hoverState.isHovering }
        nonmutating set { hoverState.isHovering = newValue }
    }

    private var showsPreview: Bool {
        get { hoverState.showsPreview }
        nonmutating set { hoverState.showsPreview = newValue }
    }

    private var previewTask: Task<Void, Never>? {
        get { hoverState.previewTask }
        nonmutating set { hoverState.previewTask = newValue }
    }

    private var showsPreviewBinding: Binding<Bool> {
        Binding(get: { showsPreview }, set: { showsPreview = $0 })
    }

    init(
        backgroundImage: BackgroundImage,
        isSelected: Bool,
        fillsWidth: Bool = false,
        size: CGSize = CGSize(width: 58, height: 46),
        onSelect: @escaping () -> Void,
        onLongPress: @escaping () -> Void
    ) {
        self.backgroundImage = backgroundImage
        self.isSelected = isSelected
        self.fillsWidth = fillsWidth
        self.size = size
        self.onSelect = onSelect
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .bottomLeading) {
                if let image = backgroundImage.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.48)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Text(backgroundImage.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .shadow(color: .black.opacity(0.75), radius: 1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
            }
            .frame(width: fillsWidth ? nil : size.width, height: size.height)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white, Color.accentColor)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete Image", role: .destructive) {
                onLongPress()
            }
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onHover { hovering in
            isHovering = hovering
            previewTask?.cancel()

            if hovering {
                previewTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(240))
                    if !Task.isCancelled, isHovering {
                        showsPreview = true
                    }
                }
            } else {
                showsPreview = false
            }
        }
        .popover(isPresented: showsPreviewBinding, arrowEdge: .trailing) {
            ImageThumbnailPreview(backgroundImage: backgroundImage)
        }
    }
}

@MainActor
private final class ImageThumbnailHoverState: ObservableObject {
    @Published var isHovering = false
    @Published var showsPreview = false
    @Published var previewTask: Task<Void, Never>?
}

private struct ImageThumbnailPreview: View {
    let backgroundImage: BackgroundImage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            previewImage

            VStack(alignment: .leading, spacing: 6) {
                Text(backgroundImage.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    previewMetric(
                        icon: "circle.lefthalf.filled",
                        text: "\(Int(backgroundImage.opacity * 100))%"
                    )

                    previewMetric(
                        icon: "arrow.up.left.and.arrow.down.right",
                        text: backgroundImage.scaleMode.displayName
                    )
                }
            }
        }
        .padding(12)
        .frame(width: 242)
    }

    @ViewBuilder
    private var previewImage: some View {
        if let image = backgroundImage.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 218, height: 132)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.7)
                }
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .frame(width: 218, height: 132)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func previewMetric(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            }
    }
}
