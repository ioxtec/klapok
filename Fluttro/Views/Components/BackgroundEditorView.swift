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
        VStack(alignment: .leading, spacing: 16) {
            // Background Type Selector
            Picker("Type", selection: Binding(
                get: { backgroundManager.collections.backgroundType },
                set: { newType in
                    backgroundManager.collections.backgroundType = newType
                    // Save asynchronously to avoid publishing during view updates
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
            
            // Gradient Section
            if backgroundManager.collections.backgroundType == .gradient {
                gradientSection
            }
            
            // Image Section
            if backgroundManager.collections.backgroundType == .image {
                imageSection
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
            HStack {
                Text("Gradients")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    showingGradientEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Add new gradient")
            }
            
            // Gradient Grid
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
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Background Images")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    showingImageImporter = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Add new background image")
            }
            
            // Image Grid
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
            
            // Image Settings
            if let selectedImage = backgroundManager.collections.selectedImage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Slider(value: Binding(
                            get: { selectedImage.opacity },
                            set: { newValue in
                                var updatedImage = selectedImage
                                updatedImage.opacity = newValue
                                backgroundManager.updateBackgroundImage(updatedImage)
                            }
                        ), in: 0.1...1.0, step: 0.1)
                        .frame(width: 100)
                        Text("\(Int(selectedImage.opacity * 100))%")
                            .font(.caption)
                            .frame(width: 30)
                    }
                    
                    Picker("Scale Mode", selection: Binding(
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
                }
                .padding(.top, 8)
            }
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
                    colors: gradient.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
