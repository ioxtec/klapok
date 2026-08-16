//
//  ExportModelsTests.swift
//  KlapokTests
//

import XCTest
@testable import Klapok

final class ExportModelsTests: XCTestCase {
    func testVideoQualityBitrates() {
        XCTAssertEqual(VideoQuality.low.bitrate, 1_000_000)
        XCTAssertEqual(VideoQuality.medium.bitrate, 3_000_000)
        XCTAssertEqual(VideoQuality.high.bitrate, 5_000_000)
        XCTAssertEqual(VideoQuality.veryHigh.bitrate, 10_000_000)
        XCTAssertEqual(VideoQuality.maximum.bitrate, 20_000_000)
    }

    func testVideoScalingFactors() {
        XCTAssertEqual(VideoScaling.original.scaleFactor, 1.0)
        XCTAssertEqual(VideoScaling.scale50.scaleFactor, 0.5)
        XCTAssertEqual(VideoScaling.scale75.scaleFactor, 0.75)
        XCTAssertEqual(VideoScaling.scale125.scaleFactor, 1.25)
        XCTAssertEqual(VideoScaling.scale150.scaleFactor, 1.5)
        XCTAssertEqual(VideoScaling.scale200.scaleFactor, 2.0)
        XCTAssertEqual(VideoScaling.custom.scaleFactor, 1.0)
    }

    func testGIFColorDepthCounts() {
        XCTAssertEqual(GIFColorDepth.colors16.colorCount, 16)
        XCTAssertEqual(GIFColorDepth.colors32.colorCount, 32)
        XCTAssertEqual(GIFColorDepth.colors64.colorCount, 64)
        XCTAssertEqual(GIFColorDepth.colors128.colorCount, 128)
        XCTAssertEqual(GIFColorDepth.colors256.colorCount, 256)
    }

    func testDefaultExportSettings() {
        let settings = ExportSettings()

        XCTAssertEqual(settings.exportType, .video)
        XCTAssertEqual(settings.videoSettings.quality, .high)
        XCTAssertEqual(settings.videoSettings.scaling, .original)
        XCTAssertEqual(settings.videoSettings.audioOption, .include)
        XCTAssertTrue(settings.videoSettings.includeSystemAudio)
        XCTAssertTrue(settings.videoSettings.includeMicrophone)
        XCTAssertTrue(settings.videoSettings.maintainAspectRatio)
        XCTAssertEqual(settings.gifSettings.colorDepth, .colors256)
        XCTAssertEqual(settings.gifSettings.frameRate, 15)
        XCTAssertEqual(settings.gifSettings.loopMode, .infinite)
    }

    func testGIFExportSettingsDecodesMissingFieldsWithDefaults() throws {
        let payload = """
        {
          "frameRate": 24,
          "maxWidth": 1024
        }
        """

        let settings = try JSONDecoder().decode(GIFExportSettings.self, from: Data(payload.utf8))

        XCTAssertEqual(settings.frameRate, 24)
        XCTAssertEqual(settings.maxWidth, 1024)
        XCTAssertEqual(settings.colorDepth, .colors256)
        XCTAssertEqual(settings.frameFormat, .optimized)
        XCTAssertEqual(settings.loopMode, .infinite)
        XCTAssertEqual(settings.dithering, .floydSteinberg)
        XCTAssertEqual(settings.maxHeight, 600)
        XCTAssertTrue(settings.maintainAspectRatio)
        XCTAssertEqual(settings.quality, 0.8)
        XCTAssertTrue(settings.optimizeForWeb)
        XCTAssertFalse(settings.includeMetadata)
    }
}
