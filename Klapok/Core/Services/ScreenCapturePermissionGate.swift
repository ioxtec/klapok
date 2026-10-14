import AppKit
import CoreGraphics

@MainActor
final class ScreenCapturePermissionGate {
    static let shared = ScreenCapturePermissionGate(
        checkAccess: { CGPreflightScreenCaptureAccess() },
        requestAccess: { CGRequestScreenCaptureAccess() }
    )
    private let checkAccess: () -> Bool
    private let requestAccess: () -> Bool
    private var isRequesting = false

    init(checkAccess: @escaping () -> Bool, requestAccess: @escaping () -> Bool) {
        self.checkAccess = checkAccess
        self.requestAccess = requestAccess
    }

    nonisolated static var isTestSession: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITests")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// Never show an overlay until the permission check succeeds.
    func ensureAccess(beforeRequest: () -> Void = {}) -> Bool {
        guard !isRequesting else { return false }
        if checkAccess() { return true }
        isRequesting = true
        defer { isRequesting = false }
        beforeRequest()
        let granted = requestAccess()
        return granted && checkAccess()
    }

    func requestOnFirstLaunch(defaults: UserDefaults = .standard, isTestSession: Bool = ScreenCapturePermissionGate.isTestSession) {
        guard !isTestSession else { return }
        let key = "screenCapturePermissionRequestedOnLaunch"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        _ = ensureAccess { NSApp.activate(ignoringOtherApps: true) }
    }
}
