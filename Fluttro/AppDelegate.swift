//
//  AppDelegate.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyManager = HotkeyManager()
    private let screenshotService = ScreenshotService()
    private let editorViewModel = EditorViewModel()

    private var editorWindow: NSWindow?
    private var panelWindow: NSWindow?
    
    @Published var isPanelPresented = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotkeys()
    }

    private func handleHotkey() {
        Task { @MainActor in
            do {
                let image = try await screenshotService.captureMainDisplay()
                openEditor(with: image)
            } catch {
                NSLog("Screenshot failed: \(error.localizedDescription)")
            }
        }
    }


    private func openEditor(with image: NSImage) {
        editorViewModel.show(image: image)

        if editorWindow == nil {
            let hosting = NSHostingController(rootView: EditorView(viewModel: editorViewModel))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Fluttro Editor"
            window.setContentSize(NSSize(width: 900, height: 600))
            window.center()
            window.isReleasedWhenClosed = false
            editorWindow = window
        }

        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func registerHotkeys() {
        let registered = hotkeyManager.register(
            keyCode: 0x1A,
            modifiers: 0x0100 | 0x0200
        ) { [weak self] in
            self?.isPanelPresented.toggle()
        }
        if !registered {
            NSLog("Failed to register global hotkey")
        }
    }
    
}

#endif
