//
//  ProfileModelsTests.swift
//  KlapokTests
//
//  Unit tests for ProfileModels
//

import XCTest
@testable import Klapok

#if os(macOS)
import AppKit
import SwiftUI

final class ProfileModelsTests: XCTestCase {
    
    // MARK: - ImageEditingProfile Tests
    
    func testImageEditingProfileInitialization() {
        let profile = ImageEditingProfile(
            name: "Test Profile",
            backgroundAspectRatio: .ratio16_9,
            backgroundPadding: 40.0,
            imageFormat: .jpeg,
            imageQuality: 0.85
        )
        
        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertEqual(profile.backgroundAspectRatio, .ratio16_9)
        XCTAssertEqual(profile.backgroundPadding, 40.0)
        XCTAssertEqual(profile.imageFormat, .jpeg)
        XCTAssertEqual(profile.imageQuality, 0.85)
        XCTAssertNotNil(profile.id)
    }
    
    func testImageEditingProfileDefaultValues() {
        let profile = ImageEditingProfile(name: "Default")
        
        XCTAssertEqual(profile.backgroundAspectRatio, .auto)
        XCTAssertEqual(profile.backgroundPadding, 30.0)
        XCTAssertEqual(profile.backgroundCornerRadius, 20.0)
        XCTAssertEqual(profile.shadowIntensity, 25.0)
        XCTAssertEqual(profile.imageFormat, .png)
        XCTAssertEqual(profile.imageQuality, 0.9)
        XCTAssertFalse(profile.showMouseCursor)
        XCTAssertTrue(profile.autoOpenEditor)
        XCTAssertFalse(profile.copyToClipboard)
        XCTAssertTrue(profile.showNotification)
    }
    
