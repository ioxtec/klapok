//
//  ExportModels.swift
//  Fluttro
//
//  Models for video and GIF export settings
//

import Foundation
import SwiftUI

// MARK: - Export Type

enum ExportType: String, Codable, CaseIterable, Identifiable {
    case video = "Video"
    case gif = "GIF"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Video Export Settings

enum VideoQuality: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case veryHigh = "Very High"
    case maximum = "Maximum"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var bitrate: Int {
        switch self {
        case .low: return 1_000_000      // 1 Mbps
        case .medium: return 3_000_000   // 3 Mbps
        case .high: return 5_000_000     // 5 Mbps
        case .veryHigh: return 10_000_000 // 10 Mbps
        case .maximum: return 20_000_000  // 20 Mbps
        }
    }
}

enum VideoScaling: String, Codable, CaseIterable, Identifiable {
    case original = "Original"
    case scale50 = "50%"
    case scale75 = "75%"
    case scale125 = "125%"
    case scale150 = "150%"
    case scale200 = "200%"
    case custom = "Custom"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var scaleFactor: Double {
        switch self {
        case .original: return 1.0
        case .scale50: return 0.5
        case .scale75: return 0.75
        case .scale125: return 1.25
        case .scale150: return 1.5
        case .scale200: return 2.0
        case .custom: return 1.0
        }
    }
}

enum AudioExportOption: String, Codable, CaseIterable, Identifiable {
    case include = "Include Audio"
    case exclude = "Remove Audio"
    case mute = "Mute Audio"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct VideoExportSettings: Codable {
    var quality: VideoQuality
    var scaling: VideoScaling
    var customScaleFactor: Double
    var audioOption: AudioExportOption
    var includeSystemAudio: Bool
    var includeMicrophone: Bool
    var maintainAspectRatio: Bool
    
    init(
        quality: VideoQuality = .high,
        scaling: VideoScaling = .original,
        customScaleFactor: Double = 1.0,
        audioOption: AudioExportOption = .include,
        includeSystemAudio: Bool = true,
        includeMicrophone: Bool = true,
        maintainAspectRatio: Bool = true
    ) {
        self.quality = quality
        self.scaling = scaling
        self.customScaleFactor = customScaleFactor
        self.audioOption = audioOption
        self.includeSystemAudio = includeSystemAudio
        self.includeMicrophone = includeMicrophone
        self.maintainAspectRatio = maintainAspectRatio
    }
}

// MARK: - GIF Export Settings

enum GIFColorDepth: String, Codable, CaseIterable, Identifiable {
    case colors16 = "16 Colors"
    case colors32 = "32 Colors"
    case colors64 = "64 Colors"
    case colors128 = "128 Colors"
    case colors256 = "256 Colors"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var colorCount: Int {
        switch self {
        case .colors16: return 16
        case .colors32: return 32
        case .colors64: return 64
        case .colors128: return 128
        case .colors256: return 256
        }
    }
}

enum GIFFrameFormat: String, Codable, CaseIterable, Identifiable {
    case png = "PNG (Better Quality)"
    case bitmap = "Bitmap (Smaller Size)"
    case optimized = "Optimized (Balanced)"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum GIFLoopMode: String, Codable, CaseIterable, Identifiable {
    case infinite = "Loop Forever"
    case once = "Play Once"
    case count = "Custom Count"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum GIFDithering: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case floydSteinberg = "Floyd-Steinberg"
    case bayer = "Bayer"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct GIFExportSettings: Codable {
    var colorDepth: GIFColorDepth
    var frameFormat: GIFFrameFormat
    var frameRate: Int // FPS
    var loopMode: GIFLoopMode
    var loopCount: Int
    var dithering: GIFDithering
    var maxWidth: Int
    var maxHeight: Int
    var maintainAspectRatio: Bool
    var quality: Double // 0.0 - 1.0
    var optimizeForWeb: Bool
    var includeMetadata: Bool
    
    init(
        colorDepth: GIFColorDepth = .colors256,
        frameFormat: GIFFrameFormat = .optimized,
        frameRate: Int = 15,
        loopMode: GIFLoopMode = .infinite,
        loopCount: Int = 0,
        dithering: GIFDithering = .floydSteinberg,
        maxWidth: Int = 800,
        maxHeight: Int = 600,
        maintainAspectRatio: Bool = true,
        quality: Double = 0.8,
        optimizeForWeb: Bool = true,
        includeMetadata: Bool = false
    ) {
        self.colorDepth = colorDepth
        self.frameFormat = frameFormat
        self.frameRate = frameRate
        self.loopMode = loopMode
        self.loopCount = loopCount
        self.dithering = dithering
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.maintainAspectRatio = maintainAspectRatio
        self.quality = quality
        self.optimizeForWeb = optimizeForWeb
        self.includeMetadata = includeMetadata
    }

    enum CodingKeys: String, CodingKey {
        case colorDepth
        case frameFormat
        case frameRate
        case loopMode
        case loopCount
        case dithering
        case maxWidth
        case maxHeight
        case maintainAspectRatio
        case quality
        case optimizeForWeb
        case includeMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colorDepth = try container.decodeIfPresent(GIFColorDepth.self, forKey: .colorDepth) ?? .colors256
        frameFormat = try container.decodeIfPresent(GIFFrameFormat.self, forKey: .frameFormat) ?? .optimized
        frameRate = try container.decodeIfPresent(Int.self, forKey: .frameRate) ?? 15
        loopMode = try container.decodeIfPresent(GIFLoopMode.self, forKey: .loopMode) ?? .infinite
        loopCount = try container.decodeIfPresent(Int.self, forKey: .loopCount) ?? 0
        dithering = try container.decodeIfPresent(GIFDithering.self, forKey: .dithering) ?? .floydSteinberg
        maxWidth = try container.decodeIfPresent(Int.self, forKey: .maxWidth) ?? 800
        maxHeight = try container.decodeIfPresent(Int.self, forKey: .maxHeight) ?? 600
        maintainAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .maintainAspectRatio) ?? true
        quality = try container.decodeIfPresent(Double.self, forKey: .quality) ?? 0.8
        optimizeForWeb = try container.decodeIfPresent(Bool.self, forKey: .optimizeForWeb) ?? true
        includeMetadata = try container.decodeIfPresent(Bool.self, forKey: .includeMetadata) ?? false
    }
}

// MARK: - Export Settings Collection

struct ExportSettings: Codable {
    var exportType: ExportType
    var videoSettings: VideoExportSettings
    var gifSettings: GIFExportSettings
    
    init() {
        self.exportType = .video
        self.videoSettings = VideoExportSettings()
        self.gifSettings = GIFExportSettings()
    }
}

