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
        
        // Background manager
        private let backgroundManager = BackgroundManager.shared

        // MARK: - Dependencies

        @MainActor private let captureManager = CaptureManager.shared
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
            guard image != nil else {
                print("EditorViewModel: No image to save")
                return
            }

            print("EditorViewModel: Starting saveImage process...")
            print("EditorViewModel: Current settings - aspect: \(selectedAspectRatio), padding: \(backgroundPadding), background type: \(backgroundManager.collections.backgroundType)")
            
            // Render the complete composition (screenshot + background)
            let compositeImage = renderCompositeImage()
            print("EditorViewModel: Composite image rendered, size: \(compositeImage.size)")
            print("EditorViewModel: Composite image is valid: \(compositeImage.size.width > 0 && compositeImage.size.height > 0)")
            
            if let savedURL = settings.saveScreenshot(compositeImage) {
                print("EditorViewModel: Composite image saved to: \(savedURL.path)")
                // Optionally show success notification
            } else {
                print("EditorViewModel: Failed to save composite image")
                // Optionally show error notification
            }
        }

        @MainActor
        func copyToClipboard() {
            guard image != nil else {
                print("EditorViewModel: No image to copy")
                return
            }

            // Copy the complete composition (screenshot + background)
            let compositeImage = renderCompositeImage()
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([compositeImage])
            print("EditorViewModel: Composite image copied to clipboard")
        }

        @MainActor
        func saveImageAs() {
            guard image != nil else {
                print("EditorViewModel: No image to save")
                return
            }

            // Render the complete composition (screenshot + background)
            let compositeImage = renderCompositeImage()
            
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.png, .jpeg]
            savePanel.nameFieldStringValue = settings.formattedFileName + ".png"
            savePanel.title = "Zapisz zrzut ekranu jako..."
            savePanel.message = "Wybierz lokalizację i nazwę pliku"

            if savePanel.runModal() == .OK, let url = savePanel.url {
                guard let tiffData = compositeImage.tiffRepresentation,
                    let bitmapRep = NSBitmapImageRep(data: tiffData),
                    let pngData = bitmapRep.representation(using: .png, properties: [:])
                else {
                    print("EditorViewModel: Failed to convert composite image to PNG")
                    return
                }

                do {
                    try pngData.write(to: url)
                    print("EditorViewModel: Composite image saved as: \(url.path)")
                } catch {
                    print("EditorViewModel: Failed to save composite image as: \(error)")
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
                print("EditorViewModel: Full screen capture error: \(error)")
            }
        }

        // Note: Area and window selection are now handled by FloatingPanelViewModel
        // EditorViewModel only handles direct full screen capture and showing images
        
        // MARK: - Background Calculations
        
        /// Calculates the background size based on aspect ratio and padding
        func calculateBackgroundSize(for imageSize: CGSize, in availableSize: CGSize) -> CGSize {
            let padding = backgroundPadding
            let availableWidth = availableSize.width - (padding * 2)
            let availableHeight = availableSize.height - (padding * 2)
            
            switch selectedAspectRatio {
            case .auto:
                // Use available space with padding
                return CGSize(width: availableWidth, height: availableHeight)
                
            default:
                let ratio = selectedAspectRatio.ratio
                let width = availableWidth
                let height = width / ratio
                
                // If height exceeds available space, scale down based on height
                if height > availableHeight {
                    return CGSize(width: availableHeight * ratio, height: availableHeight)
                } else {
                    return CGSize(width: width, height: height)
                }
            }
        }
        
        /// Calculates the image position within the background
        func calculateImagePosition(backgroundSize: CGSize, imageSize: CGSize) -> CGPoint {
            let x = (backgroundSize.width - imageSize.width) / 2
            let y = (backgroundSize.height - imageSize.height) / 2
            return CGPoint(x: x, y: y)
        }
        
        /// Calculates appropriate export size based on aspect ratio
        private func calculateExportSize(for imageSize: CGSize) -> CGSize {
            let baseSize: CGFloat = 1200 // Base width for export
            
            switch selectedAspectRatio {
            case .auto:
                // Use image proportions with reasonable padding
                let imageRatio = imageSize.width / imageSize.height
                if imageRatio > 1.0 {
                    // Landscape
                    return CGSize(width: baseSize, height: baseSize / imageRatio)
                } else {
                    // Portrait or square
                    return CGSize(width: baseSize * imageRatio, height: baseSize)
                }
                
            case .ratio16_9:
                return CGSize(width: baseSize, height: baseSize * 9 / 16)
                
            case .ratio4_3:
                return CGSize(width: baseSize, height: baseSize * 3 / 4)
                
            case .ratio3_2:
                return CGSize(width: baseSize, height: baseSize * 2 / 3)
                
            case .ratio1_1:
                return CGSize(width: baseSize, height: baseSize)
            }
        }
        
        /// Renders the complete composition (screenshot + background) as NSImage
        private func renderCompositeImage() -> NSImage {
            guard let originalImage = image else {
                print("EditorViewModel: No image to render composite")
                return NSImage(size: CGSize(width: 100, height: 100)) // Return a small placeholder image instead of empty
            }
            
            let imageSize = originalImage.size
            print("EditorViewModel: Rendering composite image - original size: \(imageSize)")
            print("EditorViewModel: Settings - background type: \(backgroundManager.collections.backgroundType), aspect ratio: \(selectedAspectRatio), padding: \(backgroundPadding)")
            
            // If background is disabled, return original image
            if backgroundManager.collections.backgroundType == .none {
                print("EditorViewModel: Background disabled, returning original image")
                return originalImage
            }
            
            // Calculate appropriate export size based on aspect ratio
            let exportSize = calculateExportSize(for: imageSize)
            let backgroundSize = calculateBackgroundSize(for: imageSize, in: exportSize)
            print("EditorViewModel: Export size: \(exportSize), background size: \(backgroundSize)")
            
            // Calculate image scale and final size
            let imagePadding = backgroundPadding
            let maxImageWidth = backgroundSize.width - (imagePadding * 2)
            let maxImageHeight = backgroundSize.height - (imagePadding * 2)
            
            let scaleX = imageSize.width > maxImageWidth ? maxImageWidth / imageSize.width : 1.0
            let scaleY = imageSize.height > maxImageHeight ? maxImageHeight / imageSize.height : 1.0
            let scale = min(scaleX, scaleY)
            
            let finalImageWidth = imageSize.width * scale
            let finalImageHeight = imageSize.height * scale
            
            // Create the composite image
            let compositeSize = backgroundSize
            let compositeImage = NSImage(size: compositeSize)
            
            compositeImage.lockFocus()
            
            // Draw background
            print("EditorViewModel: Drawing background - type: \(backgroundManager.collections.backgroundType), size: \(compositeSize)")
            
            if let context = NSGraphicsContext.current?.cgContext {
                switch backgroundManager.collections.backgroundType {
                case .gradient:
                    if let selectedGradient = backgroundManager.collections.selectedGradient {
                        print("EditorViewModel: Drawing custom gradient background")
                        let gradientColors = selectedGradient.colors.map { $0.cgColor }
                        
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0.0, 1.0])
                        
                        if let gradient = gradient {
                            context.drawLinearGradient(
                                gradient,
                                start: CGPoint(x: 0, y: compositeSize.height),
                                end: CGPoint(x: compositeSize.width, y: 0),
                                options: []
                            )
                        }
                    } else {
                        // Fallback to solid color
                        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
                        context.fill(CGRect(origin: .zero, size: compositeSize))
                    }
                    
                case .image:
                    if let selectedImage = backgroundManager.collections.selectedImage,
                       let backgroundImage = selectedImage.image {
                        print("EditorViewModel: Drawing background image")
                        drawBackgroundImage(backgroundImage, in: context, size: compositeSize, scaleMode: selectedImage.scaleMode, opacity: selectedImage.opacity)
                    } else {
                        // Fallback to solid color
                        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
                        context.fill(CGRect(origin: .zero, size: compositeSize))
                    }
                    
                case .none:
                    // Draw transparent background
                    print("EditorViewModel: Drawing transparent background")
                    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0))
                    context.fill(CGRect(origin: .zero, size: compositeSize))
                }
            } else {
                print("EditorViewModel: No graphics context available - this is the problem!")
            }
            
            // Draw shadow for the image (simplified version)
            let shadowOffset = CGSize(width: 0, height: -shadowIntensity / 2)
            let shadowBlur = shadowIntensity
            
            // Draw image with shadow
            let imageRect = NSRect(
                x: (backgroundSize.width - finalImageWidth) / 2,
                y: (backgroundSize.height - finalImageHeight) / 2,
                width: finalImageWidth,
                height: finalImageHeight
            )
            
            // Apply shadow
            let shadow = NSShadow()
            shadow.shadowOffset = shadowOffset
            shadow.shadowBlurRadius = shadowBlur
            shadow.shadowColor = NSColor.black.withAlphaComponent(shadowIntensity / 100.0)
            shadow.set()
            
            // Draw the image
            originalImage.draw(
                in: imageRect,
                from: NSRect(origin: .zero, size: originalImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )
            
            compositeImage.unlockFocus()
            
            print("EditorViewModel: Composite image created with size: \(compositeImage.size)")
            return compositeImage
        }
        
        /// Draws background image with specified scale mode and opacity
        private func drawBackgroundImage(_ image: NSImage, in context: CGContext, size: CGSize, scaleMode: BackgroundScaleMode, opacity: Double) {
            let imageSize = image.size
            let targetRect = CGRect(origin: .zero, size: size)
            
            context.setAlpha(opacity)
            
            switch scaleMode {
            case .fit:
                // Scale to fit while maintaining aspect ratio
                let scale = min(size.width / imageSize.width, size.height / imageSize.height)
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let x = (size.width - scaledSize.width) / 2
                let y = (size.height - scaledSize.height) / 2
                let rect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
                image.draw(in: rect)
                
            case .fill:
                // Scale to fill while maintaining aspect ratio
                let scale = max(size.width / imageSize.width, size.height / imageSize.height)
                let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                let x = (size.width - scaledSize.width) / 2
                let y = (size.height - scaledSize.height) / 2
                let rect = CGRect(x: x, y: y, width: scaledSize.width, height: scaledSize.height)
                image.draw(in: rect)
                
            case .stretch:
                // Stretch to fill entire area
                image.draw(in: targetRect)
                
            case .tile:
                // Tile the image
                let patternRect = CGRect(origin: .zero, size: imageSize)
                image.draw(in: targetRect, from: patternRect, operation: .sourceOver, fraction: 1.0)
                
            case .center:
                // Center without scaling
                let x = (size.width - imageSize.width) / 2
                let y = (size.height - imageSize.height) / 2
                let rect = CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height)
                image.draw(in: rect)
            }
            
            context.setAlpha(1.0)
        }
    }

#endif
