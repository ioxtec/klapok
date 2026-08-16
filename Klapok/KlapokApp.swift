//
//  KlapokApp.swift
//  Klapok
//
//  Created by Marcin Ryzko on 08/09/2025.
//

import SwiftUI

#if os(macOS)
    import AppKit
    import Carbon.HIToolbox

    @main
    struct KlapokApp: App {
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

        var body: some Scene {
            Settings {
                SettingsView()
            }
            .windowResizability(.contentSize)
            .windowToolbarStyle(.unified)

        }
    }

#endif
