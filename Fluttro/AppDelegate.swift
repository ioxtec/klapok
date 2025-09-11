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
        showFloatingPanel()
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
    
    private func showFloatingPanel() {
        // Panel: przezroczyste tło + brak toolbara
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 130),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Blur tła
        let blur = NSVisualEffectView()
        blur.material = .hudWindow // lub .underWindowBackground / .sidebar
        blur.blendingMode = .behindWindow
        blur.state = .active

        // Zawartość (SwiftUI)
        let content = NSHostingView(rootView: FloatingPanelView())

        // Kontener z zaokrągleniami
        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        blur.frame = container.bounds
        blur.autoresizingMask = [.width, .height]
        content.frame = container.bounds
        content.autoresizingMask = [.width, .height]

        container.addSubview(blur)
        container.addSubview(content)
        panel.contentView = container

        //setting panel start position
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let w = panel.frame.width
        let h = panel.frame.height

        let originX = screen.minX + (screen.width - w) / 2
        let centerY = screen.minY + screen.height * 0.25
        let originY = centerY - h / 2

        // bezpieczne ograniczenie do granic ekranu
        let clampedY = max(screen.minY, min(originY, screen.maxY - h))

        panel.setFrameOrigin(NSPoint(x: originX, y: clampedY))

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panelWindow = panel
    }
    
}

#endif
