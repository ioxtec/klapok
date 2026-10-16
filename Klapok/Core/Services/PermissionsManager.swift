//
//  PermissionsManager.swift
//  Klapok
//
//  Manages screen recording permissions and system access
//

import CoreGraphics
import Foundation
import ScreenCaptureKit

#if os(macOS)
    import AppKit

    @MainActor
    final class PermissionsManager: ObservableObject {
        @Published var hasScreenCapturePermission = false
        @Published var hasFileAccessPermission = false
        @Published private(set) var isMonitoringPermissions = false
        @Published private(set) var hasOpenedPermissionSettings = false

        private let screenCheck: () -> Bool
        private let fileCheck: () -> Bool
        private let pollInterval: TimeInterval
        private let timeout: TimeInterval
        private var monitorTask: Task<Void, Never>?
        private var isPanelVisible = false
        
        static let shared = PermissionsManager()
        
        init(screenCheck: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
             fileCheck: @escaping () -> Bool = {
                 guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return false }
                 return FileManager.default.isWritableFile(atPath: folder.path)
             },
             pollInterval: TimeInterval = 3, timeout: TimeInterval = 180) {
            self.screenCheck = screenCheck
            self.fileCheck = fileCheck
            self.pollInterval = max(0.001, pollInterval)
            self.timeout = max(0, timeout)
            checkAllPermissions()
        }

        deinit { monitorTask?.cancel() }

        func settingsPanelAppeared() {
            isPanelVisible = true
            checkAllPermissions()
        }

        func settingsPanelDisappeared() {
            isPanelVisible = false
            stopMonitoringPermissions()
        }

        func applicationBecameActive() {
            guard isPanelVisible else { return }
            checkAllPermissions()
        }

        func beginMonitoringPermissions() {
            hasOpenedPermissionSettings = true
            stopMonitoringPermissions()
            guard isPanelVisible else { return }
            checkAllPermissions()
            guard !allPermissionsGranted else { return }
            isMonitoringPermissions = true
            let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
            let interval = pollInterval
            monitorTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(interval)) }
                    catch { return }
                    guard let self, self.isPanelVisible, !Task.isCancelled else { return }
                    guard ContinuousClock.now < deadline else {
                        self.stopMonitoringPermissions()
                        return
                    }
                    self.checkAllPermissions()
                    if self.allPermissionsGranted { return }
                }
            }
        }

        private var allPermissionsGranted: Bool {
            hasScreenCapturePermission && hasFileAccessPermission
        }

        private func stopMonitoringPermissions() {
            monitorTask?.cancel()
            monitorTask = nil
            isMonitoringPermissions = false
        }
        
        // MARK: - Permission Checking
        
        func checkAllPermissions() {
            hasScreenCapturePermission = checkScreenCapturePermission()
            hasFileAccessPermission = checkFileAccessPermission()
            if allPermissionsGranted { stopMonitoringPermissions() }
        }
        
        func checkScreenCapturePermission() -> Bool {
            screenCheck()
        }
        
        func checkFileAccessPermission() -> Bool {
            fileCheck()
        }
        
        
        // MARK: - Permission Requests
        
        func requestScreenCapturePermission() {
            CGRequestScreenCaptureAccess()
        }
        
        
        // MARK: - System Settings
        
        func openSystemPreferences() {
            beginMonitoringPermissions()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
        
        func openScreenRecordingSettings() {
            beginMonitoringPermissions()
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        
        
    }

#endif
