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
        private var settingsWindow: NSWindow?
        private var panelWindow: NSPanel?
        private var overlayWindow: NSWindow?  // Pre-created overlay window
        private var statusItem: NSStatusItem?
        private var localEscapeMonitor: Any?
        private var globalEscapeMonitor: Any?

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
            setupLocalizationObservation()
            AppSettings.shared.applyDockVisibility()
            setupEditorObservation()
            setupEscapeKeyHandling()

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
                        Task { @MainActor in
                            self?.openEditor(with: image)
                            // Hide floating panel when editor appears
                            self?.hideFloatingPanelForEditor()
                        }
                    } else if !isPresented {
                        Logger.d(
                            "AppDelegate: EditorViewModel.isPresented = false, hiding editor window"
                        )
                        Task { @MainActor in
                            self?.editorWindow?.orderOut(nil)
                        }
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
                Task { @MainActor in
                    self?.handleAppDidResignActive()
                }
            }
        }

        @MainActor
        private func handleAppDidResignActive() {
            guard let panel = panelWindow, isPanelPresented else { return }

            Logger.d("AppDelegate: App resigned active, keeping floating panel visible")
            panel.hidesOnDeactivate = false
            panel.orderFrontRegardless()
            floatingPanelViewModel?.ensurePanelOnTop()
        }

        private func hideFloatingPanelForEditor() {
            Logger.d("AppDelegate: Hiding floating panel because editor opened")
            panelWindow?.orderOut(nil)
            isPanelPresented = false
        }

        private func setupEscapeKeyHandling() {
            localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                [weak self] event in
                guard event.keyCode == kVK_Escape else { return event }

                guard self?.isFloatingCaptureFlowPresented == true else { return event }
                Task { @MainActor in
                    _ = self?.dismissFloatingCaptureFlowFromEscape()
                }
                return nil
            }

            globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
                [weak self] event in
                guard event.keyCode == kVK_Escape else { return }
                Task { @MainActor in
                    _ = self?.dismissFloatingCaptureFlowFromEscape()
                }
            }
        }

        @MainActor
        @discardableResult
        private func dismissFloatingCaptureFlowFromEscape() -> Bool {
            guard isFloatingCaptureFlowPresented else { return false }

            Logger.d("AppDelegate: Escape pressed, closing floating capture flow")
            floatingPanelViewModel?.closeFloatingPanel()
            panelWindow = nil
            isPanelPresented = false
            return true
        }

        private var isFloatingCaptureFlowPresented: Bool {
            floatingPanelViewModel != nil && panelWindow != nil && isPanelPresented
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

        @MainActor
        private func openEditor(with image: NSImage) {
            Logger.d("AppDelegate: openEditor() called with image size: \(image.size)")

            if editorWindow == nil {
                Logger.d("AppDelegate: Creating new editor window...")

                let editorView = EditorView(viewModel: editorViewModel)
                let hosting = NSHostingController(rootView: editorView)

                // Window without visible title but with buttons
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 1180, height: 720),
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
                window.minSize = NSSize(width: 1180, height: 720)
                WindowPlacement.center(window, on: panelWindow?.screen)
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

        @MainActor
        private func showFloatingPanel(mode: CaptureMode = .image) {
            // If panel already exists, just show it
            if let existingPanel = panelWindow {
                isPanelPresented = true
                // Initialize current mode for existing panel
                Task { @MainActor in
                    floatingPanelViewModel?.prepareForPresentation(mode: mode)
                    existingPanel.hidesOnDeactivate = false
                    existingPanel.sharingType = .none
                    existingPanel.collectionBehavior = [
                        .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
                    ]
                    existingPanel.orderFrontRegardless()
                    floatingPanelViewModel?.ensurePanelOnTop()
                }
                return
            }

            // Panel: transparent carrier window; the visible glass is drawn by SwiftUI.
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 90),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            // Set panel level using WindowDepthManager
            WindowDepthManager.shared.setLevel(for: panel, type: .floatingPanel)
            panel.sharingType = .none
            panel.collectionBehavior = [
                .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
            ]
            panel.hidesOnDeactivate = false
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true

            // Create ViewModel
            let panelViewModel = FloatingPanelViewModel(editorViewModel: editorViewModel)
            panelViewModel.prepareForPresentation(mode: mode)
            panelViewModel.onPanelVisibilityChanged = { [weak self] isVisible in
                self?.isPanelPresented = isVisible
            }
            panelViewModel.onPanelClosed = { [weak self] in
                self?.panelWindow = nil
                self?.isPanelPresented = false
            }
            floatingPanelViewModel = panelViewModel

            Logger.s("AppDelegate: FloatingPanelViewModel created and connected to editorViewModel")

            // Content (SwiftUI)
            let content = NSHostingView(rootView: FloatingPanelView(viewModel: panelViewModel))
            content.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 480, height: 90)
            content.autoresizingMask = [.width, .height]
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = content

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
                button.toolTip = LocalizationKeys.statusItemTooltip.localized
            }

            rebuildStatusBarMenu()
        }

        private func setupLocalizationObservation() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(rebuildStatusBarMenuFromNotification),
                name: .languageChanged,
                object: nil
            )
        }

        @objc private func rebuildStatusBarMenuFromNotification() {
            if let button = statusItem?.button {
                button.toolTip = LocalizationKeys.statusItemTooltip.localized
            }
            rebuildStatusBarMenu()
        }

        private func rebuildStatusBarMenu() {
            let menu = NSMenu()

            let takeScreenshotItem = NSMenuItem(
                title: LocalizationKeys.takeScreenshotMenu.localized,
                action: #selector(takeScreenshotFromMenu),
                keyEquivalent: ""
            )
            takeScreenshotItem.target = self
            menu.addItem(takeScreenshotItem)

            let recordScreenItem = NSMenuItem(
                title: LocalizationKeys.recordScreenMenu.localized,
                action: #selector(recordScreenFromMenu),
                keyEquivalent: ""
            )
            recordScreenItem.target = self
            menu.addItem(recordScreenItem)

            menu.addItem(NSMenuItem.separator())

            let settingsItem = NSMenuItem(
                title: LocalizationKeys.settingsMenu.localized,
                action: #selector(openSettings),
                keyEquivalent: ","
            )
            settingsItem.target = self
            menu.addItem(settingsItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(
                title: LocalizationKeys.quitMenu.localized,
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
            menu.addItem(quitItem)

            statusItem?.menu = menu
        }

        @MainActor
        @objc private func takeScreenshotFromMenu() {
            showFloatingPanel(mode: .image)
        }

        @MainActor
        @objc private func recordScreenFromMenu() {
            showFloatingPanel(mode: .video)
        }

        @MainActor
        @objc private func openSettings() {
            openSettingsWindow()
        }

        @MainActor
        private func openSettingsWindow() {
            // If settings window already exists, just show it
            if let existingWindow = settingsWindow ?? NSApp.windows.first(where: { $0.title == "Fluttro Settings" }) {
                existingWindow.makeKeyAndOrderFront(nil)
                existingWindow.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            // Create new settings window
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.contentViewController = hostingController
            window.title = "Fluttro Settings"
            window.minSize = NSSize(width: 820, height: 560)
            window.collectionBehavior = [.moveToActiveSpace]
            WindowPlacement.center(window)
            window.isReleasedWhenClosed = false
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

#endif
