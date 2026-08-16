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
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Editor Display Tests
    
    func testEditorOpens() throws {
        throw XCTSkip("Editor UI needs a launch argument or fixture image to open the editor deterministically.")
    }
    
    // MARK: - Save Tests
    
    func testSaveButton() throws {
        throw XCTSkip("Save UI needs a deterministic editor fixture image before it can be tested safely.")
    }
    
    // MARK: - Settings Tests
    
    func testBackgroundSettings() throws {
        throw XCTSkip("Background UI needs a deterministic editor fixture image before it can be tested safely.")
    }
}







