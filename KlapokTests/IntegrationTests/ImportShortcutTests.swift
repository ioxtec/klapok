import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Klapok

final class ImportShortcutTests: XCTestCase {
    private var saved: [String: Any] = [:]
    private var keys: [String] {
        KeyboardShortcutAction.allCases.flatMap { action in
            ["keyboardShortcut.\(action.rawValue).keyCode", "keyboardShortcut.\(action.rawValue).modifiers"]
        }
    }

    override func setUp() {
        for key in keys {
            saved[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys { UserDefaults.standard.set(saved[key], forKey: key) }
        saved.removeAll()
    }

    func testDefaultsAreUniqueAndImportDoesNotRequestCapture() {
        for action in KeyboardShortcutAction.allCases {
            XCTAssertNil(KeyboardShortcutAction.conflictingAction(for: action.defaultShortcut, excluding: action))
        }
        XCTAssertEqual(KeyboardShortcutAction.importImage.shortcut.keyEquivalent, "i")
        XCTAssertEqual(KeyboardShortcutAction.importVideo.shortcut.keyEquivalent, "v")
        XCTAssertNil(KeyboardShortcutAction.importImage.captureType)
        XCTAssertNil(KeyboardShortcutAction.importVideo.captureType)
    }

    func testImportCustomizationPersistsAndResets() {
        let action = KeyboardShortcutAction.importImage
        let custom = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_M), modifiers: [.control, .option])
        action.setShortcut(custom)
        XCTAssertEqual(action.shortcut, custom)
        XCTAssertEqual(action.shortcut.keyEquivalent, "m")
        XCTAssertEqual(action.shortcut.carbonModifiers, UInt32(controlKey | optionKey))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "keyboardShortcut.301.keyCode"), Int(kVK_ANSI_M))
        action.resetShortcut()
        XCTAssertEqual(action.shortcut, action.defaultShortcut)
    }

    func testConflictDetectionIncludesCaptureAndImport() {
        XCTAssertEqual(KeyboardShortcutAction.conflictingAction(
            for: KeyboardShortcutAction.screenshotArea.shortcut, excluding: .importImage), .screenshotArea)
        XCTAssertEqual(KeyboardShortcutAction.conflictingAction(
            for: KeyboardShortcutAction.importVideo.shortcut, excluding: .importImage), .importVideo)
        KeyboardShortcutAction.importVideo.setShortcut(.init(keyCode: UInt32(kVK_ANSI_Z), modifiers: [.command, .control]))
        KeyboardShortcutAction.resetAllShortcuts()
        XCTAssertEqual(KeyboardShortcutAction.importVideo.shortcut, KeyboardShortcutAction.importVideo.defaultShortcut)
    }
}
