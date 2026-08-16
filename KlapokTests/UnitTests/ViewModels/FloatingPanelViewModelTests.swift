//
//  FloatingPanelViewModelTests.swift
//  KlapokTests
//
//  Unit tests for FloatingPanelViewModel
//

import XCTest
@testable import Klapok

#if os(macOS)
import AppKit

@MainActor
final class FloatingPanelViewModelTests: XCTestCase {
    
    var floatingPanelViewModel: FloatingPanelViewModel!
    var editorViewModel: EditorViewModel!
    
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
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(floatingPanelViewModel)
        XCTAssertEqual(floatingPanelViewModel.captureMode, .image)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .fullScreen)
        XCTAssertFalse(floatingPanelViewModel.isCapturing)
    }
    
    // MARK: - Screenshot Type Tests
    
    func testSetScreenshotType() {
        floatingPanelViewModel.setScreenshotType(.area)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .area)
        
        floatingPanelViewModel.setScreenshotType(.window)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .window)
    }
    
    // MARK: - Panel Visibility Tests
    
    func testHideFloatingPanel() {
        // Note: panelWindow is weak, so we can't easily test without actual window
        // This test verifies the method doesn't crash
        floatingPanelViewModel.hideFloatingPanel()
        XCTAssertNotNil(floatingPanelViewModel)
    }
    
    func testShowFloatingPanel() {
        // Note: panelWindow is weak, so we can't easily test without actual window
        // This test verifies the method doesn't crash
        floatingPanelViewModel.showFloatingPanel()
        XCTAssertNotNil(floatingPanelViewModel)
    }
    
    // MARK: - Area Selection Tests
    
    func testAreaSelectionState() {
        XCTAssertFalse(floatingPanelViewModel.isAreaSelectionActive)
        
        // Note: showAreaSelection() requires actual capture, so we test state management
        floatingPanelViewModel.isAreaSelectionActive = true
        XCTAssertTrue(floatingPanelViewModel.isAreaSelectionActive)
    }
    
    // MARK: - Window Selection Tests
    
    func testWindowSelectionState() {
        XCTAssertFalse(floatingPanelViewModel.isWindowSelectionActive)
        XCTAssertNil(floatingPanelViewModel.selectedWindow)
        
        // Note: showWindowSelection() requires actual windows, so we test state management
        floatingPanelViewModel.isWindowSelectionActive = true
        XCTAssertTrue(floatingPanelViewModel.isWindowSelectionActive)
    }
    
    // MARK: - Video Recording State Tests
    
    func testVideoRecordingState() {
        XCTAssertEqual(floatingPanelViewModel.videoRecordingState, .idle)
        XCTAssertEqual(floatingPanelViewModel.recordingDuration, 0.0)
    }
    
    func testFormattedRecordingDuration() {
        floatingPanelViewModel.recordingDuration = 125.0 // 2 minutes 5 seconds
        
        let formatted = floatingPanelViewModel.formattedRecordingDuration()
        XCTAssertEqual(formatted, "02:05")
    }
    
    // MARK: - Property Tests
    
    func testDefaultProperties() {
        XCTAssertEqual(floatingPanelViewModel.captureMode, .image)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .fullScreen)
        XCTAssertFalse(floatingPanelViewModel.isCapturing)
        XCTAssertFalse(floatingPanelViewModel.isAreaSelectionActive)
        XCTAssertFalse(floatingPanelViewModel.isWindowSelectionActive)
        XCTAssertEqual(floatingPanelViewModel.selectedArea, .zero)
        XCTAssertNil(floatingPanelViewModel.selectedWindow)
    }
    
    func testPropertyUpdates() {
        floatingPanelViewModel.captureMode = .video
        floatingPanelViewModel.screenshotType = .area
        floatingPanelViewModel.isDisplayPickerPresented = true
        floatingPanelViewModel.selectedArea = NSRect(x: 10, y: 20, width: 300, height: 200)
        
        XCTAssertEqual(floatingPanelViewModel.captureMode, .video)
        XCTAssertEqual(floatingPanelViewModel.screenshotType, .area)
        XCTAssertTrue(floatingPanelViewModel.isDisplayPickerPresented)
        XCTAssertEqual(floatingPanelViewModel.selectedArea, NSRect(x: 10, y: 20, width: 300, height: 200))
    }

    func testPinnedPanelLevelStaysAboveSelectionOverlays() {
        let manager = WindowDepthManager.shared
        let areaSelectionLevel = manager.level(for: .areaSelectionOverlay).rawValue
        let windowSelectionLevel = manager.level(for: .windowSelectionOverlay).rawValue
        let floatingPanelLevel = manager.level(for: .floatingPanel).rawValue
        let pinnedPanelLevel = manager.level(for: .pinnedFloatingPanel).rawValue

        XCTAssertGreaterThan(floatingPanelLevel, areaSelectionLevel)
        XCTAssertGreaterThan(floatingPanelLevel, windowSelectionLevel)
        XCTAssertGreaterThan(pinnedPanelLevel, floatingPanelLevel)
    }
}

#endif
