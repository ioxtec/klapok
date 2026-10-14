//
//  ExportManagerTests.swift
//  KlapokTests
//
//  Unit tests for ExportManager
//

import XCTest
@testable import Klapok

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

    func testNewEditorResetsInheritedScalingWithoutChangingAudio() {
        exportManager.settings.videoSettings.scaling = .custom
        exportManager.settings.videoSettings.customScaleFactor = 1.25
        exportManager.settings.videoSettings.audioOption = .mute
        exportManager.resetVideoScalingForNewEditor()
        XCTAssertEqual(exportManager.settings.videoSettings.scaling, .original)
        XCTAssertEqual(exportManager.settings.videoSettings.customScaleFactor, 1)
        XCTAssertEqual(exportManager.settings.videoSettings.audioOption, .mute)
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

    func testVideoSettingUpdatesDoNotResetOtherVideoOptions() {
        exportManager.updateVideoQuality(.maximum)
        exportManager.updateVideoScaling(.custom)
        exportManager.updateCustomScaleFactor(1.25)
        exportManager.updateAudioOption(.mute)

        XCTAssertEqual(exportManager.settings.videoSettings.quality, .maximum)
        XCTAssertEqual(exportManager.settings.videoSettings.scaling, .custom)
        XCTAssertEqual(exportManager.settings.videoSettings.customScaleFactor, 1.25)
        XCTAssertEqual(exportManager.settings.videoSettings.audioOption, .mute)
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

    func testUpdateGIFMaintainAspectRatio() {
        exportManager.updateGIFMaintainAspectRatio(false)
        XCTAssertFalse(exportManager.settings.gifSettings.maintainAspectRatio)

        exportManager.updateGIFMaintainAspectRatio(true)
        XCTAssertTrue(exportManager.settings.gifSettings.maintainAspectRatio)
    }

    func testGIFSettingUpdatesDoNotResetOtherGIFOptions() {
        exportManager.updateGIFColorDepth(.colors32)
        exportManager.updateGIFFrameRate(24)
        exportManager.updateGIFMaxSize(width: 640, height: 360)
        exportManager.updateGIFMaintainAspectRatio(false)
        exportManager.updateGIFQuality(0.6)

        XCTAssertEqual(exportManager.settings.gifSettings.colorDepth, .colors32)
        XCTAssertEqual(exportManager.settings.gifSettings.frameRate, 24)
        XCTAssertEqual(exportManager.settings.gifSettings.maxWidth, 640)
        XCTAssertEqual(exportManager.settings.gifSettings.maxHeight, 360)
        XCTAssertFalse(exportManager.settings.gifSettings.maintainAspectRatio)
        XCTAssertEqual(exportManager.settings.gifSettings.quality, 0.6)
    }

    func testSetExportTypePreservesExistingExportSettings() {
        exportManager.updateVideoQuality(.maximum)
        exportManager.updateGIFFrameRate(12)

        exportManager.setExportType(.gif)
        exportManager.setExportType(.video)

        XCTAssertEqual(exportManager.settings.videoSettings.quality, .maximum)
        XCTAssertEqual(exportManager.settings.gifSettings.frameRate, 12)
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
