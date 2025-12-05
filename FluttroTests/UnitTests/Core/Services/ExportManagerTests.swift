//
//  ExportManagerTests.swift
//  FluttroTests
//
//  Unit tests for ExportManager
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

final class ExportManagerTests: XCTestCase {
    
    var exportManager: ExportManager!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTempDirectory()
        exportManager = ExportManager(forPreview: true)
    }
    
    override func tearDown() {
        if let testDirectory = testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(exportManager.settings)
    }
    
    // MARK: - Export Type Tests
    
    func testSetExportType() {
        exportManager.setExportType(.video)
        XCTAssertEqual(exportManager.settings.exportType, .video)
        
        exportManager.setExportType(.gif)
        XCTAssertEqual(exportManager.settings.exportType, .gif)
    }
    
    // MARK: - Video Settings Tests
    
    func testUpdateVideoQuality() {
        let quality = VideoQuality.high
        exportManager.updateVideoQuality(quality)
        XCTAssertEqual(exportManager.settings.videoSettings.quality, quality)
    }
    
    func testUpdateVideoScaling() {
        let scaling = VideoScaling.custom
        exportManager.updateVideoScaling(scaling)
        XCTAssertEqual(exportManager.settings.videoSettings.scaling, scaling)
    }
    
    func testUpdateCustomScaleFactor() {
        let factor: Double = 0.75
        exportManager.updateCustomScaleFactor(factor)
        XCTAssertEqual(exportManager.settings.videoSettings.customScaleFactor, factor)
    }
    
    func testUpdateAudioOption() {
        let option = AudioExportOption.include
        exportManager.updateAudioOption(option)
        XCTAssertEqual(exportManager.settings.videoSettings.audioOption, option)
    }
    
    // MARK: - GIF Settings Tests
    
    func testUpdateGIFColorDepth() {
        let depth = GIFColorDepth.colors256
        exportManager.updateGIFColorDepth(depth)
        XCTAssertEqual(exportManager.settings.gifSettings.colorDepth, depth)
    }
    
    func testUpdateGIFFrameRate() {
        let fps = 15
        exportManager.updateGIFFrameRate(fps)
        XCTAssertEqual(exportManager.settings.gifSettings.frameRate, fps)
    }
    
    func testUpdateGIFMaxSize() {
        let width = 800
        let height = 600
        exportManager.updateGIFMaxSize(width: width, height: height)
        XCTAssertEqual(exportManager.settings.gifSettings.maxWidth, width)
        XCTAssertEqual(exportManager.settings.gifSettings.maxHeight, height)
    }
    
    func testUpdateGIFQuality() {
        let quality: Double = 0.8
        exportManager.updateGIFQuality(quality)
        XCTAssertEqual(exportManager.settings.gifSettings.quality, quality)
    }
    
    // MARK: - Persistence Tests
    
    func testSettingsPersistence() {
        // Note: ExportManager persistence uses Documents directory
        // In a real test, we would mock FileManager or use a test directory
        exportManager.updateVideoQuality(.high)
        exportManager.updateGIFFrameRate(20)
        
        // Settings should be updated
        XCTAssertEqual(exportManager.settings.videoSettings.quality, .high)
        XCTAssertEqual(exportManager.settings.gifSettings.frameRate, 20)
    }
}

#endif

