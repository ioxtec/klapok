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

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotkeys()
        setupWindowlessPanel()
    }

    private func handleHotkey() {
        Task { @MainActor in
            hidePanel()
            do {
                let image = try await screenshotService.captureMainDisplay()
                openEditor(with: image)
            } catch {
                NSLog("Screenshot failed: \(error.localizedDescription)")
            }
            showPanel()
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
            self?.handleHotkey()
        }
        if !registered {
            NSLog("Failed to register global hotkey")
        }
    }

    private func setupWindowlessPanel() {
        let panelView = PanelView()
        let window = PanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating

        window.contentView = NSHostingView(rootView: panelView)
        window.makeKeyAndOrderFront(nil)

        self.panelWindow = window
    }
    
    func showPanel() {
        guard let window = panelWindow else { return }
        window.center()                // center panel
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hidePanel() {
        panelWindow?.orderOut(nil)
    }
}

#endif
