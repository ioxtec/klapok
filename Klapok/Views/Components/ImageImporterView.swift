//
//  ImageImporterView.swift
//  Klapok
//
//  Image importer for background images
//

import SwiftUI
import AppKit

@MainActor
private final class ImageImporterViewState: ObservableObject {
    @Published var imageName = ""
    @Published var selectedImage: NSImage?
    @Published var opacity: Double = 1.0
    @Published var scaleMode: BackgroundScaleMode = .fit
}

struct ImageImporterView: View {
    @ObservedObject var backgroundManager: BackgroundManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewState = ImageImporterViewState()

    private var imageName: String {
        get { viewState.imageName }
        nonmutating set { viewState.imageName = newValue }
    }

    private var selectedImage: NSImage? {
        get { viewState.selectedImage }
        nonmutating set { viewState.selectedImage = newValue }
    }

    private var opacity: Double {
        get { viewState.opacity }
        nonmutating set { viewState.opacity = newValue }
    }

    private var scaleMode: BackgroundScaleMode {
        get { viewState.scaleMode }
        nonmutating set { viewState.scaleMode = newValue }
    }

    private var imageNameBinding: Binding<String> {
        Binding(get: { imageName }, set: { imageName = $0 })
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { opacity }, set: { opacity = $0 })
    }

    private var scaleModeBinding: Binding<BackgroundScaleMode> {
        Binding(get: { scaleMode }, set: { scaleMode = $0 })
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import Background Image")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Image Preview
            Group {
                if let image = selectedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 150)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("No image selected")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            
            // Image Selection Button
            Button("Select Image") {
                selectImage()
            }
            .buttonStyle(.bordered)
            
            // Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Image Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter image name", text: imageNameBinding)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Settings
            VStack(spacing: 16) {
                // Opacity Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(opacity * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: opacityBinding, in: 0.1...1.0, step: 0.1)
                }
                
                // Scale Mode Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scale Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Scale Mode", selection: scaleModeBinding) {
                        ForEach(BackgroundScaleMode.allCases, id: \.id) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Import Image") {
                    importImage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageName.isEmpty || selectedImage == nil)
            }
        }
        .padding(24)
        .frame(width: 400, height: 500)
        .centeredSheetWindow()
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        WindowPlacement.centerModalPanel(panel)
        
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                selectedImage = image
                if imageName.isEmpty {
                    imageName = url.deletingPathExtension().lastPathComponent
                }
            }
        }
    }
    
    private func importImage() {
        guard let image = selectedImage else { return }
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: .png, properties: [:]) else {
            Logger.e("ImageImporterView: Failed to convert image to PNG data")
            return
        }
        
        let backgroundImage = BackgroundImage(
            name: imageName,
            fileName: "\(UUID().uuidString).png",
            opacity: opacity,
            scaleMode: scaleMode
        )
        
        backgroundManager.addBackgroundImage(backgroundImage, imageData: imageData)
        backgroundManager.selectImage(withId: backgroundImage.id)
        dismiss()
    }
}
