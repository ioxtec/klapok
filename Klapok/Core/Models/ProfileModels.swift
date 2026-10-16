//
//  ProfileModels.swift
//  Klapok
//
//  Models for video and image editing profiles/presets
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit

// MARK: - Base Profile Protocol

protocol Profile: Codable, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var isDefault: Bool { get set }
    var createdAt: Date { get set }
    var modifiedAt: Date { get set }
}

// MARK: - Image Editing Profile

struct ImageEditingProfile: Profile {
    let id: UUID
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var modifiedAt: Date
    
    // Background settings
    var backgroundAspectRatio: BackgroundAspectRatio
    var backgroundPadding: Double
    var backgroundCornerRadius: Double
    var shadowIntensity: Double
    var appearance: ImageProfileAppearance?
    
    // Image quality settings
    var imageFormat: ImageFormat
    var imageQuality: Double
    
    // Capture behavior
    var showMouseCursor: Bool
    var autoOpenEditor: Bool
    var copyToClipboard: Bool
    var showNotification: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        backgroundAspectRatio: BackgroundAspectRatio = .auto,
        backgroundPadding: Double = 30.0,
        backgroundCornerRadius: Double = 20.0,
        shadowIntensity: Double = 25.0,
        imageFormat: ImageFormat = .png,
        imageQuality: Double = 0.9,
        showMouseCursor: Bool = false,
        autoOpenEditor: Bool = true,
        copyToClipboard: Bool = false,
        showNotification: Bool = true,
        appearance: ImageProfileAppearance? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.backgroundAspectRatio = backgroundAspectRatio
        self.backgroundPadding = backgroundPadding
        self.backgroundCornerRadius = backgroundCornerRadius
        self.shadowIntensity = shadowIntensity
        self.imageFormat = imageFormat
        self.imageQuality = imageQuality
        self.showMouseCursor = showMouseCursor
        self.autoOpenEditor = autoOpenEditor
        self.copyToClipboard = copyToClipboard
        self.showNotification = showNotification
        self.appearance = appearance
    }
    
    // Create default profiles
    static func createDefaultProfiles() -> [ImageEditingProfile] {
        let appearance = ImageProfileAppearance(gradient: BackgroundManager.createDefaultGradients().first)
        return [
            ImageEditingProfile(
                name: "Standard",
                isDefault: true,
                backgroundAspectRatio: .auto,
                backgroundPadding: 30.0,
                shadowIntensity: 25.0,
                appearance: appearance
            ),
            ImageEditingProfile(
                name: "Minimal",
                backgroundAspectRatio: .auto,
                backgroundPadding: 10.0,
                shadowIntensity: 10.0,
                appearance: appearance
            ),
            ImageEditingProfile(
                name: "Original",
                backgroundAspectRatio: .auto,
                backgroundPadding: 0.0,
                backgroundCornerRadius: 0,
                shadowIntensity: 0.0,
                appearance: ImageProfileAppearance(backgroundType: .none)
            ),
            ImageEditingProfile(
                name: "Social Media",
                backgroundAspectRatio: .ratio1_1,
                backgroundPadding: 40.0,
                shadowIntensity: 30.0,
                appearance: appearance
            ),
            ImageEditingProfile(
                name: "Presentation",
                backgroundAspectRatio: .ratio16_9,
                backgroundPadding: 50.0,
                shadowIntensity: 40.0,
                appearance: appearance
            )
        ]
    }
}

// MARK: - Video Editing Profile

struct VideoEditingProfile: Profile {
    let id: UUID
    var name: String
    var isDefault: Bool
    var createdAt: Date
    var modifiedAt: Date
    
    // Video quality settings
    var resolution: String
    var frameRate: Int
    var bitrate: Int
    var codec: String
    var format: String
    
    // Audio settings
    var recordSystemAudio: Bool
    
