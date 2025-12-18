//
//  SettingsViewModelTests.swift
//  FluttroTests
//
//  Unit tests for SettingsViewModel
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class SettingsViewModelTests: XCTestCase {
    
    var settingsViewModel: SettingsViewModel!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTempDirectory()
        
        // Reset UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        settingsViewModel = SettingsViewModel()
    }
    
    override func tearDown() {
        if let testDirectory = testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(settingsViewModel.saveDirectory)
        XCTAssertNotNil(settingsViewModel.fileNameTemplate)
    }
    
    // MARK: - Property Synchronization Tests
    
    func testSaveDirectorySynchronization() {
        let newDirectory = testDirectory.appendingPathComponent("Test Screenshots")
        settingsViewModel.saveDirectory = newDirectory
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.saveDirectory, newDirectory)
    }
    
    func testFileNameTemplateSynchronization() {
        let template = "Custom-{datetime}"
        settingsViewModel.fileNameTemplate = template
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.fileNameTemplate, template)
    }
    
    func testHotkeyModifiersSynchronization() {
        let modifiers: NSEvent.ModifierFlags = [.command, .option]
        settingsViewModel.hotkeyModifiers = modifiers
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.hotkeyModifiers, modifiers)
    }
    
    func testHotkeyKeyCodeSynchronization() {
        let keyCode: UInt16 = 0x1A
        settingsViewModel.hotkeyKeyCode = keyCode
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.hotkeyKeyCode, keyCode)
    }
    
    func testShowInDockSynchronization() {
        settingsViewModel.showInDock = false
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.showInDock, false)
    }
    
    func testLaunchAtLoginSynchronization() {
        settingsViewModel.launchAtLogin = true
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.launchAtLogin, true)
    }
    
    // MARK: - Computed Properties Tests
    
    func testHotkeyDisplayString() {
        settingsViewModel.hotkeyModifiers = [.command, .shift]
        settingsViewModel.hotkeyKeyCode = 0x1A // ]
        
        let displayString = settingsViewModel.hotkeyDisplayString
        XCTAssertTrue(displayString.contains("⌘"))
        XCTAssertTrue(displayString.contains("⇧"))
    }
    
    func testPreviewFileName() {
        settingsViewModel.fileNameTemplate = "Test-{datetime}"
        let preview = settingsViewModel.previewFileName
        
        // Should contain "Test-" prefix and ".png" extension
        XCTAssertTrue(preview.hasPrefix("Test-"))
        XCTAssertTrue(preview.hasSuffix(".png"))
    }
}

#endif



