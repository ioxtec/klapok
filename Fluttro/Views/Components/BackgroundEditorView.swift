//
//  BackgroundEditorView.swift
//  Fluttro
//
//  Background editor with gradient and image options
//

import SwiftUI
import AppKit

struct BackgroundEditorView: View {
    @ObservedObject var backgroundManager: BackgroundManager
    @State private var showingGradientEditor = false
    @State private var showingImageImporter = false
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: Any?
    @State private var deleteItemType: DeleteItemType?
    
    enum DeleteItemType {
        case gradient(UUID)
        case image(UUID)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fill")
                    .font(.callout)

                Picker("", selection: Binding(
                    get: { backgroundManager.collections.backgroundType },
                    set: { newType in
                        backgroundManager.collections.backgroundType = newType
                        // Save asynchronously to avoid publishing during view updates.
                        DispatchQueue.main.async {
                            backgroundManager.saveCollections()
                        }
                    }
                )) {
                    ForEach(BackgroundType.allCases, id: \.id) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            if backgroundManager.collections.backgroundType == .gradient {
                gradientSection
            }
            
            if backgroundManager.collections.backgroundType == .image {
                imageSection
            }

            if backgroundManager.collections.backgroundType == .none {
                BackgroundPanelHint("The screenshot is exported without a decorative background.")
            }
        }
        .sheet(isPresented: $showingGradientEditor) {
            GradientEditorView(backgroundManager: backgroundManager)
        }
        .sheet(isPresented: $showingImageImporter) {
            ImageImporterView(backgroundManager: backgroundManager)
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
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
        VStack(alignment: .leading, spacing: 12) {
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
                            itemToDelete = gradient
                            deleteItemType = .gradient(gradient.id)
                            showingDeleteAlert = true
                        }
                    )
                }
            }

            if backgroundManager.collections.customGradients.isEmpty {
                BackgroundPanelHint("Add a gradient to use this background type.")
            }
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackgroundAssetHeader(
                title: "Images",
                buttonHelp: "Add new background image",
                action: { showingImageImporter = true }
            )
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(backgroundManager.collections.backgroundImages) { image in
                    ImageThumbnailView(
                        backgroundImage: image,
                        isSelected: backgroundManager.collections.selectedImageId == image.id,
                        onSelect: {
                            backgroundManager.selectImage(withId: image.id)
                        },
                        onLongPress: {
                            itemToDelete = image
                            deleteItemType = .image(image.id)
                            showingDeleteAlert = true
                        }
                    )
                }
            }

            if backgroundManager.collections.backgroundImages.isEmpty {
                BackgroundPanelHint("Add an image to use this background type.")
            }

            if let selectedImage = backgroundManager.collections.selectedImage {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected image")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    BackgroundSliderControl(
                        title: "Image opacity",
                        valueText: "\(Int(selectedImage.opacity * 100))%",
                        value: Binding(
                            get: { selectedImage.opacity },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.opacity = newValue
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        ),
                        range: 0.1...1.0,
                        step: 0.1
                    )

                    HStack(alignment: .firstTextBaseline) {
                        Text("Image scale")
                            .font(.callout)

                        Spacer()

                        Picker("", selection: Binding(
                            get: { selectedImage.scaleMode },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.scaleMode = newValue
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        )) {
                            ForEach(BackgroundScaleMode.allCases, id: \.id) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 104)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Background Panel Controls

private struct BackgroundAssetHeader: View {
    let title: String
    let buttonHelp: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(buttonHelp)
        }
    }
}

private struct BackgroundSliderControl: View {
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

private struct BackgroundPanelHint: View {
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
    let onSelect: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Group {
                if let image = backgroundImage.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(
                Text(backgroundImage.name)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1)
                    .padding(4),
                alignment: .bottomLeading
            )
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
    }
}

#Preview {
    BackgroundEditorView(backgroundManager: BackgroundManager(forPreview: true))
        .frame(width: 300, height: 400)
        .padding()
}
