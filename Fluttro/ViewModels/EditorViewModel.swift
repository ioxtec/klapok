//
//  EditorViewModel.swift
//  Fluttro
//
//  ViewModel for image editor
//

import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit

    final class EditorViewModel: ObservableObject {
        // MARK: - Published Properties

        @Published var image: NSImage?
        @Published var isPresented: Bool = false
        @Published var isCapturing: Bool = false

        // Editor properties
        @Published var enableRoundedCorners: Bool = false
        @Published var cornerRadius: Double = 12.0
        @Published var selectedBackgroundColor: Color = .clear
        
        // Background settings
        @Published var selectedAspectRatio: BackgroundAspectRatio = .auto
        @Published var backgroundPadding: Double = 30.0
        @Published var backgroundCornerRadius: Double = 20.0
        @Published var shadowIntensity: Double = 25.0
        
        // Annotation manager
        @Published var annotationManager = AnnotationManager()
        
        // Background manager
        private let backgroundManager = BackgroundManager.shared

        // MARK: - Dependencies

        @MainActor private let captureManager = CaptureManager.shared
        private let settings = AppSettings.shared

        // MARK: - Public Methods

        @MainActor
        func show(image: NSImage) {
            Logger.s("EditorViewModel: Showing editor with image size: \(image.size), pixel size: \(image.pixelSize)")
            annotationManager.resetForNewImage()
            self.image = image
            self.isPresented = true
            Logger.s("EditorViewModel: isPresented set to true")
        }

        @MainActor
        func close() {
            self.isPresented = false
            self.image = nil
            annotationManager.resetForNewImage()
        }

        @MainActor
        func saveImage() {
            guard image != nil else {
                Logger.w("EditorViewModel: No image to save")
                return
            }

            let compositeImage = renderCompositeImage()

            if let savedURL = settings.saveScreenshot(compositeImage) {
                Logger.s("EditorViewModel: Composite image saved to: \(savedURL.path)")
            } else {
                Logger.e("EditorViewModel: Failed to save composite image")
            }
        }

        @MainActor
        func copyToClipboard() {
            guard image != nil else {
                Logger.w("EditorViewModel: No image to copy")
                return
            }

            let compositeImage = renderCompositeImage()
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([compositeImage])
            Logger.s("EditorViewModel: Composite image copied to clipboard")
        }

        @MainActor
        func saveImageAs() {
            guard image != nil else {
                Logger.w("EditorViewModel: No image to save")
                return
            }

            let compositeImage = renderCompositeImage()
            
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.png, .jpeg]
            savePanel.nameFieldStringValue = settings.formattedFileName + ".png"
            savePanel.title = "Zapisz zrzut ekranu jako..."
            savePanel.message = "Wybierz lokalizację i nazwę pliku"
            WindowPlacement.centerModalPanel(savePanel)

            if savePanel.runModal() == .OK, let url = savePanel.url {
                if CaptureFileStore.writeScreenshot(compositeImage, to: url) {
                    Logger.s("EditorViewModel: Composite image saved as: \(url.path)")
                }
            }
        }

        // MARK: - Screenshot Methods

        @MainActor
        func captureFullScreen() async {
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await captureManager.captureFullScreen()
                show(image: image)
            } catch {
                Logger.e("EditorViewModel: Full screen capture error: \(error)")
            }
        }

        // Note: Area and window selection are now handled by FloatingPanelViewModel
        // EditorViewModel only handles direct full screen capture and showing images
        
        // MARK: - Background Calculations
        
        /// Calculates the background size based on aspect ratio and padding
        func calculateBackgroundSize(for imageSize: CGSize, in availableSize: CGSize) -> CGSize {
            ImageCompositeRenderer.calculateBackgroundSize(
                for: imageSize,
                in: availableSize,
                padding: backgroundPadding,
                aspectRatio: selectedAspectRatio
            )
        }

        /// Calculates the pixel size that would be written by the current export settings.
        func calculateOutputSize(for image: NSImage) -> CGSize {
            ImageCompositeRenderer.calculateOutputSize(
                for: image,
                backgroundManager: backgroundManager,
                padding: backgroundPadding,
                aspectRatio: selectedAspectRatio
            )
        }
        
        /// Renders the complete composition (screenshot + background) as NSImage
        private func renderCompositeImage() -> NSImage {
            guard let originalImage = image else {
                Logger.w("EditorViewModel: No image to render composite")
                return NSImage(size: CGSize(width: 100, height: 100))
            }

            return ImageCompositeRenderer.render(
                image: originalImage,
                backgroundManager: backgroundManager,
                annotations: annotationManager.annotations,
                padding: backgroundPadding,
                aspectRatio: selectedAspectRatio,
                shadowIntensity: shadowIntensity
            )
        }
    }

#endif