    // Recording behavior
    var showMouseCursor: Bool
    var enableRecordingCountdown: Bool
    var recordingCountdownSeconds: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        resolution: String = "Source",
        frameRate: Int = 30,
        bitrate: Int = 5000000, // 5 Mbps
        codec: String = "H.264",
        format: String = "MP4",
        recordSystemAudio: Bool = false,
        showMouseCursor: Bool = false,
        enableRecordingCountdown: Bool = false,
        recordingCountdownSeconds: Int = 3
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.resolution = resolution
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.codec = codec
        self.format = format
        self.recordSystemAudio = recordSystemAudio
        self.showMouseCursor = showMouseCursor
        self.enableRecordingCountdown = enableRecordingCountdown
        self.recordingCountdownSeconds = min(max(recordingCountdownSeconds, 1), 30)
    }
    
    // Create default profiles
    static func createDefaultProfiles() -> [VideoEditingProfile] {
        return [
            VideoEditingProfile(
                name: "High Quality",
                isDefault: true,
                resolution: "Source",
                frameRate: 60,
                bitrate: 10000000, // 10 Mbps
                codec: "H.264",
                format: "MP4"
            ),
            VideoEditingProfile(
                name: "Balanced",
                resolution: "1080p",
                frameRate: 30,
                bitrate: 5000000, // 5 Mbps
                codec: "H.264",
                format: "MP4"
            ),
            VideoEditingProfile(
                name: "Small File",
                resolution: "720p",
                frameRate: 30,
                bitrate: 2000000, // 2 Mbps
                codec: "H.264",
                format: "MP4"
            ),
            VideoEditingProfile(
                name: "Screen Recording",
                resolution: "Source",
                frameRate: 30,
                bitrate: 5000000, // 5 Mbps
                codec: "H.264",
                format: "MP4",
                recordSystemAudio: true,
                showMouseCursor: true
            ),
            VideoEditingProfile(
                name: "Tutorial",
                resolution: "1080p",
                frameRate: 30,
                bitrate: 5000000, // 5 Mbps
                codec: "H.264",
                format: "MP4",
                recordSystemAudio: true,
                showMouseCursor: true
            )
        ]
    }
}

// MARK: - Supporting Enums

enum ImageFormat: String, CaseIterable, Codable {
    case png = "PNG"
    case jpeg = "JPEG"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Background Aspect Ratio

enum BackgroundAspectRatio: String, CaseIterable, Codable, Identifiable {
    case auto = "Auto"
    case ratio16_9 = "16:9"
    case ratio4_3 = "4:3"
    case ratio3_2 = "3:2"
    case ratio1_1 = "1:1"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var ratio: CGFloat {
        switch self {
        case .auto:
            return 0 // Special case, will use available space
        case .ratio16_9:
            return 16.0 / 9.0
        case .ratio4_3:
            return 4.0 / 3.0
        case .ratio3_2:
            return 3.0 / 2.0
        case .ratio1_1:
            return 1.0
        }
    }
}

// MARK: - Background Gradient

enum BackgroundGradient: String, CaseIterable, Codable, Identifiable {
    case cool = "Cool"
    case warm = "Warm"
    case violet = "Violet"
    case rose = "Rose"
    case sky = "Sky"
    case beach = "Beach"
    case love = "Love"
    case flower = "Flower"
    case sunset = "Sunset"
    case ocean = "Ocean"
    case forest = "Forest"
    case none = "None"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var colors: [Color] {
        switch self {
        case .cool:
            return [Color.blue.opacity(0.7), Color.cyan.opacity(0.7)]
        case .warm:
            return [Color.orange.opacity(0.7), Color.yellow.opacity(0.7)]
        case .violet:
            return [Color.purple.opacity(0.7), Color.pink.opacity(0.7)]
        case .rose:
            return [Color.pink.opacity(0.7), Color.red.opacity(0.7)]
        case .sky:
            return [Color.blue.opacity(0.6), Color.white.opacity(0.6)]
        case .beach:
            return [Color.blue.opacity(0.7), Color.green.opacity(0.7)]
        case .love:
            return [Color.pink.opacity(0.7), Color.purple.opacity(0.7)]
        case .flower:
            return [Color.pink.opacity(0.7), Color.orange.opacity(0.7)]
        case .sunset:
            return [Color.orange.opacity(0.7), Color.red.opacity(0.7)]
        case .ocean:
            return [Color.blue.opacity(0.7), Color.teal.opacity(0.7)]
        case .forest:
            return [Color.green.opacity(0.7), Color.mint.opacity(0.7)]
        case .none:
            return [Color.clear, Color.clear]
        }
    }
}

// MARK: - Profile Collections

struct ProfileCollection<T: Profile>: Codable {
    var profiles: [T]
    var activeProfileId: UUID?
    
    init(profiles: [T] = [], activeProfileId: UUID? = nil) {
        self.profiles = profiles
        self.activeProfileId = activeProfileId
    }
    
