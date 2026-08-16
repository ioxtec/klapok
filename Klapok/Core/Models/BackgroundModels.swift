//
//  BackgroundModels.swift
//  Klapok
//
//  Models for custom background gradients and images
//

import Foundation
import SwiftUI

// MARK: - Custom Gradient Model

struct GradientStopData: Codable, Identifiable, Equatable {
    let id: UUID
    var color: ColorData
    var location: Double

    init(
        id: UUID = UUID(),
        color: ColorData,
        location: Double
    ) {
        self.id = id
        self.color = color
        self.location = min(max(location, 0), 1)
    }
}

enum GradientDirection: String, CaseIterable, Codable, Identifiable {
    case topToBottom = "Top to Bottom"
    case leftToRight = "Left to Right"
    case topLeadingToBottomTrailing = "Top Left to Bottom Right"
    case bottomLeadingToTopTrailing = "Bottom Left to Top Right"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .topToBottom:
            return "Vertical"
        case .leftToRight:
            return "Horizontal"
        case .topLeadingToBottomTrailing:
            return "Diagonal"
        case .bottomLeadingToTopTrailing:
            return "Reverse"
        }
    }

    var startPoint: UnitPoint {
        switch self {
        case .topToBottom:
            return .top
        case .leftToRight:
            return .leading
        case .topLeadingToBottomTrailing:
            return .topLeading
        case .bottomLeadingToTopTrailing:
            return .bottomLeading
        }
    }

    var endPoint: UnitPoint {
        switch self {
        case .topToBottom:
            return .bottom
        case .leftToRight:
            return .trailing
        case .topLeadingToBottomTrailing:
            return .bottomTrailing
        case .bottomLeadingToTopTrailing:
            return .topTrailing
        }
    }

    func cgPoints(in size: CGSize) -> (start: CGPoint, end: CGPoint) {
        switch self {
        case .topToBottom:
            return (
                CGPoint(x: size.width / 2, y: size.height),
                CGPoint(x: size.width / 2, y: 0)
            )
        case .leftToRight:
            return (
                CGPoint(x: 0, y: size.height / 2),
                CGPoint(x: size.width, y: size.height / 2)
            )
        case .topLeadingToBottomTrailing:
            return (
                CGPoint(x: 0, y: size.height),
                CGPoint(x: size.width, y: 0)
            )
        case .bottomLeadingToTopTrailing:
            return (
                CGPoint(x: 0, y: 0),
                CGPoint(x: size.width, y: size.height)
            )
        }
    }
}

struct CustomGradient: Codable, Identifiable {
    let id: UUID
    var name: String
    var color1: ColorData
    var color2: ColorData
    var opacity: Double
    var direction: GradientDirection
    var stops: [GradientStopData]
    var createdAt: Date
    var modifiedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color1
        case color2
        case opacity
        case direction
        case stops
        case createdAt
        case modifiedAt
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        color1: ColorData,
        color2: ColorData,
        opacity: Double = 1.0,
        direction: GradientDirection = .topLeadingToBottomTrailing,
        stops: [GradientStopData]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color1 = color1
        self.color2 = color2
        self.opacity = opacity
        self.direction = direction
        self.stops = CustomGradient.normalizedStops(stops ?? [
            GradientStopData(color: color1, location: 0),
            GradientStopData(color: color2, location: 1)
        ])
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        direction = try container.decodeIfPresent(GradientDirection.self, forKey: .direction)
            ?? .topLeadingToBottomTrailing
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt

        let decodedStops = try container.decodeIfPresent([GradientStopData].self, forKey: .stops)
        color1 = try container.decodeIfPresent(ColorData.self, forKey: .color1)
            ?? decodedStops?.first?.color
            ?? ColorData(color: .blue)
        color2 = try container.decodeIfPresent(ColorData.self, forKey: .color2)
            ?? decodedStops?.last?.color
            ?? ColorData(color: .purple)

        stops = CustomGradient.normalizedStops(decodedStops ?? [
            GradientStopData(color: color1, location: 0),
            GradientStopData(color: color2, location: 1)
        ])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color1, forKey: .color1)
        try container.encode(color2, forKey: .color2)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(direction, forKey: .direction)
        try container.encode(sortedStops, forKey: .stops)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
    }
    
    var colors: [Color] {
        sortedStops.map { $0.color.color.opacity(opacity) }
    }

    var sortedStops: [GradientStopData] {
        CustomGradient.normalizedStops(stops)
    }

    var gradientStops: [Gradient.Stop] {
        sortedStops.map {
            Gradient.Stop(color: $0.color.color.opacity(opacity), location: $0.location)
        }
    }

    private static func normalizedStops(_ stops: [GradientStopData]) -> [GradientStopData] {
        let sortedStops = stops
            .map { GradientStopData(id: $0.id, color: $0.color, location: $0.location) }
            .sorted { $0.location < $1.location }

        if sortedStops.count >= 2 {
            return sortedStops
        }

        if let stop = sortedStops.first {
            return [
                GradientStopData(color: stop.color, location: 0),
                GradientStopData(color: stop.color, location: 1)
            ]
        }

        return [
            GradientStopData(color: ColorData(color: .blue), location: 0),
            GradientStopData(color: ColorData(color: .purple), location: 1)
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
                Logger.w("ColorData: Unsupported color components, using default")
                self.red = 0.0
                self.green = 0.0
                self.blue = 1.0
                self.alpha = 1.0
            }
            } else {
                Logger.w("ColorData: Failed to get color components, using default")
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
        let backgroundImagesPath = documentsPath.appendingPathComponent("Klapok Background Images")
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
