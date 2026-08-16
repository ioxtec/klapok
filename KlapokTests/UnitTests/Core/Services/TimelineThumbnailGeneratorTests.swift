//
//  TimelineThumbnailGeneratorTests.swift
//  KlapokTests
//

import XCTest
@testable import Klapok

#if os(macOS)

final class TimelineThumbnailGeneratorTests: XCTestCase {
    func testTargetCountUsesMinimumForNarrowTimelines() {
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 0), 6)
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 200), 6)
    }

    func testTargetCountScalesWithWidth() {
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 720), 10)
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 1440), 20)
    }

    func testTargetCountCapsAtMaximum() {
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 10_000), 36)
    }
}

#endif
