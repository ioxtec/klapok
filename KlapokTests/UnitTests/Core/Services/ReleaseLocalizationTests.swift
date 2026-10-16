import XCTest
@testable import Klapok

@MainActor
final class ReleaseLocalizationTests: XCTestCase {
    func testAllSupportedLanguagesAreBundledAndSwitchable() {
        let expected: [(AppLanguage, String)] = [
            (.english, "General"), (.polish, "Ogólne"),
            (.german, "Allgemein"), (.french, "Général"),
            (.spanish, "General"), (.italian, "Generali"),
            (.portugueseBrazil, "Geral"), (.japanese, "一般"),
            (.korean, "일반"), (.simplifiedChinese, "通用"),
            (.traditionalChinese, "一般")
        ]
        let manager = LanguageManager.shared
        let previous = manager.selectedLanguage
        defer { manager.selectedLanguage = previous }
        XCTAssertEqual(AppLanguage.allCases.count, expected.count + 1)
        for (language, general) in expected {
            manager.selectedLanguage = language
            XCTAssertEqual(manager.currentLanguage, language.rawValue)
            XCTAssertNotNil(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"))
            XCTAssertNotNil(Bundle.localizedBundle)
            XCTAssertEqual("General".localized, general, language.rawValue)
            if language != .english {
                XCTAssertNotEqual("Background blur".localized, "Background blur", language.rawValue)
                XCTAssertNotEqual("Import Image…".localized, "Import Image…", language.rawValue)
            }
            XCTAssertTrue(String(format: "Loaded profiles: %ld".localized, 5).contains("5"))
            XCTAssertEqual("app_name".localized, "Klapok — Capture, Polish, Share")
        }
    }

    func testSystemLanguageResolvesToSupportedLocalization() {
        let manager = LanguageManager.shared
        let previous = manager.selectedLanguage
        defer { manager.selectedLanguage = previous }
        manager.selectedLanguage = .system
        XCTAssertTrue(AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue).contains(manager.currentLanguage))
        XCTAssertNotNil(Bundle.localizedBundle)
    }

    func testMenuAndSettingsFollowSelectedLanguage() {
        let manager = LanguageManager.shared
        let previous = manager.selectedLanguage
        defer { manager.selectedLanguage = previous }
        manager.selectedLanguage = .polish
        XCTAssertEqual("Import Image…".localized, "Importuj obraz…")
        XCTAssertEqual("Import Video…".localized, "Importuj wideo…")
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
