import XCTest
@testable import Klapok

final class SidebarNumericValueTests: XCTestCase {
    func testExactTypedPixelsAreNotRoundedToSliderStep() {
        XCTAssertEqual(SidebarNumericValue.committed("273", range: 0...1000), 273)
        XCTAssertEqual(SidebarNumericValue.snapped(273, range: 0...1000, step: 5), 275)
    }

    func testTypedValuesStayWithinSliderBounds() {
        XCTAssertEqual(SidebarNumericValue.committed("9999", range: 0...2000), 2000)
        XCTAssertEqual(SidebarNumericValue.committed("-20", range: 0...2000), 0)
        XCTAssertEqual(SidebarNumericValue.committed(" 102 ", range: 0...2000), 102)
    }

    func testDecimalSeparatorsAndDisplayUnits() {
        XCTAssertEqual(SidebarNumericValue.committed("1,75", range: 0.25...3, allowsFraction: true), 1.75)
        XCTAssertEqual(SidebarNumericValue.committed("1.75", range: 0.25...3, allowsFraction: true), 1.75)
        XCTAssertEqual(SidebarNumericValue.committed("37", range: 0.1...1,
            displayMultiplier: 100, allowsFraction: true), 0.37)
        XCTAssertEqual(SidebarNumericValue.committed("200", range: 0.1...1,
            displayMultiplier: 100, allowsFraction: true), 1)
    }

    func testInvalidInputIsRejectedWithoutChangingValue() {
        for text in ["", " ", "abc", "12px", "12.3.4", "NaN", "inf", "1e9999"] {
            XCTAssertNil(SidebarNumericValue.committed(text, range: 0...2000), text)
        }
    }

    func testFractionalSliderStepsAndEndpoints() {
        XCTAssertEqual(SidebarNumericValue.snapped(1.71, range: 0.25...3, step: 0.25), 1.75)
        XCTAssertEqual(SidebarNumericValue.snapped(-1, range: 0.25...3, step: 0.25), 0.25)
        XCTAssertEqual(SidebarNumericValue.snapped(5000, range: 0...2000, step: 5), 2000)
    }
}
