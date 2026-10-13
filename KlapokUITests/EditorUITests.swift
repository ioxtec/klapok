//
//  EditorUITests.swift
//  KlapokUITests
//
//  UI tests for editor
//

import XCTest

final class EditorUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITests", "-UITestOpenImageEditor", "-AppleLanguages", "(en)"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Editor Display Tests
    
    func testEditorOpens() throws {
        XCTAssertTrue(app.buttons["editor.crop"].waitForExistence(timeout: 5))
    }
    
    // MARK: - Save Tests
    
    func testCropSheetAppliesAndCloses() throws {
        XCTAssertTrue(app.buttons["editor.crop"].waitForExistence(timeout: 5))
        app.buttons["editor.crop"].click()
        XCTAssertTrue(app.buttons["editor.applyCrop"].waitForExistence(timeout: 3))
        app.buttons["editor.applyCrop"].click()
        XCTAssertTrue(app.buttons["editor.crop"].waitForExistence(timeout: 3))
    }
    
    // MARK: - Settings Tests
    
    func testEditorScreenshot() throws {
        XCTAssertTrue(app.buttons["editor.crop"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}







