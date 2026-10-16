//
//  AppDelegate.swift
//  Klapok
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import Combine
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
    import Carbon.HIToolbox

    final class CaptureControlPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    final class AppDelegate: NSObject, NSApplicationDelegate {
        private let hotkeyManager = HotkeyManager()
        @MainActor private let captureManager = CaptureManager.shared
        private let editorViewModel = EditorViewModel()
        private var floatingPanelViewModel: FloatingPanelViewModel?
        private var cancellables = Set<AnyCancellable>()

        private var editorWindow: NSWindow?
        private var importedVideoWindow: NSWindow?
        #if DEBUG
        private var uiTestVideoFolder: URL?
        #endif

        func applicationWillTerminate(_ notification: Notification) {
            if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
            localEscapeMonitor = nil
            #if DEBUG
            if let uiTestVideoFolder { try? FileManager.default.removeItem(at: uiTestVideoFolder) }
            #endif
        }
        private var settingsWindow: NSWindow?
        private var panelWindow: NSPanel?
        private var overlayWindow: NSWindow?  // Pre-created overlay window
        private var statusItem: NSStatusItem?
        private var localEscapeMonitor: Any?

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

            Task { @MainActor in
                runUITestLaunchActionsIfNeeded()
                ScreenCapturePermissionGate.shared.requestOnFirstLaunch()
            }
        }

        @MainActor
        private func runUITestLaunchActionsIfNeeded() {
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("-UITests") else { return }

            if arguments.contains("-UITestResetSettings") {
                AppSettings.shared.resetToDefaults()
            }

            if arguments.contains("-UITestOpenSettings") {
                openSettingsWindow()
            }

            if arguments.contains("-UITestOpenImageEditor") {
                let image = NSImage(size: CGSize(width: 800, height: 500))
                image.lockFocus()
                NSColor.systemBlue.setFill()
                NSRect(x: 0, y: 0, width: 800, height: 500).fill()
                image.unlockFocus()
                editorViewModel.show(image: image)
            }

            #if DEBUG
            if let index = arguments.firstIndex(of: "-UITestVideoURL"), arguments.indices.contains(index + 1) {
                let fixtureURL = URL(fileURLWithPath: arguments[index + 1])
                Task { @MainActor in
                    // The test runner's temp directory is readable but not writable
                    // by the sandboxed app. Export beside an app-owned fixture copy.
                    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("KlapokUITest-\(UUID().uuidString)")
                    let url = folder.appendingPathComponent(fixtureURL.lastPathComponent)
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        if let encoded = ProcessInfo.processInfo.environment["KLAPOK_UI_TEST_VIDEO_DATA"],
                           let data = Data(base64Encoded: encoded) {
                            try data.write(to: url)
                        } else {
                            try FileManager.default.copyItem(at: fixtureURL, to: url)
                        }
                        self.uiTestVideoFolder = folder
                    } catch {
                        Logger.e("Could not prepare UI test video: \(error)")
                        return
                    }
                    let asset = AVURLAsset(url: url)
                    guard let duration = try? await asset.load(.duration),
                          let track = try? await asset.loadTracks(withMediaType: .video).first,
                          let size = try? await track.load(.naturalSize) else { return }
                    let recording = VideoRecording(url: url, duration: duration.seconds, size: size, frameRate: 30)
                    let host = NSHostingController(rootView: VideoEditorView(viewModel: VideoEditorViewModel(video: recording)))
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 850),
                        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                    window.title = "Klapok Video Editor"
                    window.contentViewController = host; window.isReleasedWhenClosed = false
                    self.editorWindow = window
                    window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
                }
            }
            #endif

            if arguments.contains("-UITestShowFloatingPanel") {
                hideEditorWindowsForNewCapture()
                let mode: CaptureMode = arguments.contains("-UITestShowVideoPanel") ? .video : .image
                showFloatingPanel(mode: mode)
            }
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

        @MainActor
        private func hideEditorWindowsForNewCapture() {
            editorViewModel.isPresented = false
            editorWindow?.orderOut(nil)
            floatingPanelViewModel?.hideVideoEditorWindow()
            importedVideoWindow?.orderOut(nil)
        }

        private func setupEscapeKeyHandling() {
            localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                [weak self] event in
                guard event.keyCode == kVK_Escape else { return event }

                guard let self, self.isFloatingCaptureFlowPresented,
                      let panel = self.panelWindow, event.window === panel else { return event }
                Task { @MainActor in
                    _ = self.dismissFloatingCaptureFlowFromEscape()
                }
                return nil
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

        @MainActor
        private func openEditor(with image: NSImage) {
            Logger.d("AppDelegate: openEditor() called with image size: \(image.size)")

            if editorWindow == nil {
                Logger.d("AppDelegate: Creating new editor window...")

                let editorView = ScreenshotEditorView(viewModel: editorViewModel)
                let hosting = NSHostingController(rootView: editorView)
                hosting.view.wantsLayer = true
                hosting.view.layer?.cornerRadius = 18
                hosting.view.layer?.cornerCurve = .continuous
                hosting.view.layer?.masksToBounds = true

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
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                window.contentView?.layer?.cornerRadius = 18
                window.contentView?.layer?.cornerCurve = .continuous
                window.contentView?.layer?.masksToBounds = true
                window.title = "Klapok Screenshot Editor"
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.minSize = NSSize(width: 1180, height: 720)
                window.setContentSize(NSSize(width: 1180, height: 720))
                WindowPlacement.center(window, on: panelWindow?.screen)
                window.isReleasedWhenClosed = false

                editorWindow = window
                Logger.s("AppDelegate: Editor window created successfully")
            }

            Logger.d("AppDelegate: Showing editor window...")
            editorWindow?.makeKeyAndOrderFront(nil)
            if let editorWindow {
                refreshEditorWindowLayout(editorWindow, preferredScreen: panelWindow?.screen)

                DispatchQueue.main.async {
                    self.refreshEditorWindowLayout(editorWindow, preferredScreen: self.panelWindow?.screen)
                }
            }
            NSApp.activate(ignoringOtherApps: true)
            Logger.s("AppDelegate: Editor window shown successfully")
        }

        @MainActor
        private func refreshEditorWindowLayout(_ window: NSWindow, preferredScreen: NSScreen? = nil) {
            window.contentView?.needsLayout = true
            window.contentView?.layoutSubtreeIfNeeded()
            window.contentView?.needsDisplay = true
            window.invalidateShadow()

            let frame = window.frame
            let nudgedFrame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width + 1,
                height: frame.height
            )

            window.setFrame(nudgedFrame, display: true, animate: false)
            window.setFrame(frame, display: true, animate: false)
            WindowPlacement.center(window, on: preferredScreen)
        }

        private func registerHotkeys() {
            for shortcut in KeyboardShortcutAction.allCases {
                let registered = hotkeyManager.register(
                    id: shortcut.id,
                    keyCode: shortcut.keyCode,
                    modifiers: shortcut.carbonModifiers
                ) { [weak self] in
                    Task { @MainActor in
                        self?.performKeyboardShortcut(shortcut)
                    }
                }

                if !registered {
                    NSLog("Failed to register global hotkey: \(shortcut.title)")
                }
            }
        }

        @MainActor
        private func performKeyboardShortcut(_ shortcut: KeyboardShortcutAction) {
            switch shortcut {
            case .importImage:
                importImageFromMenu()
                return
            case .importVideo:
                importVideoFromMenu()
                return
            default:
                break
            }
            hideEditorWindowsForNewCapture()
            showFloatingPanel(mode: shortcut.mode)
            floatingPanelViewModel?.performShortcut(shortcut)
        }

        @MainActor
        private func showFloatingPanel(mode: CaptureMode = .image) {
            // If panel already exists, just show it
            if let existingPanel = panelWindow {
                isPanelPresented = true
                // Initialize current mode for existing panel
                floatingPanelViewModel?.prepareForPresentation(mode: mode)
                existingPanel.hidesOnDeactivate = false
                existingPanel.sharingType = .none
                existingPanel.collectionBehavior = [
                    .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
                ]
                existingPanel.makeKeyAndOrderFront(nil)
                floatingPanelViewModel?.ensurePanelOnTop()
                return
            }

            // Panel: transparent carrier window; the visible glass is drawn by SwiftUI.
            let panel = CaptureControlPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 104),
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
            content.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 480, height: 104)
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

            panel.becomesKeyOnlyIfNeeded = false
            panel.makeKeyAndOrderFront(nil)
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
                button.image = statusItemBrandImage()
                button.toolTip = LocalizationKeys.statusItemTooltip.localized
            }

            rebuildStatusBarMenu()
        }

        private func statusItemBrandImage() -> NSImage? {
            if let assetImage = NSImage(named: "KlapokToolbarDark")?.copy() as? NSImage {
                assetImage.size = NSSize(width: 18, height: 18)
                assetImage.isTemplate = true
                return assetImage
            }

            guard
                let imageURL = Bundle.main.url(forResource: "klapok-toolbar-dark", withExtension: "png"),
                let image = NSImage(contentsOf: imageURL)
            else {
                return NSImage(
                    systemSymbolName: "camera.fill",
                    accessibilityDescription: "Klapok"
                )
            }

            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        private func setupLocalizationObservation() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(rebuildStatusBarMenuFromNotification),
                name: .languageChanged,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(rebuildShortcutsFromNotification),
                name: .keyboardShortcutsChanged,
                object: nil
            )
        }

        @objc private func rebuildStatusBarMenuFromNotification() {
            if let button = statusItem?.button {
                button.toolTip = LocalizationKeys.statusItemTooltip.localized
            }
            rebuildStatusBarMenu()
        }

        @objc private func rebuildShortcutsFromNotification() {
            hotkeyManager.unregister()
            registerHotkeys()
            rebuildStatusBarMenu()
        }

        private func rebuildStatusBarMenu() {
            let menu = NSMenu()

            addShortcutActionItems(KeyboardShortcutAction.screenshotActions, to: menu)

            menu.addItem(NSMenuItem.separator())

            addShortcutActionItems(KeyboardShortcutAction.recordingActions, to: menu)

            menu.addItem(NSMenuItem.separator())

            addShortcutActionItems(KeyboardShortcutAction.importActions, to: menu)
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

        private func addShortcutActionItems(_ shortcuts: [KeyboardShortcutAction], to menu: NSMenu) {
            for shortcut in shortcuts {
                let item = NSMenuItem(
                    title: shortcut.menuTitle,
                    action: #selector(performShortcutFromMenu(_:)),
                    keyEquivalent: shortcut.shortcut.keyEquivalent
                )
                item.keyEquivalentModifierMask = shortcut.shortcut.keyEquivalentModifierMask
                item.representedObject = Int(shortcut.rawValue)
                item.toolTip = shortcut.description
                item.target = self
                menu.addItem(item)
            }
        }

        @MainActor
        @objc private func takeScreenshotFromMenu() {
            hideEditorWindowsForNewCapture()
            showFloatingPanel(mode: .image)
        }

        @MainActor
        @objc private func recordScreenFromMenu() {
            hideEditorWindowsForNewCapture()
            showFloatingPanel(mode: .video)
        }

        @MainActor
        @objc private func performShortcutFromMenu(_ sender: NSMenuItem) {
            guard
                let rawValue = sender.representedObject as? Int,
                let shortcut = KeyboardShortcutAction(rawValue: UInt32(rawValue))
            else {
                return
            }

            performKeyboardShortcut(shortcut)
        }

        @MainActor
        @objc private func openSettings() {
            openSettingsWindow()
        }

        @MainActor
        private func chooseImportFile(types: [UTType], title: String) -> URL? {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = types
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.title = title
            NSApp.activate(ignoringOtherApps: true)
            WindowPlacement.centerModalPanel(panel)
            return panel.runModal() == .OK ? panel.url : nil
        }

        @MainActor
        @objc private func importImageFromMenu() {
            guard let url = chooseImportFile(types: [.image], title: "Import Image…".localized) else { return }
            do {
                let image = try MediaImportService.loadImage(from: url)
                hideEditorWindowsForNewCapture()
                hideFloatingPanelForEditor()
                editorViewModel.show(image: image)
            } catch { showImportError(error) }
        }

        @MainActor
        @objc private func importVideoFromMenu() {
            guard let url = chooseImportFile(types: [.movie], title: "Import Video…".localized) else { return }
            Task { @MainActor in
                do {
                    let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Klapok/Imports", isDirectory: true)
                    let recording = try await MediaImportService.importVideo(from: url, into: directory)
                    hideEditorWindowsForNewCapture()
                    hideFloatingPanelForEditor()
                    let host = NSHostingController(rootView: VideoEditorView(viewModel: VideoEditorViewModel(video: recording)))
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 720),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                        backing: .buffered, defer: false)
                    window.contentViewController = host
                    window.title = "Klapok Video Editor".localized
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                    window.minSize = NSSize(width: 1180, height: 720)
                    window.isReleasedWhenClosed = false
                    importedVideoWindow?.close()
                    importedVideoWindow = window
                    WindowPlacement.center(window)
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } catch { showImportError(error) }
            }
        }

        @MainActor
        private func showImportError(_ error: Error) {
            let alert = NSAlert()
            alert.messageText = "Import Failed".localized
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }

        @MainActor
        private func openSettingsWindow() {
            // If settings window already exists, just show it
            if let existingWindow = settingsWindow ?? NSApp.windows.first(where: { $0.title == "Klapok Settings" }) {
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
            window.title = "Klapok Settings"
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
