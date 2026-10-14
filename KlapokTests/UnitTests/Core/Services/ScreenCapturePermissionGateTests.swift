import XCTest
@testable import Klapok

@MainActor
final class ScreenCapturePermissionGateTests: XCTestCase {
    func testGrantedAccessDoesNotHideUIOrAskAgain() {
        var events: [String] = []
        let gate = ScreenCapturePermissionGate(checkAccess: { true }, requestAccess: { events.append("request"); return false })
        XCTAssertTrue(gate.ensureAccess { events.append("hide") })
        XCTAssertTrue(events.isEmpty)
    }

    func testDeniedAccessClosesOverlaysBeforePromptAndStopsCapture() {
        var events: [String] = []
        let gate = ScreenCapturePermissionGate(checkAccess: { false }, requestAccess: { events.append("request"); return false })
        if gate.ensureAccess(beforeRequest: { events.append("hide overlays") }) { events.append("capture") }
        XCTAssertEqual(events, ["hide overlays", "request"])
    }

    func testNewGrantIsRecheckedBeforeCaptureContinues() {
        var allowed = false
        var events: [String] = []
        let gate = ScreenCapturePermissionGate(checkAccess: { allowed }, requestAccess: {
            events.append("request"); allowed = true; return true
        })
        if gate.ensureAccess(beforeRequest: { events.append("hide") }) { events.append("capture") }
        XCTAssertEqual(events, ["hide", "request", "capture"])
    }

    func testGrantThatStillNeedsRestartDoesNotStartCapture() {
        let gate = ScreenCapturePermissionGate(checkAccess: { false }, requestAccess: { true })
        XCTAssertFalse(gate.ensureAccess())
    }

    func testReentrantActionCannotOpenOverlayDuringPrompt() {
        var gate: ScreenCapturePermissionGate!
        gate = ScreenCapturePermissionGate(checkAccess: { false }, requestAccess: {
            XCTAssertFalse(gate.ensureAccess()); return false
        })
        XCTAssertFalse(gate.ensureAccess())
    }

    func testFirstLaunchRequestsOnlyOnceButCaptureCanRetryLater() {
        let suite = "Klapok.PermissionGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var requests = 0
        let gate = ScreenCapturePermissionGate(checkAccess: { false }, requestAccess: { requests += 1; return false })
        gate.requestOnFirstLaunch(defaults: defaults, isTestSession: false)
        gate.requestOnFirstLaunch(defaults: defaults, isTestSession: false)
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(gate.ensureAccess())
        XCTAssertEqual(requests, 2)
    }
}
