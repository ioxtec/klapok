//
//  BackgroundModels.swift
//  Fluttro
//
//  Models for custom background gradients and images
//

import Foundation
import SwiftUI

// MARK: - Custom Gradient Model

struct CustomGradient: Codable, Identifiable {
    let id: UUID
    var name: String
    var color1: ColorData
    var color2: ColorData
    var opacity: Double
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        color1: ColorData,
        color2: ColorData,
        opacity: Double = 1.0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color1 = color1
        self.color2 = color2
        self.opacity = opacity
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var colors: [Color] {
        return [
            color1.color.opacity(opacity),
            color2.color.opacity(opacity)
        ]
    }
}

// MARK: - Color Data Model

struct ColorData: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    
    init(color: Color) {
        let nsColor = NSColor(color)

        // Try to convert to an RGB color space we can safely read components from
        if let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor.usingColorSpace(.deviceRGB) {
            self.red = Double(rgb.redComponent)
            self.green = Double(rgb.greenComponent)
            self.blue = Double(rgb.blueComponent)
            self.alpha = Double(rgb.alphaComponent)
        } else {
            let cgColor = nsColor.cgColor
            if let comps = cgColor.components {
            // Handle grayscale (2 comps: gray, alpha) or RGBA (4 comps)
            switch comps.count {
            case 2:
                let gray = Double(comps[0])
                self.red = gray
                self.green = gray
                self.blue = gray
                self.alpha = Double(comps[1])
            case 4:
                self.red = Double(comps[0])
                self.green = Double(comps[1])
                self.blue = Double(comps[2])
                self.alpha = Double(comps[3])
            default:
                print("ColorData: Unsupported color components, using default")
                self.red = 0.0
                self.green = 0.0
                self.blue = 1.0
                self.alpha = 1.0
            }
            } else {
                // Fallback to default color if components are nil
                print("ColorData: Failed to get color components, using default")
                self.red = 0.0
                self.green = 0.0
                self.blue = 1.0
                self.alpha = 1.0
            }
        }
    }
    
    var color: Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    func toColor() -> Color {
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    func toNSColor() -> NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Background Image Model

struct BackgroundImage: Codable, Identifiable {
    let id: UUID
    var name: String
    var fileName: String
    var opacity: Double
    var scaleMode: BackgroundScaleMode
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        opacity: Double = 1.0,
        scaleMode: BackgroundScaleMode = .fit,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.opacity = opacity
        self.scaleMode = scaleMode
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    var image: NSImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let backgroundImagesPath = documentsPath.appendingPathComponent("Fluttro Background Images")
        let imageURL = backgroundImagesPath.appendingPathComponent(fileName)
        return NSImage(contentsOf: imageURL)
    }
}

// MARK: - Background Scale Mode

enum BackgroundScaleMode: String, CaseIterable, Codable, Identifiable {
    case fit = "Fit"
    case fill = "Fill"
    case stretch = "Stretch"
    case tile = "Tile"
    case center = "Center"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Background Type

enum BackgroundType: String, CaseIterable, Codable, Identifiable {
    case gradient = "Gradient"
    case image = "Image"
    case none = "None"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Background Collections

struct BackgroundCollections: Codable {
    var customGradients: [CustomGradient]
    var backgroundImages: [BackgroundImage]
    var selectedGradientId: UUID?
    var selectedImageId: UUID?
    var backgroundType: BackgroundType
    
    init() {
        self.customGradients = []
        self.backgroundImages = []
        self.selectedGradientId = nil
        self.selectedImageId = nil
        self.backgroundType = .gradient
    }
    
    var selectedGradient: CustomGradient? {
        guard let selectedGradientId = selectedGradientId else { return nil }
        return customGradients.first { $0.id == selectedGradientId }
    }
    
    var selectedImage: BackgroundImage? {
        guard let selectedImageId = selectedImageId else { return nil }
        return backgroundImages.first { $0.id == selectedImageId }
    }
}

