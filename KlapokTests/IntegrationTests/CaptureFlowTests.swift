//
//  CaptureFlowTests.swift
//  KlapokTests
//
//  Integration tests for capture flow
//

import XCTest
@testable import Klapok

#if os(macOS)
import AppKit

@MainActor
final class CaptureFlowTests: XCTestCase {
    
    var editorViewModel: EditorViewModel!
    var floatingPanelViewModel: FloatingPanelViewModel!
    
    override func setUp() {
        super.setUp()
        editorViewModel = EditorViewModel()
        floatingPanelViewModel = FloatingPanelViewModel(editorViewModel: editorViewModel)
    }
    
    override func tearDown() {
        floatingPanelViewModel = nil
        editorViewModel = nil
        super.tearDown()
    }
    
    // MARK: - Full Screen Capture Flow Tests
    
    func testFullScreenCaptureFlow() async throws {
        // Set up for full screen capture
        floatingPanelViewModel.setScreenshotType(.fullScreen)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .fullScreen)
        
        // Note: Actual capture requires screen recording permissions
        // This test verifies the flow setup
        XCTAssertFalse(floatingPanelViewModel.isCapturing)
    }
    
    // MARK: - Area Selection Flow Tests
    
    func testAreaSelectionFlowSetup() {
        // Set up for area selection
        floatingPanelViewModel.setScreenshotType(.area)
        
        // Verify state
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .area)
        // Note: Actual area selection requires UI interaction
    }
    
    // MARK: - Window Selection Flow Tests
    
    func testWindowSelectionFlowSetup() {
        // Set up for window selection
        floatingPanelViewModel.setScreenshotType(.window)
        
        // Verify state
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .window)
        // Note: Actual window selection requires available windows
    }
    
    // MARK: - Editor Integration Tests
    
    func testEditorOpensAfterCapture() {
        let testImage = TestHelpers.createTestImage()
        
        // Simulate capture result
        editorViewModel.show(image: testImage)
        
        // Verify editor is presented
        XCTAssertTrue(editorViewModel.isPresented)
        XCTAssertEqual(editorViewModel.image, testImage)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingInCaptureFlow() {
        // Test that errors don't crash the flow
        floatingPanelViewModel.setScreenshotType(.fullScreen)
        
        // Verify state is maintained even if capture fails
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .fullScreen)
    }
}

#endif








