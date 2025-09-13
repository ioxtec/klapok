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
        private let screenshotService = ScreenshotService()
        private let editorViewModel = EditorViewModel()
        private var floatingPanelViewModel: FloatingPanelViewModel?
        private var cancellables = Set<AnyCancellable>()

        private var editorWindow: NSWindow?
        private var panelWindow: NSPanel?
        private var overlayWindow: NSWindow?  // Pre-created overlay window

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

            // Ukryj okno - będziemy je pokazywać na żądanie
            window.orderOut(nil)

            overlayWindow = window
            Logger.s("AppDelegate: Overlay window created and hidden")
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            registerHotkeys()
            createOverlayWindow()  // Tworzymy overlay window przy starcie
            showFloatingPanel()
            setupEditorObservation()

            // Debug informacje o aplikacji
            PermissionsManager.debugPermissions()

        }

        private func setupEditorObservation() {
            Logger.d("AppDelegate: Setting up editor observation")
            // Obserwuj zmiany w editorViewModel.isPresented
            editorViewModel.$isPresented
                .sink { [weak self] isPresented in
                    Logger.d("AppDelegate: EditorViewModel.isPresented changed to: \(isPresented)")
                    if isPresented, let image = self?.editorViewModel.image {
                        Logger.s(
                            "AppDelegate: EditorViewModel.isPresented = true, pokazuję okno edytora"
                        )
                        self?.openEditor(with: image)
                    } else if !isPresented {
                        Logger.d(
                            "AppDelegate: EditorViewModel.isPresented = false, ukrywam okno edytora"
                        )
                        self?.editorWindow?.orderOut(nil)
                    }
                }
                .store(in: &cancellables)
            Logger.s("AppDelegate: Editor observation setup completed")
        }

        private func handleHotkey() {
            Task { @MainActor in
                do {
                    let image = try await screenshotService.captureMainDisplay()
                    editorViewModel.show(image: image)  // To wywoła setupEditorObservation
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

                // Okno bez widocznego tytułu ale z przyciskami
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
            // Panel: przezroczyste tło + brak toolbara + cienki border
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .screenSaver + 1
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
            blur.material = .hudWindow  // lub .underWindowBackground / .sidebar
            blur.blendingMode = .behindWindow
            blur.state = .active

            // Utwórz ViewModel
            let panelViewModel = FloatingPanelViewModel(editorViewModel: editorViewModel)
            floatingPanelViewModel = panelViewModel

            Logger.s("AppDelegate: FloatingPanelViewModel created and connected to editorViewModel")

            // Zawartość (SwiftUI)
            let content = NSHostingView(rootView: FloatingPanelView(viewModel: panelViewModel))

            // Kontener z zaokrągleniami i borderem
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
            // Nie robimy panel key window - to tylko floating panel
            panelWindow = panel

            // Przekaż referencję do panelu do ViewModel
            panelViewModel.panelWindow = panel
        }
    }

#endif
