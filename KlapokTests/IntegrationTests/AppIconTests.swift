import AppKit
import XCTest
@testable import Klapok

final class AppIconTests: XCTestCase {
    func testAppUsesCompiledPaperIcon() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
                       "KlapokPaper")
        let url = try XCTUnwrap(Bundle.main.url(forResource: "KlapokPaper", withExtension: "icns"))
        XCTAssertNotNil(NSImage(contentsOf: url))
    }

    func testCompiledIconHasTransparentCornersAndOpaqueCenter() throws {
        for choice in AppIconChoice.allCases {
            try assertSystemMask(for: choice)
        }
    }

    private func assertSystemMask(for choice: AppIconChoice) throws {
        let image = try XCTUnwrap(choice.image(), choice.resourceName)
        let bitmap = try XCTUnwrap(image.representations.compactMap { $0 as? NSBitmapImageRep }
            .max { $0.pixelsWide < $1.pixelsWide })
        XCTAssertTrue(bitmap.hasAlpha)
        let width = bitmap.pixelsWide, height = bitmap.pixelsHigh
        for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent, 0.01)
        }
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: width / 2, y: height / 2)).alphaComponent, 0.99)
    }
}

@MainActor
final class AppIconPreferenceTests: XCTestCase {
    private func withDefaults(_ test: (UserDefaults) throws -> Void) rethrows {
        let suite = "AppIconTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try test(defaults)
    }

    func testMissingAndUnknownPreferencesUseDefault() {
        withDefaults { defaults in
            var changes = 0
            let manager = AppIconManager(defaults: defaults, applyImage: { _ in changes += 1 })
            XCTAssertEqual(manager.selection, .roostersLight)
            XCTAssertEqual(changes, 0)
            defaults.set("removed-icon", forKey: AppIconManager.preferenceKey)
            XCTAssertEqual(AppIconManager(defaults: defaults, applyImage: { _ in }).selection, .roostersLight)
        }
    }

    func testSelectionIsAppliedPersistedAndRestoredOnLaunch() throws {
        try withDefaults { defaults in
            var applied: NSImage?
            let image = NSImage(size: NSSize(width: 32, height: 32))
            let manager = AppIconManager(defaults: defaults, imageProvider: { _ in image }, applyImage: { applied = $0 })
            for choice in AppIconChoice.allCases where choice != .roostersLight {
                XCTAssertTrue(manager.select(choice))
                XCTAssertTrue(applied === image)
                XCTAssertEqual(manager.selection, choice)
                XCTAssertEqual(defaults.string(forKey: AppIconManager.preferenceKey), choice.rawValue)
                applied = nil
                let relaunched = AppIconManager(defaults: defaults, imageProvider: { _ in image }, applyImage: { applied = $0 })
                relaunched.applySavedIcon()
                XCTAssertEqual(relaunched.selection, choice)
                XCTAssertTrue(try XCTUnwrap(applied) === image)
            }
            XCTAssertTrue(manager.select(.roostersLight))
            XCTAssertNil(applied)
            XCTAssertEqual(defaults.string(forKey: AppIconManager.preferenceKey), AppIconChoice.roostersLight.rawValue)
        }
    }

    func testMissingResourceDoesNotChangeSelectionOrPreference() {
        withDefaults { defaults in
            var changes = 0
            let manager = AppIconManager(defaults: defaults, imageProvider: { _ in nil }, applyImage: { _ in changes += 1 })
            XCTAssertFalse(manager.select(.flowerDark))
            XCTAssertEqual(manager.selection, .roostersLight)
            XCTAssertNil(defaults.string(forKey: AppIconManager.preferenceKey))
            XCTAssertEqual(changes, 0)
        }
    }

    func testUnavailableSavedIconRestoresPrimaryIcon() {
        withDefaults { defaults in
            defaults.set(AppIconChoice.flowerDark.rawValue, forKey: AppIconManager.preferenceKey)
            var restored = false
            let manager = AppIconManager(defaults: defaults, imageProvider: { _ in nil }, applyImage: { restored = $0 == nil })
            manager.applySavedIcon()
            XCTAssertTrue(restored)
            XCTAssertEqual(manager.selection, .roostersLight)
            XCTAssertEqual(defaults.string(forKey: AppIconManager.preferenceKey), AppIconChoice.roostersLight.rawValue)
        }
    }

    func testPublicDockAPIUpdatesRunningAppIcon() {
        withDefaults { defaults in
            let previous = NSApp.applicationIconImage
            defer { NSApp.applicationIconImage = previous }
            let manager = AppIconManager(defaults: defaults)
            for choice in AppIconChoice.allCases {
                XCTAssertTrue(manager.select(choice))
                XCTAssertNotNil(NSApp.applicationIconImage)
            }
        }
    }
}