    var activeProfile: T? {
        guard let activeProfileId = activeProfileId else { return nil }
        return profiles.first { $0.id == activeProfileId }
    }
    
    mutating func setActiveProfile(_ profile: T) {
        activeProfileId = profile.id
    }
    
    mutating func addProfile(_ profile: T) {
        profiles.append(profile)
    }
    
    mutating func updateProfile(_ profile: T) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }
    
    mutating func removeProfile(withId id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = profiles.first?.id
        }
    }
}

// MARK: - Profile Extensions

extension ImageEditingProfile {
    @discardableResult
    func applyToEditorViewModel(_ viewModel: EditorViewModel, background: BackgroundManager = .shared) -> Bool {
        // Older libraries have no appearance snapshot. Preserve their background except for Original.
        let isLegacyOriginal = appearance == nil && name == "Original" && backgroundPadding == 0 && shadowIntensity == 0
        do {
            if let appearance {
                try appearance.apply(to: viewModel, background: background)
            } else if isLegacyOriginal {
                try ImageProfileAppearance(backgroundType: .none).apply(to: viewModel, background: background)
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
            return false
        }
        viewModel.selectedAspectRatio = backgroundAspectRatio
        viewModel.backgroundPadding = backgroundPadding
        viewModel.backgroundCornerRadius = isLegacyOriginal ? 0 : backgroundCornerRadius
        viewModel.shadowIntensity = shadowIntensity
        return true
    }
    
    static func fromEditorViewModel(_ viewModel: EditorViewModel, name: String,
                                    background: BackgroundManager = .shared) -> ImageEditingProfile {
        return ImageEditingProfile(
            name: name,
            backgroundAspectRatio: viewModel.selectedAspectRatio,
            backgroundPadding: viewModel.backgroundPadding,
            backgroundCornerRadius: viewModel.backgroundCornerRadius,
            shadowIntensity: viewModel.shadowIntensity,
            appearance: .capture(from: viewModel, background: background)
        )
    }

    func updating(from viewModel: EditorViewModel, background: BackgroundManager = .shared) -> Self {
        var updated = self
        updated.modifiedAt = Date()
        updated.backgroundAspectRatio = viewModel.selectedAspectRatio
        updated.backgroundPadding = viewModel.backgroundPadding
        updated.backgroundCornerRadius = viewModel.backgroundCornerRadius
        updated.shadowIntensity = viewModel.shadowIntensity
        updated.appearance = .capture(from: viewModel, background: background)
        return updated
    }
}

extension VideoEditingProfile {
    func applyToAppSettings(_ settings: AppSettings) {
        settings.videoResolution = resolution
        settings.videoFrameRate = frameRate
        settings.videoBitrate = bitrate
        settings.videoCodec = codec
        settings.videoFormat = format
        settings.recordSystemAudio = recordSystemAudio
        settings.showMouseCursor = showMouseCursor
        settings.enableRecordingCountdown = enableRecordingCountdown
        settings.recordingCountdownSeconds = recordingCountdownSeconds
    }
    
    static func fromAppSettings(_ settings: AppSettings, name: String) -> VideoEditingProfile {
        return VideoEditingProfile(
            name: name,
            resolution: settings.videoResolution,
            frameRate: settings.videoFrameRate,
            bitrate: settings.videoBitrate,
            codec: settings.videoCodec,
            format: settings.videoFormat,
            recordSystemAudio: settings.recordSystemAudio,
            showMouseCursor: settings.showMouseCursor,
            enableRecordingCountdown: settings.enableRecordingCountdown,
            recordingCountdownSeconds: settings.recordingCountdownSeconds
        )
    }

    func updating(from settings: AppSettings, name: String? = nil) -> VideoEditingProfile {
        VideoEditingProfile(
            id: id,
            name: name ?? self.name,
            isDefault: isDefault,
            createdAt: createdAt,
            modifiedAt: Date(),
            resolution: settings.videoResolution,
            frameRate: settings.videoFrameRate,
            bitrate: settings.videoBitrate,
            codec: settings.videoCodec,
            format: settings.videoFormat,
            recordSystemAudio: settings.recordSystemAudio,
            showMouseCursor: settings.showMouseCursor,
            enableRecordingCountdown: settings.enableRecordingCountdown,
            recordingCountdownSeconds: settings.recordingCountdownSeconds
        )
    }
}

#endif
