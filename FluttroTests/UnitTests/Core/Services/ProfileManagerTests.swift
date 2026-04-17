//
//  ProfileManagerTests.swift
//  FluttroTests
//
//  Unit tests for ProfileManager
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class ProfileManagerTests: XCTestCase {
    
    var profileManager: ProfileManager!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTempDirectory()
        
        // Create ProfileManager with test directory
        // Note: ProfileManager uses Documents directory, so we'll test with actual paths
        profileManager = ProfileManager()
    }
    
    override func tearDown() {
        // Clean up profiles directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let profilesDirectory = documentsPath.appendingPathComponent("Fluttro Profiles")
        if FileManager.default.fileExists(atPath: profilesDirectory.path) {
            try? FileManager.default.removeItem(at: profilesDirectory)
        }
        
        if let testDirectory = testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(profileManager.imageProfiles)
        XCTAssertNotNil(profileManager.videoProfiles)
    }
    
    func testDefaultProfilesCreated() {
        // ProfileManager should create default profiles on initialization
        XCTAssertFalse(profileManager.imageProfiles.profiles.isEmpty)
        XCTAssertFalse(profileManager.videoProfiles.profiles.isEmpty)
    }
    
    // MARK: - Image Profile Management Tests
    
    func testAddImageProfile() {
        let initialCount = profileManager.imageProfiles.profiles.count
        
        let newProfile = ImageEditingProfile(
            name: "Test Profile",
            backgroundAspectRatio: .ratio16_9,
            backgroundPadding: 50.0
        )
        
        profileManager.addImageProfile(newProfile)
        
        XCTAssertEqual(profileManager.imageProfiles.profiles.count, initialCount + 1)
        XCTAssertTrue(profileManager.imageProfiles.profiles.contains { $0.id == newProfile.id })
    }
    
    func testUpdateImageProfile() {
        let profile = ImageEditingProfile(
            name: "Original Profile",
            backgroundPadding: 30.0
        )
        
        profileManager.addImageProfile(profile)
        
        var updatedProfile = profile
        updatedProfile.name = "Updated Profile"
        updatedProfile.backgroundPadding = 50.0
        
        profileManager.updateImageProfile(updatedProfile)
        
        let foundProfile = profileManager.imageProfiles.profiles.first { $0.id == profile.id }
        XCTAssertNotNil(foundProfile)
        XCTAssertEqual(foundProfile?.name, "Updated Profile")
        XCTAssertEqual(foundProfile?.backgroundPadding, 50.0)
    }
    
    func testRemoveImageProfile() {
        let profile = ImageEditingProfile(name: "To Remove")
        profileManager.addImageProfile(profile)
        
        let initialCount = profileManager.imageProfiles.profiles.count
        
        profileManager.removeImageProfile(withId: profile.id)
        
        XCTAssertEqual(profileManager.imageProfiles.profiles.count, initialCount - 1)
        XCTAssertFalse(profileManager.imageProfiles.profiles.contains { $0.id == profile.id })
    }
    
    func testSetActiveImageProfile() {
        let profile = ImageEditingProfile(name: "Active Profile")
        profileManager.addImageProfile(profile)
        
        profileManager.setActiveImageProfile(profile)
        
        let activeProfile = profileManager.getActiveImageProfile()
        XCTAssertNotNil(activeProfile)
        XCTAssertEqual(activeProfile?.id, profile.id)
    }
    
    func testGetActiveImageProfile() {
        let profile = ImageEditingProfile(name: "Test Active")
        profileManager.addImageProfile(profile)
        profileManager.setActiveImageProfile(profile)
        
        let activeProfile = profileManager.getActiveImageProfile()
        XCTAssertEqual(activeProfile?.id, profile.id)
    }
    
    // MARK: - Video Profile Management Tests
    
    func testAddVideoProfile() {
        let initialCount = profileManager.videoProfiles.profiles.count
        
        let newProfile = VideoEditingProfile(
            name: "Test Video Profile",
            resolution: "1080p",
            frameRate: 60
        )
        
        profileManager.addVideoProfile(newProfile)
        
        XCTAssertEqual(profileManager.videoProfiles.profiles.count, initialCount + 1)
        XCTAssertTrue(profileManager.videoProfiles.profiles.contains { $0.id == newProfile.id })
    }
    
    func testUpdateVideoProfile() {
        let profile = VideoEditingProfile(
            name: "Original Video Profile",
            resolution: "720p"
        )
        
        profileManager.addVideoProfile(profile)
        
        var updatedProfile = profile
        updatedProfile.name = "Updated Video Profile"
        updatedProfile.resolution = "1080p"
        
        profileManager.updateVideoProfile(updatedProfile)
        
        let foundProfile = profileManager.videoProfiles.profiles.first { $0.id == profile.id }
        XCTAssertNotNil(foundProfile)
        XCTAssertEqual(foundProfile?.name, "Updated Video Profile")
        XCTAssertEqual(foundProfile?.resolution, "1080p")
    }
    
    func testRemoveVideoProfile() {
        let profile = VideoEditingProfile(name: "To Remove")
        profileManager.addVideoProfile(profile)
        
        let initialCount = profileManager.videoProfiles.profiles.count
        
        profileManager.removeVideoProfile(withId: profile.id)
        
        XCTAssertEqual(profileManager.videoProfiles.profiles.count, initialCount - 1)
        XCTAssertFalse(profileManager.videoProfiles.profiles.contains { $0.id == profile.id })
    }
    
    func testSetActiveVideoProfile() {
        let profile = VideoEditingProfile(name: "Active Video Profile")
        profileManager.addVideoProfile(profile)
        
        profileManager.setActiveVideoProfile(profile)
        
        let activeProfile = profileManager.getActiveVideoProfile()
        XCTAssertNotNil(activeProfile)
        XCTAssertEqual(activeProfile?.id, profile.id)
    }
    
    // MARK: - Profile Persistence Tests
    
    func testImageProfilesPersistence() {
        let profile = ImageEditingProfile(name: "Persistent Profile")
        profileManager.addImageProfile(profile)
        
        // Create new ProfileManager instance to test loading
        let newManager = ProfileManager()
        
        let foundProfile = newManager.imageProfiles.profiles.first { $0.id == profile.id }
        XCTAssertNotNil(foundProfile)
        XCTAssertEqual(foundProfile?.name, "Persistent Profile")
    }
    
    func testVideoProfilesPersistence() {
        let profile = VideoEditingProfile(name: "Persistent Video Profile")
        profileManager.addVideoProfile(profile)
        
        // Create new ProfileManager instance to test loading
        let newManager = ProfileManager()
        
        let foundProfile = newManager.videoProfiles.profiles.first { $0.id == profile.id }
        XCTAssertNotNil(foundProfile)
        XCTAssertEqual(foundProfile?.name, "Persistent Video Profile")
    }
    
    // MARK: - Reset Tests
    
    func testResetImageProfilesToDefaults() {
        // Add custom profile
        let customProfile = ImageEditingProfile(name: "Custom")
        profileManager.addImageProfile(customProfile)
        
        // Reset to defaults
        profileManager.resetImageProfilesToDefaults()
        
        // Should have default profiles
        let defaultProfiles = ImageEditingProfile.createDefaultProfiles()
        XCTAssertEqual(profileManager.imageProfiles.profiles.count, defaultProfiles.count)
        XCTAssertFalse(profileManager.imageProfiles.profiles.contains { $0.id == customProfile.id })
    }
    
    func testResetVideoProfilesToDefaults() {
        // Add custom profile
        let customProfile = VideoEditingProfile(name: "Custom Video")
        profileManager.addVideoProfile(customProfile)
        
        // Reset to defaults
        profileManager.resetVideoProfilesToDefaults()
        
        // Should have default profiles
        let defaultProfiles = VideoEditingProfile.createDefaultProfiles()
        XCTAssertEqual(profileManager.videoProfiles.profiles.count, defaultProfiles.count)
        XCTAssertFalse(profileManager.videoProfiles.profiles.contains { $0.id == customProfile.id })
    }
    
    // MARK: - Profile Creation from Settings Tests
    
    func testCreateImageProfileFromCurrentSettings() {
        let editorViewModel = EditorViewModel()
        editorViewModel.backgroundPadding = 40.0
        editorViewModel.selectedAspectRatio = .ratio16_9
        
        let profile = profileManager.createImageProfileFromCurrentSettings(
            name: "From Settings",
            from: editorViewModel
        )
        
        XCTAssertEqual(profile.name, "From Settings")
        XCTAssertEqual(profile.backgroundPadding, 40.0)
        XCTAssertEqual(profile.backgroundAspectRatio, .ratio16_9)
        XCTAssertTrue(profileManager.imageProfiles.profiles.contains { $0.id == profile.id })
    }
    
    func testCreateVideoProfileFromCurrentSettings() {
        let settings = AppSettings.shared
        settings.videoResolution = "1080p"
        settings.videoFrameRate = 60
        
        let profile = profileManager.createVideoProfileFromCurrentSettings(
            name: "From Settings Video",
            from: settings
        )
        
        XCTAssertEqual(profile.name, "From Settings Video")
        XCTAssertEqual(profile.resolution, "1080p")
        XCTAssertEqual(profile.frameRate, 60)
        XCTAssertTrue(profileManager.videoProfiles.profiles.contains { $0.id == profile.id })
    }
}

#endif