    func testImageEditingProfileSerialization() throws {
        let profile = ImageEditingProfile(
            name: "Serializable",
            backgroundAspectRatio: .ratio4_3,
            backgroundPadding: 50.0
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ImageEditingProfile.self, from: data)
        
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.backgroundAspectRatio, profile.backgroundAspectRatio)
        XCTAssertEqual(decoded.backgroundPadding, profile.backgroundPadding)
    }
    
    func testImageEditingProfileDefaultProfiles() {
        let defaults = ImageEditingProfile.createDefaultProfiles()
        
        XCTAssertFalse(defaults.isEmpty)
        XCTAssertTrue(defaults.contains { $0.isDefault })
        
        // Check that we have expected default profiles
        let names = defaults.map { $0.name }
        XCTAssertTrue(names.contains("Standard"))
        XCTAssertTrue(names.contains("Minimal"))
    }
    
    // MARK: - VideoEditingProfile Tests
    
    func testVideoEditingProfileInitialization() {
        let profile = VideoEditingProfile(
            name: "Test Video Profile",
            resolution: "1080p",
            frameRate: 60,
            bitrate: 10000000,
            codec: "H.265",
            format: "MOV"
        )
        
        XCTAssertEqual(profile.name, "Test Video Profile")
        XCTAssertEqual(profile.resolution, "1080p")
        XCTAssertEqual(profile.frameRate, 60)
        XCTAssertEqual(profile.bitrate, 10000000)
        XCTAssertEqual(profile.codec, "H.265")
        XCTAssertEqual(profile.format, "MOV")
        XCTAssertNotNil(profile.id)
    }
    
    func testVideoEditingProfileDefaultValues() {
        let profile = VideoEditingProfile(name: "Default")
        
        XCTAssertEqual(profile.resolution, "Source")
        XCTAssertEqual(profile.frameRate, 30)
        XCTAssertEqual(profile.bitrate, 5000000) // 5 Mbps
        XCTAssertEqual(profile.codec, "H.264")
        XCTAssertEqual(profile.format, "MP4")
        XCTAssertFalse(profile.recordSystemAudio)
        XCTAssertFalse(profile.showMouseCursor)
        XCTAssertFalse(profile.enableRecordingCountdown)
        XCTAssertEqual(profile.recordingCountdownSeconds, 3)
    }
    
    func testVideoEditingProfileSerialization() throws {
        let profile = VideoEditingProfile(
            name: "Serializable Video",
            resolution: "720p",
            frameRate: 30
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VideoEditingProfile.self, from: data)
        
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.resolution, profile.resolution)
        XCTAssertEqual(decoded.frameRate, profile.frameRate)
    }
    
    func testVideoEditingProfileDefaultProfiles() {
        let defaults = VideoEditingProfile.createDefaultProfiles()
        
        XCTAssertFalse(defaults.isEmpty)
        XCTAssertTrue(defaults.contains { $0.isDefault })
        
        // Check that we have expected default profiles
        let names = defaults.map { $0.name }
        XCTAssertTrue(names.contains("High Quality"))
        XCTAssertTrue(names.contains("Balanced"))
    }

    @MainActor
    func testVideoEditingProfileFromAppSettingsCopiesRecordingBehavior() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        settings.videoResolution = "720p"
        settings.videoFrameRate = 60
        settings.videoBitrate = 10_000_000
        settings.videoCodec = "H.265"
        settings.videoFormat = "MOV"
        settings.recordSystemAudio = true
        settings.showMouseCursor = true
        settings.enableRecordingCountdown = true
        settings.recordingCountdownSeconds = 5

        let profile = VideoEditingProfile.fromAppSettings(settings, name: "Captured Settings")

        XCTAssertEqual(profile.resolution, "720p")
        XCTAssertEqual(profile.frameRate, 60)
        XCTAssertEqual(profile.bitrate, 10_000_000)
        XCTAssertEqual(profile.codec, "H.265")
        XCTAssertEqual(profile.format, "MOV")
        XCTAssertTrue(profile.recordSystemAudio)
        XCTAssertTrue(profile.showMouseCursor)
        XCTAssertTrue(profile.enableRecordingCountdown)
        XCTAssertEqual(profile.recordingCountdownSeconds, 5)
    }

    @MainActor
    func testVideoEditingProfileUpdatingPreservesIdentityAndRefreshesValues() {
        let settings = AppSettings.shared
        settings.resetToDefaults()
        settings.videoResolution = "1080p"
        settings.videoFrameRate = 24
        settings.videoBitrate = 2_000_000
        settings.videoCodec = "H.264"
        settings.videoFormat = "MP4"
        settings.recordSystemAudio = true
        settings.showMouseCursor = false
        settings.enableRecordingCountdown = true
        settings.recordingCountdownSeconds = 7

        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let profile = VideoEditingProfile(
            id: UUID(),
            name: "Original Profile",
            isDefault: true,
            createdAt: createdAt,
            modifiedAt: createdAt,
            resolution: "Source"
        )

        let updatedProfile = profile.updating(from: settings, name: "Updated Profile")

        XCTAssertEqual(updatedProfile.id, profile.id)
        XCTAssertEqual(updatedProfile.createdAt, createdAt)
        XCTAssertTrue(updatedProfile.isDefault)
        XCTAssertEqual(updatedProfile.name, "Updated Profile")
        XCTAssertEqual(updatedProfile.resolution, "1080p")
        XCTAssertEqual(updatedProfile.frameRate, 24)
        XCTAssertEqual(updatedProfile.bitrate, 2_000_000)
        XCTAssertEqual(updatedProfile.codec, "H.264")
        XCTAssertEqual(updatedProfile.format, "MP4")
        XCTAssertTrue(updatedProfile.recordSystemAudio)
        XCTAssertFalse(updatedProfile.showMouseCursor)
        XCTAssertTrue(updatedProfile.enableRecordingCountdown)
        XCTAssertEqual(updatedProfile.recordingCountdownSeconds, 7)
        XCTAssertGreaterThanOrEqual(updatedProfile.modifiedAt.timeIntervalSince(createdAt), 0)
    }
    
    // MARK: - Profile Protocol Tests
    
    func testProfileProtocolConformance() {
        let imageProfile = ImageEditingProfile(name: "Test")
        let videoProfile = VideoEditingProfile(name: "Test")
        
        // Both should conform to Profile protocol
        XCTAssertNotNil(imageProfile.id)
        XCTAssertNotNil(videoProfile.id)
        XCTAssertEqual(imageProfile.name, "Test")
        XCTAssertEqual(videoProfile.name, "Test")
    }
}

#endif






