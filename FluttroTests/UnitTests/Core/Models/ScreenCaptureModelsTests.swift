//
//  ScreenCaptureModelsTests.swift
//  FluttroTests
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit
import CoreMedia

final class ScreenCaptureModelsTests: XCTestCase {
    func testVideoRecordingStateDisplayNames() {
        XCTAssertEqual(VideoRecordingState.idle.displayName, "Idle")
        XCTAssertEqual(VideoRecordingState.recording.displayName, "Recording")
    }

    func testCaptureRequestDefaultsToImageMode() {
        let request = CaptureRequest(type: .fullScreen)

        XCTAssertEqual(request.type, .fullScreen)
        XCTAssertEqual(request.mode, .image)
    }

    func testImageCaptureFullScreenFactory() {
        let request = ImageCaptureRequest.fullScreen(displayID: 42)

        XCTAssertEqual(request.baseRequest.type, .fullScreen)
        XCTAssertEqual(request.baseRequest.mode, .image)
        XCTAssertEqual(request.displayID, 42)
        XCTAssertNil(request.area)
        XCTAssertNil(request.window)
    }

    func testImageCaptureAreaFactory() {
        let area = NSRect(x: 10, y: 20, width: 300, height: 200)
        let request = ImageCaptureRequest.area(area)

        XCTAssertEqual(request.baseRequest.type, .area)
        XCTAssertEqual(request.area, area)
        XCTAssertNil(request.displayID)
    }

    func testImageCaptureConfigurations() {
        XCTAssertEqual(ImageCaptureConfiguration.default.pixelFormat, kCVPixelFormatType_32BGRA)
        XCTAssertEqual(ImageCaptureConfiguration.default.minimumFrameInterval, CMTime(value: 1, timescale: 60))
        XCTAssertFalse(ImageCaptureConfiguration.default.showsCursor)
        XCTAssertFalse(ImageCaptureConfiguration.default.capturesAudio)

        XCTAssertEqual(ImageCaptureConfiguration.highQuality.minimumFrameInterval, CMTime(value: 1, timescale: 120))
    }

    func testVideoCaptureConfigurationDefaults() {
        let configuration = VideoCaptureConfiguration.default

        XCTAssertEqual(configuration.frameRate, 30.0)
        XCTAssertEqual(configuration.bitRate, 5_000_000)
        XCTAssertEqual(configuration.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertTrue(configuration.capturesAudio)
        XCTAssertFalse(configuration.showsCursor)
    }

    func testCaptureStatisticsTracksSuccessAndFailure() {
        let initial = CaptureStatistics()
        XCTAssertEqual(initial.successRate, 0)

        let afterSuccess = initial.withNewCapture(success: true, duration: 0.2)
        XCTAssertEqual(afterSuccess.totalCaptures, 1)
        XCTAssertEqual(afterSuccess.successfulCaptures, 1)
        XCTAssertEqual(afterSuccess.failedCaptures, 0)
        XCTAssertEqual(afterSuccess.averageCaptureTime, 0.2, accuracy: 0.001)
        XCTAssertEqual(afterSuccess.successRate, 1.0)
        XCTAssertNotNil(afterSuccess.lastCaptureTime)

        let afterFailure = afterSuccess.withNewCapture(success: false, duration: 0.4)
        XCTAssertEqual(afterFailure.totalCaptures, 2)
        XCTAssertEqual(afterFailure.successfulCaptures, 1)
        XCTAssertEqual(afterFailure.failedCaptures, 1)
        XCTAssertEqual(afterFailure.averageCaptureTime, 0.3, accuracy: 0.001)
        XCTAssertEqual(afterFailure.successRate, 0.5)
    }

    func testCaptureResultStoresDataAndMetadata() {
        let metadata = CaptureMetadata(
            type: .area,
            mode: .image,
            area: NSRect(x: 1, y: 2, width: 3, height: 4),
            screenSize: CGSize(width: 800, height: 600),
            captureDuration: 0.12,
            configuration: "test"
        )
        let result = CaptureResult(data: "payload", metadata: metadata)

        XCTAssertEqual(result.data, "payload")
        XCTAssertEqual(result.metadata.type, .area)
        XCTAssertEqual(result.metadata.area, metadata.area)
        XCTAssertEqual(result.metadata.configuration, "test")
    }
}

#endif
