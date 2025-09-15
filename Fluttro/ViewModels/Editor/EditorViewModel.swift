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

        // MARK: - Dependencies

        private let screenshotService = ScreenshotService()
        private let settings = AppSettings.shared

        // MARK: - Public Methods

        @MainActor
        func show(image: NSImage) {
            Logger.s("EditorViewModel: Showing editor with image: \(image.size)")
            self.image = image
            self.isPresented = true
            Logger.s("EditorViewModel: isPresented set to true")
        }

        @MainActor
        func close() {
            print("EditorViewModel: Closing editor")
            self.isPresented = false
            self.image = nil
        }

        @MainActor
        func saveImage() {
            guard let image = image else {
                print("EditorViewModel: No image to save")
                return
            }

            if let savedURL = settings.saveScreenshot(image) {
                print("EditorViewModel: Image saved to: \(savedURL.path)")
                // Optionally show success notification
            } else {
                print("EditorViewModel: Failed to save image")
                // Optionally show error notification
            }
        }

        @MainActor
        func copyToClipboard() {
            guard let image = image else {
                print("EditorViewModel: No image to copy")
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            print("EditorViewModel: Image copied to clipboard")
        }

        @MainActor
        func saveImageAs() {
            guard let image = image else {
                print("EditorViewModel: No image to save")
                return
            }

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.png, .jpeg]
            savePanel.nameFieldStringValue = settings.formattedFileName + ".png"
            savePanel.title = "Zapisz zrzut ekranu jako..."
            savePanel.message = "Wybierz lokalizację i nazwę pliku"

            if savePanel.runModal() == .OK, let url = savePanel.url {
                guard let tiffData = image.tiffRepresentation,
                    let bitmapRep = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmapRep.representation(using: .png, properties: [:])
                else {
                    print("EditorViewModel: Failed to convert image to PNG")
                    return
                }

                do {
                    try pngData.write(to: url)
                    print("EditorViewModel: Image saved as: \(url.path)")
                } catch {
                    print("EditorViewModel: Failed to save image as: \(error)")
                }
            }
        }

        // MARK: - Screenshot Methods

        @MainActor
        func captureFullScreen() async {
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await screenshotService.captureMainDisplay()
                show(image: image)
            } catch {
                print("EditorViewModel: Full screen capture error: \(error)")
            }
        }

        // Note: Area and window selection are now handled by FloatingPanelViewModel
        // EditorViewModel only handles direct full screen capture and showing images
    }

#endif
