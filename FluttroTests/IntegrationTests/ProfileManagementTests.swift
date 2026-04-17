//
//  ProfileManagementTests.swift
//  FluttroTests
//
//  Integration tests for profile management
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class ProfileManagementTests: XCTestCase {
    
    var profileManager: ProfileManager!
    var editorViewModel: EditorViewModel!
    var settings: AppSettings!
    
    override func setUp() {
        super.setUp()
        profileManager = ProfileManager()
        editorViewModel = EditorViewModel()
        settings = AppSettings.shared
    }
    
    override func tearDown() {
        // Clean up profiles
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let profilesDirectory = documentsPath.appendingPathComponent("Fluttro Profiles")
        if FileManager.default.fileExists(atPath: profilesDirectory.path) {
            try? FileManager.default.removeItem(at: profilesDirectory)
        }
        
        super.tearDown()
    }
    
    // MARK: - Full Profile Lifecycle Tests
    
    func testFullProfileLifecycle() {
        // Create
        let profile = ImageEditingProfile(
            name: "Lifecycle Test",
            backgroundAspectRatio: .ratio16_9,
            backgroundPadding: 40.0
        )
        profileManager.addImageProfile(profile)
        
        // Verify creation
        XCTAssertTrue(profileManager.imageProfiles.profiles.contains { $0.id == profile.id })
        
        // Update
        var updatedProfile = profile
        updatedProfile.name = "Updated Lifecycle Test"
        updatedProfile.backgroundPadding = 50.0
        profileManager.updateImageProfile(updatedProfile)
        
        // Verify update
        let foundProfile = profileManager.imageProfiles.profiles.first { $0.id == profile.id }
        XCTAssertEqual(foundProfile?.name, "Updated Lifecycle Test")
        XCTAssertEqual(foundProfile?.backgroundPadding, 50.0)
        
        // Set active
        profileManager.setActiveImageProfile(updatedProfile)
        XCTAssertEqual(profileManager.getActiveImageProfile()?.id, profile.id)
        
        // Delete
        let countBeforeDelete = profileManager.imageProfiles.profiles.count
        profileManager.removeImageProfile(withId: profile.id)
        XCTAssertEqual(profileManager.imageProfiles.profiles.count, countBeforeDelete - 1)
    }
    
    // MARK: - Profile Switching Tests
    
    func testSwitchingBetweenProfiles() {
        let profile1 = ImageEditingProfile(
            name: "Profile 1",
            backgroundAspectRatio: .ratio16_9
        )
        let profile2 = ImageEditingProfile(
            name: "Profile 2",
            backgroundAspectRatio: .ratio4_3
        )
        
        profileManager.addImageProfile(profile1)
        profileManager.addImageProfile(profile2)
        
        profileManager.setActiveImageProfile(profile1)
        XCTAssertEqual(profileManager.getActiveImageProfile()?.id, profile1.id)
        
        profileManager.setActiveImageProfile(profile2)
        XCTAssertEqual(profileManager.getActiveImageProfile()?.id, profile2.id)
    }
    
    // MARK: - Default Profiles Tests
    
    func testDefaultProfilesOnFirstRun() {
        // Create new ProfileManager (simulates first run)
        let newManager = ProfileManager()
        
        // Should have default profiles
        XCTAssertFalse(newManager.imageProfiles.profiles.isEmpty)
        XCTAssertFalse(newManager.videoProfiles.profiles.isEmpty)
        
        // Should have at least one default profile
        let hasDefaultImage = newManager.imageProfiles.profiles.contains { $0.isDefault }
        let hasDefaultVideo = newManager.videoProfiles.profiles.contains { $0.isDefault }
        XCTAssertTrue(hasDefaultImage)
        XCTAssertTrue(hasDefaultVideo)
    }
    
    // MARK: - Profile Application Tests
    
    func testApplyImageProfileToEditor() {
        let profile = ImageEditingProfile(
            name: "Test Apply",
            backgroundAspectRatio: .ratio16_9,
            backgroundPadding: 50.0,
            shadowIntensity: 30.0
        )
        
        profileManager.addImageProfile(profile)
        profileManager.applyImageProfile(profile, to: editorViewModel)
        
        // Verify profile was applied
        XCTAssertEqual(editorViewModel.selectedAspectRatio, .ratio16_9)
        XCTAssertEqual(editorViewModel.backgroundPadding, 50.0)
        XCTAssertEqual(editorViewModel.shadowIntensity, 30.0)
        
        // Verify profile is active
        XCTAssertEqual(profileManager.getActiveImageProfile()?.id, profile.id)
    }
    
    func testApplyVideoProfileToSettings() {
        let profile = VideoEditingProfile(
            name: "Test Apply Video",
            resolution: "1080p",
            frameRate: 60,
            bitrate: 10000000
        )
        
        profileManager.addVideoProfile(profile)
        profileManager.applyVideoProfile(profile, to: settings)
        
        // Verify profile was applied
        XCTAssertEqual(settings.videoResolution, "1080p")
        XCTAssertEqual(settings.videoFrameRate, 60)
        XCTAssertEqual(settings.videoBitrate, 10000000)
        
        // Verify profile is active
        XCTAssertEqual(profileManager.getActiveVideoProfile()?.id, profile.id)
    }
    
    // MARK: - Profile Creation from Settings Tests
    
    func testCreateImageProfileFromCurrentSettings() {
        editorViewModel.backgroundPadding = 45.0
        editorViewModel.selectedAspectRatio = .ratio1_1
        editorViewModel.shadowIntensity = 35.0
        
        let profile = profileManager.createImageProfileFromCurrentSettings(
            name: "From Editor",
            from: editorViewModel
        )
        
        XCTAssertEqual(profile.name, "From Editor")
        XCTAssertEqual(profile.backgroundPadding, 45.0)
        XCTAssertEqual(profile.backgroundAspectRatio, .ratio1_1)
        XCTAssertEqual(profile.shadowIntensity, 35.0)
        XCTAssertTrue(profileManager.imageProfiles.profiles.contains { $0.id == profile.id })
    }
    
    func testCreateVideoProfileFromCurrentSettings() {
        settings.videoResolution = "720p"
        settings.videoFrameRate = 24
        settings.videoBitrate = 3000000
        
        let profile = profileManager.createVideoProfileFromCurrentSettings(
            name: "From Settings",
            from: settings
        )
        
        XCTAssertEqual(profile.name, "From Settings")
        XCTAssertEqual(profile.resolution, "720p")
        XCTAssertEqual(profile.frameRate, 24)
        XCTAssertEqual(profile.bitrate, 3000000)
        XCTAssertTrue(profileManager.videoProfiles.profiles.contains { $0.id == profile.id })
    }
}

#endif








