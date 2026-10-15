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
        app.launchArguments = ["-UITests", "-UITestOpenImageEditor", "-AppleLanguages", "(en)", "-app_language", "en"]
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

    func testPolishBackgroundPickerFitsSidebar() throws {
        app.terminate()
        app.launchArguments = ["-UITests", "-UITestOpenImageEditor", "-AppleLanguages", "(pl)", "-app_language", "pl"]
        app.launch()
        let picker = app.descendants(matching: .any)["editor.backgroundType"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Tło")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Profile")).firstMatch.exists)
        let none = picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Brak")).firstMatch
        XCTAssertTrue(none.exists)
        XCTAssertGreaterThan(none.frame.width, 0)
        XCTAssertLessThanOrEqual(none.frame.maxX, picker.frame.maxX + 1)
        none.click()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    func testEditorScreenshot() throws {
        XCTAssertTrue(app.buttons["editor.crop"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}







