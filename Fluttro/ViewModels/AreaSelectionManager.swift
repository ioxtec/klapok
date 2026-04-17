//
//  AreaSelectionManager.swift
//  Fluttro
//
//  Manages area selection overlay window
//

import SwiftUI

#if os(macOS)
    import AppKit

    private final class AreaSelectionOverlayPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    // MARK: - Area Selection Manager

    final class AreaSelectionManager: ObservableObject {
        @Published var isPresented = false
        @Published var isRecording = false

        private var completion: ((NSRect?) -> Void)?
        private var overlayWindow: NSWindow?
        private var currentSelection: NSRect = .zero
        private var isHiding = false

        // MARK: - Public Methods

        func show(completion: @escaping (NSRect?) -> Void) {
            self.completion = completion
            self.isPresented = true

            createOverlayWindow()
        }

        func hide(with rect: NSRect?) {
            guard !isHiding else {
                Logger.log(
                    "AreaSelectionManager: Already hiding, avoiding infinite loop",
                    type: LogType.info)
                return
            }

            isHiding = true
            isPresented = false
            overlayWindow?.close()
            overlayWindow = nil

            let completionToCall = completion
            completion = nil

            completionToCall?(rect)
            isHiding = false
        }

        func getCurrentSelection() -> NSRect {
            return currentSelection
        }
        
        func startRecording() {
            isRecording = true
        }
        
        func stopRecording() {
            isRecording = false
        }

        // MARK: - Private Methods

        private func createOverlayWindow() {
            Logger.d("AreaSelectionManager: Creating fullscreen overlay window")

            guard let screen = NSScreen.main else {
                Logger.e("AreaSelectionManager: ERROR - No main screen found")
                return
            }

            // Use full screen bounds including menu bar
            let fullScreenRect = NSScreen.screens.first?.frame ?? screen.frame
            Logger.d(
                "AreaSelectionManager: Full screen rect (including menu bar): \(fullScreenRect)")
            Logger.d("AreaSelectionManager: Screen frame (visible area): \(screen.frame)")

            // Create SwiftUI view
            let overlayView = AreaSelectionView(
                onSelection: { rect in
                    Logger.s(
                        "AreaSelectionManager: Selection confirmed: \(String(describing: rect))")
                    self.hide(with: rect)
                },
                currentSelection: Binding(
                    get: { self.currentSelection },
                    set: { self.currentSelection = $0 }
                ),
                isRecording: Binding(
                    get: { self.isRecording },
                    set: { self.isRecording = $0 }
                )
            )

            // Create hosting controller
            let hostingController = NSHostingController(rootView: overlayView)

            // Create window
            let window = AreaSelectionOverlayPanel(
                contentRect: fullScreenRect,
                styleMask: [.nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            // Set window level using WindowDepthManager
            WindowDepthManager.shared.setLevel(for: window, type: .areaSelectionOverlay)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.contentViewController = hostingController
            window.acceptsMouseMovedEvents = true
            window.becomesKeyOnlyIfNeeded = false

            // Try to cover menu bar and receive key events
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            overlayWindow = window

            // Set frame and show
            window.setFrame(fullScreenRect, display: true)
            window.orderFront(nil)
            window.makeKeyAndOrderFront(nil)  // Make it key to receive keyboard events

            Logger.s("AreaSelectionManager: Overlay window shown successfully")
        }
    }

#endif
