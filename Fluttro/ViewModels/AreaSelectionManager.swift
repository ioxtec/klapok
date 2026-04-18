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

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .crosshair)
        }

        override func cursorUpdate(with event: NSEvent) {
            NSCursor.crosshair.set()
        }

        override func mouseMoved(with event: NSEvent) {
            NSCursor.crosshair.set()
            super.mouseMoved(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            NSCursor.crosshair.set()
            super.mouseDragged(with: event)
        }

        override func mouseDown(with event: NSEvent) {
            NSCursor.crosshair.set()
            super.mouseDown(with: event)
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

        private func startSelectionCursorOverride() {
            guard !didPushSelectionCursor else { return }

            NSCursor.crosshair.push()
            NSCursor.crosshair.set()
            didPushSelectionCursor = true

            let events: NSEvent.EventTypeMask = [
                .cursorUpdate,
                .leftMouseDown,
                .leftMouseDragged,
                .mouseMoved,
            ]

            if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: events, handler: { event in
                NSCursor.crosshair.set()
                return event
            }) {
                cursorMonitors.append(localMonitor)
            }

            if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { _ in
                DispatchQueue.main.async {
                    NSCursor.crosshair.set()
                }
            }) {
                cursorMonitors.append(globalMonitor)
            }
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
