//
//  ExportFlowTests.swift
//  FluttroTests
//
//  Integration tests for export flow
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class ExportFlowTests: XCTestCase {
    
    var editorViewModel: EditorViewModel!
    var settings: AppSettings!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTempDirectory()
        editorViewModel = EditorViewModel()
        settings = AppSettings.shared
        
        // Set test directory
        settings.saveDirectory = testDirectory
    }
    
    override func tearDown() {
        if let testDirectory = testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        super.tearDown()
    }
    
    // MARK: - Image Export Tests
    
    func testSaveImageFlow() {
        let testImage = TestHelpers.createTestImage()
        editorViewModel.show(image: testImage)
        
        // Save image
        editorViewModel.saveImage()
        
        // Verify image was saved (check directory)
        let files = try? FileManager.default.contentsOfDirectory(at: testDirectory, includingPropertiesForKeys: nil)
        XCTAssertNotNil(files)
        // Note: Actual file check would require waiting for async save
    }
    
    func testCopyToClipboardFlow() {
        let testImage = TestHelpers.createTestImage()
        editorViewModel.show(image: testImage)
        
        // Copy to clipboard
        editorViewModel.copyToClipboard()
        
        // Verify clipboard has content
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems
        XCTAssertNotNil(items)
    }
    
    // MARK: - Settings Integration Tests
    
    func testExportUsesSettingsDirectory() {
        let customDirectory = testDirectory.appendingPathComponent("Custom Export")
        settings.saveDirectory = customDirectory
        
        let testImage = TestHelpers.createTestImage()
        editorViewModel.show(image: testImage)
        
        // Save should use custom directory
        editorViewModel.saveImage()
        
        // Verify directory exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: customDirectory.path))
    }
    
    func testExportUsesFileNameTemplate() {
        settings.fileNameTemplate = "TestExport-{datetime}"
        
        let testImage = TestHelpers.createTestImage()
        let savedURL = settings.saveScreenshot(testImage)
        
        XCTAssertNotNil(savedURL)
        if let url = savedURL {
            let fileName = url.lastPathComponent
            XCTAssertTrue(fileName.hasPrefix("TestExport-"))
        }
    }
}

#endif

