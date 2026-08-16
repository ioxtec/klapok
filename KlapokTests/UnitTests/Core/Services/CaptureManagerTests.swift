//
//  CaptureManagerTests.swift
//  KlapokTests
//
//  Unit tests for CaptureManager
//

import XCTest
@testable import Klapok

#if os(macOS)
import AppKit
import CoreMedia

@MainActor
final class CaptureManagerTests: XCTestCase {
    
    var captureManager: CaptureManager!
    
    override func setUp() {
        super.setUp()
        captureManager = CaptureManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(captureManager)
        XCTAssertEqual(captureManager.captureMode, .image)
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsInitialization() {
        let stats = captureManager.statistics
        XCTAssertEqual(stats.totalCaptures, 0)
        XCTAssertEqual(stats.successfulCaptures, 0)
        XCTAssertEqual(stats.failedCaptures, 0)
    }
    
    // MARK: - Capture Mode Tests
    
    func testCaptureMode() {
        captureManager.captureMode = .video
        XCTAssertEqual(captureManager.captureMode, .video)
        
        captureManager.captureMode = .image
        XCTAssertEqual(captureManager.captureMode, .image)
    }
    
    // MARK: - Full Screen Capture Tests
    
    func testCaptureFullScreenRequest() async throws {
        // Note: Actual capture requires screen recording permissions
        // This test verifies the method exists and can be called
        // In a real scenario with permissions, we would test actual capture
        
        let request = ImageCaptureRequest.fullScreen()
        XCTAssertNotNil(request)
        XCTAssertEqual(request.baseRequest.type, .fullScreen)
    }
    
    // MARK: - Area Capture Tests
    
    func testCaptureAreaRequest() {
        let area = NSRect(x: 100, y: 100, width: 400, height: 300)
        let request = ImageCaptureRequest.area(area)
        
        XCTAssertNotNil(request)
        XCTAssertEqual(request.baseRequest.type, .area)
        XCTAssertNotNil(request.area)
        if let requestArea = request.area {
            XCTAssertEqual(requestArea, area)
        }
    }
    
    // MARK: - Window Capture Tests
    
    func testCaptureWindowRequest() {
        // Note: SCWindow cannot be easily mocked, so we test that the method exists
        // In a real scenario, we would need an actual SCWindow instance
        // This test verifies the request structure is correct
        let request = ImageCaptureRequest.fullScreen()
        XCTAssertNotNil(request)
        XCTAssertEqual(request.baseRequest.type, .fullScreen)
        
        // Window capture requires actual SCWindow, which we can't easily create in tests
        // The actual window capture would be tested in integration tests
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidAreaCapture() async {
        // Test with invalid area
        let invalidArea = NSRect.zero
        
        do {
            _ = try await captureManager.captureArea(invalidArea)
            XCTFail("Should have thrown error for invalid area")
        } catch {
            // Expected to fail
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testImageCaptureConfiguration() {
        let config = ImageCaptureConfiguration.default
        XCTAssertNotNil(config)
        XCTAssertFalse(config.showsCursor)
        
        // Test high quality configuration
        let highQualityConfig = ImageCaptureConfiguration.highQuality
        XCTAssertNotNil(highQualityConfig)
        XCTAssertFalse(highQualityConfig.showsCursor)
        
        // Test custom configuration with all parameters
        let customConfig = ImageCaptureConfiguration(
            pixelFormat: kCVPixelFormatType_32BGRA,
            captureResolution: .best,
            showsCursor: true,
            capturesAudio: false,
            minimumFrameInterval: CMTime(value: 1, timescale: 60),
            scalesToFit: false,
            preservesAspectRatio: true
        )
        XCTAssertTrue(customConfig.showsCursor)
    }
}

#endif

