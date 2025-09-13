//
//  PermissionsManager.swift
//  Fluttro
//
//  Manages screen recording permissions
//

import CoreGraphics
import Foundation

#if os(macOS)
    import AppKit

    final class PermissionsManager {

        @MainActor
        static func debugPermissions() {

            let hasPermission = CGPreflightScreenCaptureAccess()

            if !hasPermission {
                CGRequestScreenCaptureAccess()
            }
            Logger.i("=== DEBUG UPRAWNIEŃ ===")
            Logger.i("Bundle ID: \(Bundle.main.bundleIdentifier ?? "BRAK")")
            Logger.i(
                "App Name: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "BRAK")")
            Logger.i("Executable: \(Bundle.main.executablePath ?? "BRAK")")
            Logger.i("======================")
            Logger.i("hasPermission: \(hasPermission.description)")

            // CGPreflightScreenCaptureAccess zawsze zwraca false w development builds
            // Więc nie sprawdzamy uprawnień - pozwalamy systemowi obsłużyć to automatycznie
            Logger.i("Uprawnienia: System obsłuży automatycznie przez ScreenCaptureKit")
            Logger.i("======================")
        }
    }

#endif
