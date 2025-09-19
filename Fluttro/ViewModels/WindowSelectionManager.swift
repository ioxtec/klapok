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

    @MainActor
    final class WindowSelectionManager: ObservableObject {
        // MARK: - Properties

        private var overlayWindow: NSWindow?
        private var onSelectionCallback: ((SCWindow?) -> Void)?
        private var isHiding = false

        // MARK: - Lifecycle

        deinit {
            // Clean up synchronously in deinit - avoid close() to prevent deadlock
            if let window = overlayWindow {
                Task { @MainActor in
                    window.orderOut(nil)
                }
            }
        }

        // MARK: - Public Methods

        func show(onSelection: @escaping (SCWindow?) -> Void) {
            Logger.d("WindowSelectionManager: Showing window selection overlay")

            // Hide any existing overlay first
            hide()

            // Wait a moment for cleanup to complete
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

                // Store callback
                self.onSelectionCallback = onSelection

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
            if let window = overlayWindow {
                // Just hide the window, don't close it to avoid deadlock
                window.orderOut(nil)

                // Clear reference and let garbage collection handle cleanup
                overlayWindow = nil
            }

            onSelectionCallback = nil
            isHiding = false
        }

        // MARK: - Private Methods

        private func createOverlayWindow() {
            guard let screen = NSScreen.main else {
                Logger.e("WindowSelectionManager: No main screen found")
                return
            }

            let screenFrame = screen.frame

            // Create window that covers the entire screen
            overlayWindow = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )

            guard let window = overlayWindow else { return }

            // Configure window using WindowDepthManager
            WindowDepthManager.shared.setLevel(for: window, type: .windowSelectionOverlay)
            window.backgroundColor = NSColor.clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Create SwiftUI view
            let contentView = WindowSelectionOverlayView(
                onSelection: { [weak self] selectedWindow in
                    self?.handleWindowSelection(selectedWindow)
                },
                onCancel: { [weak self] in
                    self?.handleCancel()
                }
            )

            // Set up hosting view
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = screenFrame
            window.contentView = hostingView

            // Show window
            window.makeKeyAndOrderFront(nil)

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

            // Call the callback with nil (anulowanie)
            onSelectionCallback?(nil)

            // Hide overlay
            hide()
        }
    }

#endif
