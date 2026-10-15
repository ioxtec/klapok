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
        let url = try XCTUnwrap(Bundle.main.url(forResource: "KlapokPaper", withExtension: "icns"))
        let image = try XCTUnwrap(NSImage(contentsOf: url))
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
