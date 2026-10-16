//
//  SettingsUITests.swift
//  KlapokUITests
//
//  UI tests for settings
//

import XCTest

final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-UITests",
            "-UITestResetSettings",
            "-UITestOpenSettings",
            "-app_language", "en"
        ]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Settings Window Tests
    
    func testSettingsWindowOpens() throws {
        XCTAssertTrue(app.windows["Klapok Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("settings.title").exists)
    }
    
    // MARK: - General Settings Tests
    
    func testGeneralSettings() throws {
        XCTAssertTrue(app.windows["Klapok Settings"].waitForExistence(timeout: 5))

        app.buttons["settings.tab.general"].click()

        XCTAssertTrue(element("settings.content.general").waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["settings.tab.general"].value as? String, "selected")
        XCTAssertTrue(app.staticTexts["Screen Recording"].exists)
        XCTAssertFalse(app.staticTexts["Accessibility"].exists)
    }
    
    // MARK: - Image Settings Tests
    
    func testImageSettings() throws {
        XCTAssertTrue(app.windows["Klapok Settings"].waitForExistence(timeout: 5))

        app.buttons["settings.tab.image"].click()

        XCTAssertTrue(element("settings.content.image").waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["settings.tab.image"].value as? String, "selected")
    }
    
    // MARK: - Video Settings Tests
    
    func testVideoSettings() throws {
        XCTAssertTrue(app.windows["Klapok Settings"].waitForExistence(timeout: 5))

        app.buttons["settings.tab.video"].click()

        XCTAssertTrue(element("settings.content.video").waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["settings.tab.video"].value as? String, "selected")
    }

    func testKeyboardShortcutsSettings() throws {
        XCTAssertTrue(app.windows["Klapok Settings"].waitForExistence(timeout: 5))

        app.buttons["settings.tab.shortcuts"].click()

        XCTAssertTrue(element("settings.content.shortcuts").waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["settings.tab.shortcuts"].value as? String, "selected")
        XCTAssertTrue(element("settings.shortcut.301").exists)
        XCTAssertTrue(element("settings.shortcut.302").exists)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}






