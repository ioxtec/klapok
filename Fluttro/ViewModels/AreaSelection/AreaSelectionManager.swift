//
//  AreaSelectionManager.swift
//  Fluttro
//
//  Manages area selection overlay window
//

import SwiftUI

#if os(macOS)
    import AppKit

    // MARK: - Area Selection Manager

    final class AreaSelectionManager: ObservableObject {
        @Published var isPresented = false

        private var backgroundImage: NSImage?
        private var completion: ((NSRect?) -> Void)?
        private var overlayWindow: NSWindow?
        private var currentSelection: NSRect = .zero
        private var isHiding = false

        // MARK: - Public Methods

        func show(backgroundImage: NSImage, completion: @escaping (NSRect?) -> Void) {
            self.backgroundImage = backgroundImage
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
            backgroundImage = nil

            completionToCall?(rect)
            isHiding = false
        }

        func getCurrentSelection() -> NSRect {
            return currentSelection
        }

        // MARK: - Private Methods

        private func createOverlayWindow() {
            Logger.d("AreaSelectionManager: Creating fullscreen overlay window")

            guard let screen = NSScreen.main else {
                Logger.e("AreaSelectionManager: ERROR - No main screen found")
                return
            }

            guard let backgroundImage = backgroundImage else {
                Logger.e("AreaSelectionManager: ERROR - No background image")
                return
            }

            let fullScreenRect = NSRect(
                x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)

            // Create SwiftUI view
            let overlayView = AreaSelectionView(
                backgroundImage: backgroundImage,
                onSelection: { rect in
                    Logger.s(
                        "AreaSelectionManager: Selection confirmed: \(String(describing: rect))")
                    self.hide(with: rect)
                },
                currentSelection: Binding(
                    get: { self.currentSelection },
                    set: { self.currentSelection = $0 }
                )
            )

            // Create hosting controller
            let hostingController = NSHostingController(rootView: overlayView)

            // Create window
            let window = NSPanel(
                contentRect: fullScreenRect,
                styleMask: [.nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.contentViewController = hostingController
            window.acceptsMouseMovedEvents = true
            window.becomesKeyOnlyIfNeeded = false

            overlayWindow = window

            // Set frame and show
            window.setFrame(fullScreenRect, display: true)
            window.center()
            window.orderFront(nil)

            Logger.s("AreaSelectionManager: Overlay window shown successfully")
        }
    }

#endif
