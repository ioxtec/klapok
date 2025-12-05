//
//  AppSettingsTests.swift
//  FluttroTests
//
//  Unit tests for AppSettings
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class AppSettingsTests: XCTestCase {
    
    var settings: AppSettings!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        // Use a test-specific UserDefaults suite
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Create test directory
        testDirectory = TestHelpers.createTempDirectory()
        
        // Note: AppSettings uses singleton, so we test the shared instance
        settings = AppSettings.shared
    }
    
    override func tearDown() {
        // Clean up test directory
        if let testDirectory = testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        
        // Reset UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(settings.saveDirectory)
        XCTAssertNotNil(settings.videoSaveDirectory)
        XCTAssertFalse(settings.fileNameTemplate.isEmpty)
        XCTAssertFalse(settings.videoFileNameTemplate.isEmpty)
    }
    
    func testDefaultValues() {
        XCTAssertEqual(settings.fileNameTemplate, "Screenshot-{datetime}")
        XCTAssertEqual(settings.videoFileNameTemplate, "Video-{datetime}")
        XCTAssertEqual(settings.videoResolution, "Source")
        XCTAssertEqual(settings.videoFrameRate, 30)
        XCTAssertEqual(settings.videoBitrate, 5000000) // 5 Mbps
        XCTAssertEqual(settings.videoCodec, "H.264")
        XCTAssertEqual(settings.videoFormat, "MP4")
    }
    
    // MARK: - Save Directory Tests
    
    func testSaveDirectoryPersistence() {
        let newDirectory = testDirectory.appendingPathComponent("Test Screenshots")
        settings.saveDirectory = newDirectory
        
        // Verify it's saved to UserDefaults
        let savedPath = UserDefaults.standard.string(forKey: "saveDirectory")
        XCTAssertEqual(savedPath, newDirectory.path)
    }
    
    func testVideoSaveDirectoryPersistence() {
        let newDirectory = testDirectory.appendingPathComponent("Test Videos")
        settings.videoSaveDirectory = newDirectory
        
        // Verify it's saved to UserDefaults
        let savedPath = UserDefaults.standard.string(forKey: "videoSaveDirectory")
        XCTAssertEqual(savedPath, newDirectory.path)
    }
    
    // MARK: - File Name Template Tests
    
    func testFileNameTemplatePersistence() {
        let template = "Custom-{datetime}"
        settings.fileNameTemplate = template
        
        let saved = UserDefaults.standard.string(forKey: "fileNameTemplate")
        XCTAssertEqual(saved, template)
    }
    
    func testVideoFileNameTemplatePersistence() {
        let template = "CustomVideo-{datetime}"
        settings.videoFileNameTemplate = template
        
        let saved = UserDefaults.standard.string(forKey: "videoFileNameTemplate")
        XCTAssertEqual(saved, template)
    }
    
    func testFormattedFileName() {
        settings.fileNameTemplate = "Test-{datetime}"
        let formatted = settings.formattedFileName
        
        // Should contain "Test-" prefix
        XCTAssertTrue(formatted.hasPrefix("Test-"))
        // Should contain date format (yyyy-MM-dd_HH-mm-ss)
        XCTAssertTrue(formatted.contains("-"))
    }
    
    func testFormattedVideoFileName() {
        settings.videoFileNameTemplate = "TestVideo-{datetime}"
        let formatted = settings.formattedVideoFileName
        
        // Should contain "TestVideo-" prefix
        XCTAssertTrue(formatted.hasPrefix("TestVideo-"))
    }
    
    func testFileNameTemplateWithDateVariables() {
        settings.fileNameTemplate = "Screenshot-{date}"
        let formatted = settings.formattedFileName
        
        // Should contain "Screenshot-" prefix
        XCTAssertTrue(formatted.hasPrefix("Screenshot-"))
    }
    
    // MARK: - Hotkey Tests
    
    func testHotkeyModifiersPersistence() {
        let modifiers: NSEvent.ModifierFlags = [.command, .option]
        settings.hotkeyModifiers = modifiers
        
        let saved = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt
        XCTAssertEqual(saved, modifiers.rawValue)
    }
    
    func testHotkeyKeyCodePersistence() {
        let keyCode: UInt16 = 0x1A
        settings.hotkeyKeyCode = keyCode
        
        let saved = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        XCTAssertEqual(saved, Int(keyCode))
    }
    
    func testHotkeyDisplayString() {
        settings.hotkeyModifiers = [.command, .shift]
        settings.hotkeyKeyCode = 0x1A // ]
        
        let displayString = settings.hotkeyDisplayString
        XCTAssertTrue(displayString.contains("⌘"))
        XCTAssertTrue(displayString.contains("⇧"))
        XCTAssertTrue(displayString.contains("]"))
    }
    
    // MARK: - Video Settings Tests
    
    func testVideoSettingsPersistence() {
        settings.videoResolution = "1080p"
        settings.videoFrameRate = 60
        settings.videoBitrate = 10000000 // 10 Mbps
        settings.videoCodec = "H.265"
        settings.videoFormat = "MOV"
        
        XCTAssertEqual(UserDefaults.standard.string(forKey: "videoResolution"), "1080p")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "videoFrameRate"), 60)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "videoBitrate"), 10000000)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "videoCodec"), "H.265")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "videoFormat"), "MOV")
    }
    
    func testVideoBitrateStringConversion() {
        settings.videoBitrate = 5000000 // 5 Mbps
        
        let bitrateString = settings.videoBitrateString
        XCTAssertTrue(bitrateString.contains("Mbps") || bitrateString.contains("5"))
        
        // Test setting from string
        settings.videoBitrateString = "10 Mbps"
        XCTAssertEqual(settings.videoBitrate, 10000000)
        
        settings.videoBitrateString = "5000 kbps"
        XCTAssertEqual(settings.videoBitrate, 5000000)
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() {
        // Change some values
        settings.fileNameTemplate = "Custom"
        settings.videoResolution = "720p"
        settings.videoFrameRate = 60
        
        // Reset
        settings.resetToDefaults()
        
        // Verify defaults
        XCTAssertEqual(settings.fileNameTemplate, "Screenshot-{datetime}")
        XCTAssertEqual(settings.videoResolution, "Source")
        XCTAssertEqual(settings.videoFrameRate, 30)
    }
    
    // MARK: - Save Screenshot Tests
    
    func testSaveScreenshot() {
        let testImage = TestHelpers.createTestImage()
        let savedURL = settings.saveScreenshot(testImage)
        
        XCTAssertNotNil(savedURL)
        if let url = savedURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func testSaveScreenshotCreatesDirectory() {
        let customDirectory = testDirectory.appendingPathComponent("Custom Screenshots")
        settings.saveDirectory = customDirectory
        
        let testImage = TestHelpers.createTestImage()
        let savedURL = settings.saveScreenshot(testImage)
        
        XCTAssertNotNil(savedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: customDirectory.path))
        
        // Clean up
        if let url = savedURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Save Video Tests
    
    func testSaveVideo() {
        // Create a dummy video file for testing
        let videoURL = testDirectory.appendingPathComponent("test_video.mp4")
        let testData = Data("test video content".utf8)
        
        do {
            try testData.write(to: videoURL)
            
            let savedURL = settings.saveVideo(videoURL)
            
            XCTAssertNotNil(savedURL)
            if let url = savedURL {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
            }
        } catch {
            XCTFail("Failed to create test video file: \(error)")
        }
    }
}

#endif

