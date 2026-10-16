import XCTest
@testable import Klapok

@MainActor
final class PermissionRefreshTests: XCTestCase {
    func testMonitoringFinishesWithOnlyCaptureAndFileAccess() {
        let manager = PermissionsManager(screenCheck: { true }, fileCheck: { true })
        manager.settingsPanelAppeared()
        manager.beginMonitoringPermissions()
        XCTAssertTrue(manager.hasScreenCapturePermission)
        XCTAssertTrue(manager.hasFileAccessPermission)
        XCTAssertFalse(manager.isMonitoringPermissions)
    }

    func testCapturePanelAcceptsKeysWithoutBecomingMainWindow() {
        let panel = CaptureControlPanel(contentRect: .zero, styleMask: [.nonactivatingPanel],
                                        backing: .buffered, defer: false)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }

    func testPollingRecognizesGrantAndStopsWhenAllAreGranted() async throws {
        var granted = false
        let manager = PermissionsManager(screenCheck: { granted }, fileCheck: { true },
            pollInterval: 0.01, timeout: 1)
        manager.settingsPanelAppeared()
        manager.beginMonitoringPermissions()
        XCTAssertTrue(manager.isMonitoringPermissions)
        granted = true
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertTrue(manager.hasScreenCapturePermission)
        XCTAssertFalse(manager.isMonitoringPermissions)
    }

    func testPollingStopsOnTimeout() async throws {
        var checks = 0
        let manager = PermissionsManager(screenCheck: { checks += 1; return false }, fileCheck: { true },
            pollInterval: 0.01, timeout: 0.04)
        manager.settingsPanelAppeared()
        manager.beginMonitoringPermissions()
        try await Task.sleep(for: .milliseconds(90))
        XCTAssertFalse(manager.isMonitoringPermissions)
        let completedChecks = checks
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(checks, completedChecks)
    }

    func testClosingSettingsCancelsPollingAndActivationRefresh() async throws {
        var checks = 0
        let manager = PermissionsManager(screenCheck: { checks += 1; return false }, fileCheck: { true },
            pollInterval: 0.01, timeout: 1)
        manager.settingsPanelAppeared()
        manager.beginMonitoringPermissions()
        manager.settingsPanelDisappeared()
        let previousChecks = checks
        manager.applicationBecameActive()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(manager.isMonitoringPermissions)
        XCTAssertEqual(checks, previousChecks)
    }

    func testActivationAndManualRefreshUpdateStatusWithoutPrompting() {
        var granted = false
        let manager = PermissionsManager(screenCheck: { granted }, fileCheck: { true })
        manager.settingsPanelAppeared()
        granted = true
        manager.applicationBecameActive()
        XCTAssertTrue(manager.hasScreenCapturePermission)
        XCTAssertTrue(manager.hasFileAccessPermission)
        granted = false
        manager.checkAllPermissions()
        XCTAssertFalse(manager.hasScreenCapturePermission)
        XCTAssertTrue(manager.hasFileAccessPermission)
    }

    func testRepeatedMonitoringDoesNotLeaveAnOldTimeoutRunning() async throws {
        let manager = PermissionsManager(screenCheck: { false }, fileCheck: { true },
            pollInterval: 0.01, timeout: 0.15)
        manager.settingsPanelAppeared()
        manager.beginMonitoringPermissions()
        try await Task.sleep(for: .milliseconds(90))
        manager.beginMonitoringPermissions()
        try await Task.sleep(for: .milliseconds(90))
        XCTAssertTrue(manager.isMonitoringPermissions)
        manager.settingsPanelDisappeared()
    }

    func testMonitoringDoesNotStartWhilePanelIsClosed() {
        let manager = PermissionsManager(screenCheck: { false }, fileCheck: { true })
        manager.beginMonitoringPermissions()
        XCTAssertFalse(manager.isMonitoringPermissions)
    }
}
