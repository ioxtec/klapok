//
//  CaptureErrorTests.swift
//  FluttroTests
//

import XCTest
@testable import Fluttro

#if os(macOS)

final class CaptureErrorTests: XCTestCase {
    func testErrorDescriptionsIncludeAssociatedValues() {
        XCTAssertEqual(
            CaptureError.notImplemented("HDR capture").errorDescription,
            "Feature not implemented: HDR capture"
        )
        XCTAssertEqual(
            CaptureError.invalidRequest("missing window").errorDescription,
            "Invalid request: missing window"
        )
    }

    func testRecoverySuggestionsForKeyErrors() {
        XCTAssertEqual(
            CaptureError.permissionDenied.recoverySuggestion,
            "Grant screen recording permission in System Preferences > Security & Privacy"
        )
        XCTAssertEqual(
            CaptureError.noWindowSelected.recoverySuggestion,
            "Select a window before attempting to capture"
        )
    }

    func testErrorCategories() {
        XCTAssertEqual(CaptureErrorCategory(from: .permissionDenied), .permission)
        XCTAssertEqual(CaptureErrorCategory(from: .invalidConfiguration), .configuration)
        XCTAssertEqual(CaptureErrorCategory(from: .timeout), .network)
        XCTAssertEqual(CaptureErrorCategory(from: .userCancelled), .user)
        XCTAssertEqual(CaptureErrorCategory(from: .streamStartFailed), .system)
        XCTAssertEqual(CaptureErrorCategory(from: .frameConversionFailed), .unknown)
    }

    func testRecoverability() {
        XCTAssertFalse(CaptureErrorHandler.isRecoverable(.unavailable))
        XCTAssertFalse(CaptureErrorHandler.isRecoverable(.permissionDenied))
        XCTAssertTrue(CaptureErrorHandler.isRecoverable(.timeout))
        XCTAssertTrue(CaptureErrorHandler.isRecoverable(.streamStopFailed))
        XCTAssertTrue(CaptureErrorHandler.isRecoverable(.unknown(NSError(domain: "Test", code: 1))))
    }

    func testUserFriendlyMessages() {
        XCTAssertEqual(
            CaptureErrorHandler.userFriendlyMessage(for: .permissionDenied),
            "Screen recording permission is required. Please enable it in System Preferences."
        )
        XCTAssertEqual(
            CaptureErrorHandler.userFriendlyMessage(for: .noWindowSelected),
            "Please select a window to capture."
        )
        XCTAssertEqual(
            CaptureErrorHandler.userFriendlyMessage(for: .streamCreationFailed),
            "Capture failed. Please try again."
        )
    }
}

#endif
