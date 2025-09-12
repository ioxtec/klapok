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

            print("AppDelegate: Creating overlay window at startup...")
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
            print("AppDelegate: Overlay window created and hidden")
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
            // Obserwuj zmiany w editorViewModel.isPresented
            editorViewModel.$isPresented
                .sink { [weak self] isPresented in
                    if isPresented, let image = self?.editorViewModel.image {
                        print("EditorViewModel.isPresented = true, pokazuję okno edytora")
                        self?.openEditor(with: image)
                    } else if !isPresented {
                        print("EditorViewModel.isPresented = false, ukrywam okno edytora")
                        self?.editorWindow?.orderOut(nil)
                    }
                }
                .store(in: &cancellables)
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
            print("AppDelegate: openEditor() called with image size: \(image.size)")

            // NIE wywołujemy editorViewModel.show() tutaj - to już zostało zrobione
            // Ta metoda tylko pokazuje okno edytora

            if editorWindow == nil {
                print("AppDelegate: Creating new editor window...")

                print("AppDelegate: Creating EditorView...")
                let editorView = EditorView(viewModel: editorViewModel)

                print("AppDelegate: Creating NSHostingController...")
                let hosting = NSHostingController(rootView: editorView)

                print("AppDelegate: Creating NSWindow...")
                let window = NSWindow(contentViewController: hosting)
                window.title = "Fluttro Editor"
                window.setContentSize(NSSize(width: 900, height: 600))
                window.center()
                window.isReleasedWhenClosed = false
                editorWindow = window

                print("AppDelegate: Editor window created successfully")
            } else {
                print("AppDelegate: Using existing editor window")
            }

            print("AppDelegate: Showing editor window...")
            editorWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            print("AppDelegate: Editor window shown successfully")
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
            self.floatingPanelViewModel = panelViewModel

            // Zawartość (SwiftUI)
            let content = NSHostingView(rootView: FloatingPanelView(viewModel: panelViewModel))

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

            panel.orderFront(nil)
            // Nie robimy panel key window - to tylko floating panel
            self.panelWindow = panel
        }

    }

#endif
