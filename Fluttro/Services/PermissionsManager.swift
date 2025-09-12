//
//  PermissionsManager.swift
//  Fluttro
//
//  Manages screen recording permissions
//

import Foundation
import CoreGraphics

#if os(macOS)
import AppKit

final class PermissionsManager {
    

    
    @MainActor
    static func debugPermissions() {
        
        let hasPermission = CGPreflightScreenCaptureAccess()

        if !hasPermission {
            CGRequestScreenCaptureAccess()
        }
        print("=== DEBUG UPRAWNIEŃ ===")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "BRAK")")
        print("App Name: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "BRAK")")
        print("Executable: \(Bundle.main.executablePath ?? "BRAK")")
        print("======================")
        print("hasPermission: \(hasPermission.description)")

        // CGPreflightScreenCaptureAccess zawsze zwraca false w development builds
        // Więc nie sprawdzamy uprawnień - pozwalamy systemowi obsłużyć to automatycznie
        print("Uprawnienia: System obsłuży automatycznie przez ScreenCaptureKit")
        print("======================")
    }
}

#endif
