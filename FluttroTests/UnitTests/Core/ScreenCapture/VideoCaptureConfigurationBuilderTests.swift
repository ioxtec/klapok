//
//  VideoCaptureConfigurationBuilderTests.swift
//  FluttroTests
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AVFoundation
import CoreMedia

@MainActor
final class VideoCaptureConfigurationBuilderTests: XCTestCase {
    private var settings: AppSettings!

    override func setUp() {
        super.setUp()
        settings = AppSettings.shared
        settings.resetToDefaults()
    }

    override func tearDown() {
        settings.resetToDefaults()
        settings = nil
        super.tearDown()
    }

    func testStreamSettingsUseSourceSizeAndBehaviorFlags() {
        settings.videoResolution = "Source"
        settings.videoFrameRate = 60
        settings.showMouseCursor = true
        settings.recordSystemAudio = true

        let result = VideoCaptureConfigurationBuilder.streamSettings(
            sourceSize: CGSize(width: 1512, height: 982),
            settings: settings
        )

        XCTAssertEqual(result.outputSize, CGSize(width: 1512, height: 982))
        XCTAssertEqual(result.minimumFrameInterval, CMTime(value: 1, timescale: 60))
        XCTAssertEqual(result.queueDepth, 5)
        XCTAssertTrue(result.showsCursor)
        XCTAssertTrue(result.capturesAudio)
    }

    func testStreamSettingsApplyPresetResolution() {
        settings.videoResolution = "720p"
        settings.videoFrameRate = 24

        let result = VideoCaptureConfigurationBuilder.streamSettings(
            sourceSize: CGSize(width: 3024, height: 1964),
            settings: settings
        )

        XCTAssertEqual(result.outputSize, CGSize(width: 1280, height: 720))
        XCTAssertEqual(result.minimumFrameInterval, CMTime(value: 1, timescale: 24))
    }

    func testWriterSettingsMapFormatCodecAndCompressionValues() throws {
        settings.videoFormat = "MOV"
        settings.videoCodec = "H.265"
        settings.videoBitrate = 8_000_000
        settings.videoFrameRate = 30

        let result = VideoCaptureConfigurationBuilder.writerSettings(
            outputSize: CGSize(width: 1920, height: 1080),
            settings: settings
        )

        XCTAssertEqual(result.fileType, .mov)
        XCTAssertEqual(result.codec, .hevc)
        XCTAssertEqual(result.videoSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(result.averageBitRate, 8_000_000)
        XCTAssertEqual(result.expectedSourceFrameRate, 30)
        XCTAssertEqual(result.maxKeyFrameInterval, 60)

        let outputSettings = result.outputSettings
        XCTAssertEqual(outputSettings[AVVideoCodecKey] as? AVVideoCodecType, .hevc)
        XCTAssertEqual(outputSettings[AVVideoWidthKey] as? Int, 1920)
        XCTAssertEqual(outputSettings[AVVideoHeightKey] as? Int, 1080)

        let compression = try XCTUnwrap(
            outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any]
        )
        XCTAssertEqual(compression[AVVideoAverageBitRateKey] as? Int, 8_000_000)
        XCTAssertEqual(compression[AVVideoExpectedSourceFrameRateKey] as? Int, 30)
        XCTAssertEqual(compression[AVVideoMaxKeyFrameIntervalKey] as? Int, 60)
        XCTAssertNil(compression[AVVideoH264EntropyModeKey], "HEVC should not carry H.264-only properties")
        XCTAssertNil(compression[AVVideoProfileLevelKey], "HEVC should not carry H.264 profile level")
    }

    func testWriterSettingsKeepH264SpecificPropertiesForH264() throws {
        settings.videoFormat = "MP4"
        settings.videoCodec = "H.264"
        settings.videoBitrate = 5_000_000
        settings.videoFrameRate = 25

        let result = VideoCaptureConfigurationBuilder.writerSettings(
            outputSize: CGSize(width: 1280, height: 720),
            settings: settings
        )

        XCTAssertEqual(result.fileType, .mp4)
        XCTAssertEqual(result.codec, .h264)

        let compression = try XCTUnwrap(
            result.outputSettings[AVVideoCompressionPropertiesKey] as? [String: Any]
        )
        XCTAssertEqual(compression[AVVideoAverageBitRateKey] as? Int, 5_000_000)
        XCTAssertEqual(compression[AVVideoExpectedSourceFrameRateKey] as? Int, 25)
        XCTAssertEqual(compression[AVVideoMaxKeyFrameIntervalKey] as? Int, 50)
        XCTAssertEqual(
            compression[AVVideoProfileLevelKey] as? String,
            AVVideoProfileLevelH264BaselineAutoLevel
        )
        XCTAssertEqual(
            compression[AVVideoH264EntropyModeKey] as? String,
            AVVideoH264EntropyModeCAVLC
        )
    }

    func testPixelBufferAttributesMatchResolvedOutputSize() {
        let result = VideoCaptureConfigurationBuilder.writerSettings(
            outputSize: CGSize(width: 854, height: 480),
            settings: settings
        )

        XCTAssertEqual(result.pixelBufferAttributes[kCVPixelBufferWidthKey as String] as? Int, 854)
        XCTAssertEqual(result.pixelBufferAttributes[kCVPixelBufferHeightKey as String] as? Int, 480)
        XCTAssertEqual(
            result.pixelBufferAttributes[kCVPixelBufferPixelFormatTypeKey as String] as? OSType,
            kCVPixelFormatType_32BGRA
        )
    }
}

#endif
