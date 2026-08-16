//
//  WindowPlacement.swift
//  Klapok
//
//  Utilities for placing AppKit windows on one physical display.
//

#if os(macOS)
    import AppKit
    import SwiftUI

    enum WindowPlacement {
        @MainActor
        static func center(_ window: NSWindow, on preferredScreen: NSScreen? = nil, margin: CGFloat = 24) {
            guard let screen = preferredScreen ?? screen(for: window) ?? screenUnderMouse() ?? NSScreen.main else {
                window.center()
                return
            }

            let visibleFrame = screen.visibleFrame.insetBy(dx: margin, dy: margin)
            var frame = window.frame

            let originX: CGFloat
            if frame.width >= visibleFrame.width {
                originX = visibleFrame.minX
            } else {
                originX = visibleFrame.midX - frame.width / 2
            }

            let originY: CGFloat
            if frame.height >= visibleFrame.height {
                originY = visibleFrame.minY
            } else {
                originY = visibleFrame.midY - frame.height / 2
            }

            let maxOriginX = Swift.max(visibleFrame.minX, visibleFrame.maxX - frame.width)
            let maxOriginY = Swift.max(visibleFrame.minY, visibleFrame.maxY - frame.height)

            frame.origin.x = clamp(originX, min: visibleFrame.minX, max: maxOriginX)
            frame.origin.y = clamp(originY, min: visibleFrame.minY, max: maxOriginY)
            window.setFrame(frame, display: true)
        }

        @MainActor
        static func screen(for window: NSWindow?) -> NSScreen? {
            if let screen = window?.screen {
                return screen
            }

            return nil
        }

        @MainActor
        static func screenUnderMouse() -> NSScreen? {
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { screen in
                screen.frame.contains(mouseLocation)
            }
        }

        @MainActor
        static func centerModalPanel(
            _ panel: NSPanel,
            relativeTo referenceWindow: NSWindow? = nil,
            margin: CGFloat = 24
        ) {
            let resolvedWindow = referenceWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
            center(panel, on: screen(for: resolvedWindow) ?? screenUnderMouse(), margin: margin)
        }

        private static func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
            Swift.min(Swift.max(value, minValue), maxValue)
        }
    }

    struct WindowCenteringAnchor: NSViewRepresentable {
        let preferredScreen: NSScreen?

        init(preferredScreen: NSScreen? = nil) {
            self.preferredScreen = preferredScreen
        }

        func makeNSView(context: Context) -> CenteringAnchorView {
            let view = CenteringAnchorView()
            view.preferredScreen = preferredScreen
            return view
        }

        func updateNSView(_ nsView: CenteringAnchorView, context: Context) {
            nsView.preferredScreen = preferredScreen
        }
    }

    final class CenteringAnchorView: NSView {
        var preferredScreen: NSScreen?
        private weak var lastCenteredWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            centerWindowIfNeeded()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            centerWindowIfNeeded()
        }

        private func centerWindowIfNeeded() {
            guard let window, window !== lastCenteredWindow else { return }
            lastCenteredWindow = window

            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                WindowPlacement.center(window, on: self.preferredScreen)
            }
        }
    }

    extension View {
        func centeredSheetWindow(preferredScreen: NSScreen? = nil) -> some View {
            background(WindowCenteringAnchor(preferredScreen: preferredScreen))
        }
    }
#endif
