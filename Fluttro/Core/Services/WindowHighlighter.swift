//
//  WindowHighlighter.swift
//  Fluttro
//
//  Service for highlighting windows with visual effects
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    @MainActor
    final class WindowHighlighter: ObservableObject {
        // MARK: - Properties

        private var highlightWindow: NSWindow?
        private var highlightTimer: Timer?
        private var currentWindow: SCWindow?

        // MARK: - Lifecycle

        deinit {
            // Clean up synchronously in deinit
            highlightTimer?.invalidate()
            highlightTimer = nil

            if let window = highlightWindow {
                window.close()
                highlightWindow = nil
            }

            currentWindow = nil
        }

        // MARK: - Public Methods

        func highlightWindow(_ window: SCWindow) {
            // Stop any existing highlighting
            stopHighlighting()

            currentWindow = window
            createHighlightOverlay(for: window)
            // DISABLED: startFlashingAnimation() - no animations to prevent deadlock
        }

        func stopHighlighting() {
            // Invalidate timer first to prevent new animations
            highlightTimer?.invalidate()
            highlightTimer = nil

            // Safely close and clear highlight window
            if let window = highlightWindow {
                window.close()
                highlightWindow = nil
            }

            currentWindow = nil
        }

        // MARK: - Private Methods

        private func createHighlightOverlay(for window: SCWindow) {
            // DISABLED: Creating separate NSWindow causes conflicts
            // Instead, we'll use a different approach - highlight via SwiftUI state
            // This prevents window level conflicts and NSHostingView issues

            // For now, just store the window frame for potential future use
            // The actual highlighting will be handled differently
            let windowFrame = window.frame
            // TODO: Implement highlighting via SwiftUI overlay instead of separate NSWindow
        }

        private func startFlashingAnimation() {
            var flashCount = 0
            let maxFlashes = 4

            highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) {
                [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }

                flashCount += 1

                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.animateFlash()
                }

                if flashCount >= maxFlashes {
                    timer.invalidate()
                    // Keep the highlight visible but stop flashing
                }
            }
        }

        private func animateFlash() {
            guard let overlay = highlightWindow else { return }

            // Animate opacity for flash effect
            NSAnimationContext.runAnimationGroup { [weak self] context in
                guard let self = self, let overlay = self.highlightWindow else { return }
                context.duration = 0.2
                overlay.animator().alphaValue = 0.8
            } completionHandler: { [weak self] in
                guard let self = self else { return }
                guard let overlay = self.highlightWindow else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    overlay.animator().alphaValue = 0.3
                }
            }
        }
    }

    // MARK: - Highlight View

    struct HighlightView: View {
        var body: some View {
            Rectangle()
                .stroke(Color.blue, lineWidth: 4)
                .background(Color.blue.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .padding(2)
                )
                .shadow(color: .blue, radius: 8, x: 0, y: 0)
        }
    }

#endif
