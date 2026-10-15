import XCTest
@testable import Klapok

@MainActor
final class ReleaseLocalizationTests: XCTestCase {
    func testMenuAndSettingsFollowSelectedLanguage() {
        let manager = LanguageManager.shared
        let previous = manager.selectedLanguage
        defer { manager.selectedLanguage = previous }
        manager.selectedLanguage = .polish
        XCTAssertEqual("Import Image…".localized, "Importuj obraz…")
        XCTAssertEqual(String(localized: "Import Video…"), "Importuj wideo…")
        XCTAssertEqual("General".localized, "Ogólne")
        XCTAssertEqual("Background".localized, "Tło")
        XCTAssertEqual("Profiles".localized, "Profile")
        XCTAssertEqual(String(format: "Loaded profiles: %ld".localized, 5), "Liczba profili: 5")
        XCTAssertEqual("Capture full screen".localized, "Zrób zrzut całego ekranu")
        manager.selectedLanguage = .english
        XCTAssertEqual("Import Image…".localized, "Import Image…")
        XCTAssertEqual("General".localized, "General")
    }
}
