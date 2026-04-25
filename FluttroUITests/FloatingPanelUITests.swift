//
//  FloatingPanelUITests.swift
//  FluttroUITests
//
//  UI tests for floating panel
//

import XCTest

final class FloatingPanelUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-UITests",
            "-UITestResetSettings",
            "-UITestShowFloatingPanel",
            "-UITestDisableCaptureSideEffects"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Panel Display Tests
    
    func testFloatingPanelDisplays() throws {
        XCTAssertTrue(app.buttons["floatingPanel.primaryCapture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["floatingPanel.mode.image"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.mode.video"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.captureType.fullScreen"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.captureType.area"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.captureType.window"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.primaryCapture"].exists)
        XCTAssertTrue(app.buttons["floatingPanel.close"].exists)
    }
    
    // MARK: - Capture Type Selection Tests
    
    func testSwitchCaptureTypes() throws {
        XCTAssertTrue(app.buttons["floatingPanel.primaryCapture"].waitForExistence(timeout: 5))

        let fullScreen = app.buttons["floatingPanel.captureType.fullScreen"]
        let area = app.buttons["floatingPanel.captureType.area"]
        let window = app.buttons["floatingPanel.captureType.window"]

        XCTAssertEqual(fullScreen.value as? String, "selected")

        area.tap()
        XCTAssertEqual(area.value as? String, "selected")
        XCTAssertEqual(fullScreen.value as? String, "unselected")

        window.tap()
        XCTAssertEqual(window.value as? String, "selected")
        XCTAssertEqual(area.value as? String, "unselected")
    }
    
    // MARK: - Capture Button Tests
    
    func testCaptureButton() throws {
        XCTAssertTrue(app.buttons["floatingPanel.primaryCapture"].waitForExistence(timeout: 5))

        let captureButton = app.buttons["floatingPanel.primaryCapture"]
        XCTAssertTrue(captureButton.isEnabled)
        XCTAssertEqual(captureButton.value as? String, "ready")
    }

    func testSwitchCaptureModes() throws {
        XCTAssertTrue(app.buttons["floatingPanel.primaryCapture"].waitForExistence(timeout: 5))

        let imageMode = app.buttons["floatingPanel.mode.image"]
        let videoMode = app.buttons["floatingPanel.mode.video"]

        XCTAssertEqual(imageMode.value as? String, "selected")
        XCTAssertEqual(videoMode.value as? String, "unselected")

        videoMode.tap()
        XCTAssertEqual(videoMode.value as? String, "selected")
        XCTAssertEqual(imageMode.value as? String, "unselected")

        imageMode.tap()
        XCTAssertEqual(imageMode.value as? String, "selected")
        XCTAssertEqual(videoMode.value as? String, "unselected")
    }

}






