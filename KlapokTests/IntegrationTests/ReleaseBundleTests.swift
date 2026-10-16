import XCTest
@testable import Klapok

final class ReleaseBundleTests: XCTestCase {
    func testBundleUsesNewIdentityAndOnlyMacOS() throws {
        let id = try XCTUnwrap(Bundle.main.bundleIdentifier)
        XCTAssertTrue(id == "com.ioxtec.klapok" || id.hasPrefix("com.ioxtec.klapok.reviewtests"))
        XCTAssertEqual(Bundle.main.infoDictionary?["CFBundleSupportedPlatforms"] as? [String], ["MacOSX"])
        XCTAssertFalse((Bundle.main.object(forInfoDictionaryKey: "NSScreenCaptureDescription") as? String ?? "").isEmpty)
    }

    func testPrivacyManifestIsBundledWithRequiredReasons() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        let items = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = items.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        let files = items.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryFileTimestamp" }
        XCTAssertEqual(files?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["C617.1", "3B52.1"])
    }

    func testOnlyCompleteReleaseLanguagesAreBundled() {
        let supported = Set(AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue))
        let bundled = Set(Bundle.main.localizations).subtracting(["Base"])
        XCTAssertEqual(bundled, supported)
    }
}
