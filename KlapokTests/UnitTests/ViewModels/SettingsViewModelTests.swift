//
//  SettingsViewModelTests.swift
//  KlapokTests
//
//  Unit tests for SettingsViewModel
//

import XCTest
@testable import Klapok

#if os(macOS)
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
    
    func testShowInDockSynchronization() {
        settingsViewModel.showInDock = false
        
        // Should sync with AppSettings
        XCTAssertEqual(AppSettings.shared.showInDock, false)
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







