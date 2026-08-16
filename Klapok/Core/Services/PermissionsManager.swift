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

    final class PermissionsManager: ObservableObject {
        @Published var hasScreenCapturePermission = false
        @Published var hasFileAccessPermission = false
        @Published var hasAccessibilityPermission = false
        
        static let shared = PermissionsManager()
        
        private init() {
            checkAllPermissions()
        }
        
        // MARK: - Permission Checking
        
        func checkAllPermissions() {
            hasScreenCapturePermission = checkScreenCapturePermission()
            hasFileAccessPermission = checkFileAccessPermission()
            hasAccessibilityPermission = checkAccessibilityPermission()
        }
        
        func checkScreenCapturePermission() -> Bool {
            // For ScreenCaptureKit, we need to check if we can access screen content
            // This is a simplified check - in practice, ScreenCaptureKit will handle permissions
            return CGPreflightScreenCaptureAccess()
        }
        
        func checkFileAccessPermission() -> Bool {
            // Check if we can write to the Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let testFile = documentsPath.appendingPathComponent(".test_write_permission")
            
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: testFile)
                return true
            } catch {
                return false
            }
        }
        
        func checkAccessibilityPermission() -> Bool {
            // Check if we have accessibility permissions (for global hotkeys)
            return AXIsProcessTrusted()
        }
        
        // MARK: - Permission Requests
        
        func requestScreenCapturePermission() {
            CGRequestScreenCaptureAccess()
        }
        
        func requestAccessibilityPermission() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
        
        // MARK: - System Settings
        
        func openSystemPreferences() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
        
        func openScreenRecordingSettings() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
        
        func openAccessibilitySettings() {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        
    }

#endif
