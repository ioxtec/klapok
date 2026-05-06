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

    private final class AreaSelectionHostingView<Content: View>: NSHostingView<Content> {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }
    }

    // MARK: - Area Selection Manager

    final class AreaSelectionManager: ObservableObject {
        @Published var isPresented = false
        @Published var isRecording = false

        private var completion: ((NSRect?) -> Void)?
        private var overlayWindows: [NSWindow] = []
        private let selectionCoordinator = AreaSelectionCoordinator()
        private var cursorMonitors: [Any] = []
        private var didPushSelectionCursor = false
        private var isHiding = false

        // MARK: - Public Methods

        func show(completion: @escaping (NSRect?) -> Void) {
            self.completion = completion
            self.isPresented = true
            self.isRecording = false
            selectionCoordinator.reset()
            restoreRememberedSelectionIfNeeded()

            createOverlayWindow()
            startSelectionCursorOverride()
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
            overlayWindows.forEach { $0.close() }
            overlayWindows.removeAll()
            stopSelectionCursorOverride()

            let completionToCall = completion
            completion = nil
            selectionCoordinator.reset()
            isRecording = false

            completionToCall?(rect)
            isHiding = false
        }

        func getCurrentSelection() -> NSRect {
            return selectionCoordinator.currentSelection
        }
        
        func startRecording() {
            isRecording = true
            selectionCoordinator.isRecording = true
        }
        
        func stopRecording() {
            isRecording = false
            selectionCoordinator.isRecording = false
        }

        // MARK: - Private Methods

        private func createOverlayWindow() {
            Logger.d("AreaSelectionManager: Creating overlay windows for \(NSScreen.screens.count) screens")

            let screens = NSScreen.screens
            guard !screens.isEmpty else {
                Logger.e("AreaSelectionManager: ERROR - No screens found")
                return
            }

            overlayWindows = screens.map { screen in
                let overlayView = AreaSelectionView(
                    screenID: ScreenPixelGeometry.displayID(for: screen),
                    screenFrame: screen.frame,
                    onSelection: { rect in
                        Logger.s(
                            "AreaSelectionManager: Selection confirmed: \(String(describing: rect))")
                        self.hide(with: rect)
                    },
                    coordinator: self.selectionCoordinator
                )

                let hostingView = AreaSelectionHostingView(rootView: overlayView)

                let window = AreaSelectionOverlayPanel(
                    contentRect: screen.frame,
                    styleMask: [.nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )

                WindowDepthManager.shared.setLevel(for: window, type: .areaSelectionOverlay)
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = false
                window.contentView = hostingView
                window.acceptsMouseMovedEvents = true
                window.becomesKeyOnlyIfNeeded = false
                window.initialFirstResponder = hostingView

                // Try to cover menu bar and receive key events
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

                window.setFrame(screen.frame, display: true)
                window.orderFront(nil)
                window.makeFirstResponder(hostingView)
                window.invalidateCursorRects(for: hostingView)
                return window
            }

            overlayWindows.first?.makeKeyAndOrderFront(nil)

            Logger.s("AreaSelectionManager: Overlay window shown successfully")
        }

        private func restoreRememberedSelectionIfNeeded() {
            let settings = AppSettings.shared
            guard
                settings.areaSelectionLockEnabled,
                let rect = settings.lastAreaSelectionRect,
                !rect.isEmpty,
                let displayID = displayID(for: rect)
            else {
                return
            }

            selectionCoordinator.activeScreenID = displayID
            selectionCoordinator.currentSelection = rect
        }

        private func displayID(for rect: NSRect) -> CGDirectDisplayID? {
            let midpoint = NSPoint(x: rect.midX, y: rect.midY)
            let screenWithMidpoint = NSScreen.screens.first { $0.frame.contains(midpoint) }
            if let screenWithMidpoint {
                return ScreenPixelGeometry.displayID(for: screenWithMidpoint)
            }

            let bestMatchingScreen = NSScreen.screens.max { lhs, rhs in
                intersectionArea(between: lhs.frame, and: rect) < intersectionArea(between: rhs.frame, and: rect)
            }

            guard
                let bestMatchingScreen,
                intersectionArea(between: bestMatchingScreen.frame, and: rect) > 0
            else {
                return nil
            }

            return ScreenPixelGeometry.displayID(for: bestMatchingScreen)
        }

        private func intersectionArea(between lhs: NSRect, and rhs: NSRect) -> CGFloat {
            let intersection = lhs.intersection(rhs)
            return intersection.width * intersection.height
        }

        private func startSelectionCursorOverride() {
            guard !didPushSelectionCursor else { return }

            NSCursor.crosshair.push()
            NSCursor.crosshair.set()
            didPushSelectionCursor = true
        }

        private func stopSelectionCursorOverride() {
            cursorMonitors.forEach(NSEvent.removeMonitor)
            cursorMonitors.removeAll()

            if didPushSelectionCursor {
                NSCursor.pop()
                didPushSelectionCursor = false
            }

            NSCursor.arrow.set()
        }
    }

#endif
