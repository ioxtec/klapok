//
//  AppDelegate.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import Combine
import SwiftUI

#if os(macOS)
    import AppKit
    import Carbon.HIToolbox

    final class AppDelegate: NSObject, NSApplicationDelegate {
        private let hotkeyManager = HotkeyManager()
        @MainActor private let captureManager = CaptureManager.shared
        private let editorViewModel = EditorViewModel()
        private var floatingPanelViewModel: FloatingPanelViewModel?
        private var cancellables = Set<AnyCancellable>()

        private var editorWindow: NSWindow?
        private var panelWindow: NSPanel?
        private var overlayWindow: NSWindow?  // Pre-created overlay window
        private var statusItem: NSStatusItem?

        @Published var isPanelPresented = false

        private func createOverlayWindow() {
            guard let screen = NSScreen.main else { return }

            Logger.d("AppDelegate: Creating overlay window at startup...")
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false

            // Hide window - we'll show it on demand
            window.orderOut(nil)

            overlayWindow = window
            Logger.s("AppDelegate: Overlay window created and hidden")
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            registerHotkeys()
            createOverlayWindow()  // Create overlay window at startup
            setupStatusBarItem()
            setupEditorObservation()

            // Debug informacje o aplikacji
            PermissionsManager.debugPermissions()
        }

        private func setupEditorObservation() {
            Logger.d("AppDelegate: Setting up editor observation")
            // Observe changes in editorViewModel.isPresented
            editorViewModel.$isPresented
                .sink { [weak self] isPresented in
                    Logger.d("AppDelegate: EditorViewModel.isPresented changed to: \(isPresented)")
                    if isPresented, let image = self?.editorViewModel.image {
                        Logger.s(
                            "AppDelegate: EditorViewModel.isPresented = true, showing editor window"
                        )
                        self?.openEditor(with: image)
                        // Hide floating panel when editor appears
                        self?.hideFloatingPanelForEditor()
                    } else if !isPresented {
                        Logger.d(
                            "AppDelegate: EditorViewModel.isPresented = false, hiding editor window"
                        )
                        self?.editorWindow?.orderOut(nil)
                    }
                }
                .store(in: &cancellables)

            // Setup panel focus observation
            setupPanelFocusObservation()

            Logger.s("AppDelegate: Editor observation setup completed")
        }

        private func setupPanelFocusObservation() {
            // Observe when application loses focus
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleAppDidResignActive()
            }
        }

        private func handleAppDidResignActive() {
            // Hide floating panel when application loses focus, but only if there's no active area selection
            guard let viewModel = floatingPanelViewModel else { return }

            // Don't hide panel if area selection is active
            if !viewModel.isAreaSelectionActive {
                Logger.d("AppDelegate: App resigned active, hiding floating panel")
                panelWindow?.orderOut(nil)
                isPanelPresented = false
            } else {
                Logger.d(
                    "AppDelegate: App resigned active but area selection is active, keeping panel")
            }
        }

        private func hideFloatingPanelForEditor() {
            Logger.d("AppDelegate: Hiding floating panel because editor opened")
            panelWindow?.orderOut(nil)
            isPanelPresented = false
        }

        private func handleHotkey() {
            Task { @MainActor in
                do {
                    let image = try await captureManager.captureFullScreen()
                    editorViewModel.show(image: image)  // This will trigger setupEditorObservation
                } catch {
                    NSLog("Screenshot failed: \(error.localizedDescription)")
                }
            }
        }

        private func openEditor(with image: NSImage) {
            Logger.d("AppDelegate: openEditor() called with image size: \(image.size)")

            if editorWindow == nil {
                Logger.d("AppDelegate: Creating new editor window...")

                let editorView = EditorView(viewModel: editorViewModel)
                let hosting = NSHostingController(rootView: editorView)

                // Window without visible title but with buttons
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                    styleMask: [
                        .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView,
                    ],
                    backing: .buffered,
                    defer: false
                )

                window.contentViewController = hosting
                window.title = "Fluttro Editor"
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.center()
                window.isReleasedWhenClosed = false

                editorWindow = window
                Logger.s("AppDelegate: Editor window created successfully")
            }

            Logger.d("AppDelegate: Showing editor window...")
            editorWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            Logger.s("AppDelegate: Editor window shown successfully")
        }

        private func registerHotkeys() {
            let registered = hotkeyManager.register(
                keyCode: 0x1a,
                modifiers: 0x0100 | 0x0200
            ) { [weak self] in
                self?.isPanelPresented.toggle()
            }
            if !registered {
                NSLog("Failed to register global hotkey")
            }
        }

        private func showFloatingPanel() {
            // If panel already exists, just show it
            if let existingPanel = panelWindow {
                existingPanel.orderFront(nil)
                isPanelPresented = true
                // Initialize current mode for existing panel
                Task { @MainActor in
                    floatingPanelViewModel?.initializeCurrentMode()
                }
                return
            }

            // Panel: transparent background + no toolbar + thin border
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            // Set panel level using WindowDepthManager
            WindowDepthManager.shared.setLevel(for: panel, type: .floatingPanel)
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

            // Background blur
            let blur = NSVisualEffectView()
            blur.material = .hudWindow  // or .underWindowBackground / .sidebar
            blur.blendingMode = .behindWindow
            blur.state = .active

            // Create ViewModel
            let panelViewModel = FloatingPanelViewModel(editorViewModel: editorViewModel)
            floatingPanelViewModel = panelViewModel

            Logger.s("AppDelegate: FloatingPanelViewModel created and connected to editorViewModel")

            // Content (SwiftUI)
            let content = NSHostingView(rootView: FloatingPanelView(viewModel: panelViewModel))

            // Container with rounded corners and border
            let container = NSView(frame: panel.contentView?.bounds ?? .zero)
            container.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.cornerRadius = 10
            container.layer?.masksToBounds = true

            // Dodaj cienki border
            container.layer?.borderWidth = 0.5
            container.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor

            blur.frame = container.bounds
            blur.autoresizingMask = [.width, .height]
            content.frame = container.bounds
            content.autoresizingMask = [.width, .height]

            container.addSubview(blur)
            container.addSubview(content)
            panel.contentView = container

            // setting panel start position
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let w = panel.frame.width
            let h = panel.frame.height

            let originX = screen.minX + (screen.width - w) / 2
            let centerY = screen.minY + screen.height * 0.25
            let originY = centerY - h / 2

            // bezpieczne ograniczenie do granic ekranu
            let clampedY = max(screen.minY, min(originY, screen.maxY - h))

            panel.setFrameOrigin(NSPoint(x: originX, y: clampedY))

            panel.orderFront(nil)
            // Don't make panel key window - it's just a floating panel
            panelWindow = panel
            isPanelPresented = true

            // Pass panel reference to ViewModel
            panelViewModel.panelWindow = panel
            
            // Ensure panel is on top
            Task { @MainActor in
                panelViewModel.ensurePanelOnTop()
                panelViewModel.initializeCurrentMode()
            }
        }

        private func setupStatusBarItem() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

            if let button = statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: "camera.fill", accessibilityDescription: "Fluttro")
                button.toolTip = "Fluttro - Screenshot Tool"
            }

            let menu = NSMenu()

            let takeScreenshotItem = NSMenuItem(
                title: "Take Screenshot",
                action: #selector(takeScreenshotFromMenu),
                keyEquivalent: ""
            )
            takeScreenshotItem.target = self
            menu.addItem(takeScreenshotItem)

            menu.addItem(NSMenuItem.separator())

            let settingsItem = NSMenuItem(
                title: "Settings...",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
            settingsItem.target = self
            menu.addItem(settingsItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(
                title: "Quit Fluttro",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
            menu.addItem(quitItem)

            statusItem?.menu = menu
        }

        @objc private func takeScreenshotFromMenu() {
            showFloatingPanel()
        }

        @objc private func openSettings() {
            openSettingsWindow()
        }

        private func openSettingsWindow() {
            // If settings window already exists, just show it
            if let existingWindow = NSApp.windows.first(where: { $0.title == "Fluttro Settings" }) {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            // Create new settings window
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.contentViewController = hostingController
            window.title = "Fluttro Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

#endif
