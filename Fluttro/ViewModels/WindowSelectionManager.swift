//
//  WindowSelectionManager.swift
//  Fluttro
//
//  Manager for window selection overlay
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    private final class WindowSelectionOverlayPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    @MainActor
    final class WindowSelectionManager: ObservableObject {
        // MARK: - Properties

        private var overlayWindows: [NSWindow] = []
        private var onSelectionCallback: ((SCWindow?) -> Void)?
        private var onCancelCallback: (() -> Void)?
        private var captureMode: CaptureMode = .image
        private var isHiding = false

        // MARK: - Lifecycle

        deinit {
            // Clean up synchronously in deinit - avoid close() to prevent deadlock
            for window in overlayWindows {
                Task { @MainActor in
                    window.orderOut(nil)
                }
            }
        }

        // MARK: - Public Methods

        func show(
            captureMode: CaptureMode,
            onSelection: @escaping (SCWindow?) -> Void,
            onCancel: @escaping () -> Void
        ) {
            Logger.d("WindowSelectionManager: Showing window selection overlay")

            // Hide any existing overlay first
            hide()

            // Wait a moment for cleanup to complete
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

                // Store callback
                self.captureMode = captureMode
                self.onSelectionCallback = onSelection
                self.onCancelCallback = onCancel

                // Create overlay window
                self.createOverlayWindow()
            }
        }

        func hide() {
            guard !isHiding else {
                Logger.d("WindowSelectionManager: Already hiding, avoiding multiple calls")
                return
            }

            isHiding = true
            Logger.d("WindowSelectionManager: Hiding window selection overlay")

            // Safely hide window - avoid close() to prevent deadlock
            for window in overlayWindows {
                // Just hide the window, don't close it to avoid deadlock
                window.orderOut(nil)
            }
            overlayWindows.removeAll()

            onSelectionCallback = nil
            onCancelCallback = nil
            isHiding = false
        }

        // MARK: - Private Methods

        private func createOverlayWindow() {
            let screens = NSScreen.screens
            guard !screens.isEmpty else {
                Logger.e("WindowSelectionManager: No screens found")
                return
            }

            overlayWindows = screens.map { screen in
                let screenFrame = screen.frame
                let window = WindowSelectionOverlayPanel(
                    contentRect: screenFrame,
                    styleMask: [.nonactivatingPanel, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )

                WindowDepthManager.shared.setLevel(for: window, type: .windowSelectionOverlay)
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = false
                window.acceptsMouseMovedEvents = true
                window.becomesKeyOnlyIfNeeded = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

                let contentView = WindowSelectionOverlayView(
                    captureMode: captureMode,
                    screenFrame: screenFrame,
                    onSelection: { [weak self] selectedWindow in
                        self?.handleWindowSelection(selectedWindow)
                    },
                    onCancel: { [weak self] in
                        self?.handleCancel()
                    }
                )

                let hostingView = NSHostingView(rootView: contentView)
                hostingView.frame = CGRect(origin: .zero, size: screenFrame.size)
                window.contentView = hostingView
                window.initialFirstResponder = hostingView
                window.orderFront(nil)
                window.makeFirstResponder(hostingView)
                return window
            }

            overlayWindows.first?.makeKeyAndOrderFront(nil)

            Logger.s("WindowSelectionManager: Window selection overlay created and shown")
        }

        private func handleWindowSelection(_ window: SCWindow?) {
            Logger.d(
                "WindowSelectionManager: Window selection: \(String(describing: window?.title))"
            )

            // Call the callback (nie zamykamy overlay)
            onSelectionCallback?(window)
        }

        private func handleCancel() {
            Logger.d("WindowSelectionManager: Window selection cancelled")

            onCancelCallback?()
        }
    }

#endif
