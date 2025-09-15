//
//  WindowSelectionOverlay.swift
//  Fluttro
//
//  Advanced window selection overlay with hover preview and window highlighting
//

import SwiftUI

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    // MARK: - Window Selection View

    struct WindowSelectionOverlayView: View {
        let onSelection: (SCWindow?) -> Void
        let onCancel: () -> Void
        @State private var availableWindows: [SCWindow] = []
        @State private var hoveredWindow: SCWindow?
        @State private var selectedWindow: SCWindow?
        @State private var mousePosition: CGPoint = .zero
        @State private var isLoading: Bool = true
        @StateObject private var windowHighlighter = WindowHighlighter()
        @State private var lastHoverUpdate: Date = Date()
        @State private var isProcessingHover: Bool = false
        private let hoverThrottleInterval: TimeInterval = 0.5  // 500ms throttle - jeszcze więcej

        var body: some View {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea(.all)

                // Window highlighting overlays

                // Selected window (czerwona ramka)
                if let selectedWindow = selectedWindow {
                    WindowFrameHighlight(window: selectedWindow, color: .red, label: "SELECTED")
                }

                // Hovered window (niebieska ramka) - tylko jeśli różne od selected
                if let hoveredWindow = hoveredWindow,
                    hoveredWindow.windowID != selectedWindow?.windowID
                {
                    WindowFrameHighlight(window: hoveredWindow, color: .blue, label: nil)
                }

                // Instructions
                VStack {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)

                            Text("Ładowanie dostępnych okien...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            if let selectedWindow = selectedWindow {
                                Text("Selected Window:")
                                    .foregroundColor(.white)
                                    .font(.headline)

                                Text(windowDisplayName(selectedWindow))
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(6)

                            } else {
                                Text("Select a window to capture")
                                    .foregroundColor(.white)
                                    .font(.headline)

                                if let hoveredWindow = hoveredWindow {
                                    Text("Hovering: \(windowDisplayName(hoveredWindow))")
                                        .foregroundColor(.yellow)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(6)
                                }
                            }

                            Text(
                                selectedWindow != nil
                                    ? "Click the camera button to capture • ESC to cancel"
                                    : "Click on a window to select it • ESC to cancel"
                            )
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding(.top, 50)

                // Mouse position indicator (for debugging)
                if !isLoading {
                    VStack {
                        HStack {
                            Text("x:\(Int(mousePosition.x)), y:\(Int(mousePosition.y))")
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .font(.system(size: 10, design: .monospaced))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.leading, 10)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mousePosition = location

                    // Skip if still loading or processing
                    guard !isLoading && !isProcessingHover else { return }

                    // Throttle hover updates to prevent performance issues
                    let now = Date()
                    if now.timeIntervalSince(lastHoverUpdate) >= hoverThrottleInterval {
                        lastHoverUpdate = now
                        isProcessingHover = true

                        // Find window under cursor
                        let screenLocation = convertToScreenCoordinates(location)
                        let windowUnderCursor = findWindowUnderCursor(at: screenLocation)

                        // Update hovered window with SwiftUI highlighting
                        if windowUnderCursor != hoveredWindow {
                            hoveredWindow = windowUnderCursor
                        }

                        isProcessingHover = false
                    }
                case .ended:
                    // Reset on hover end
                    hoveredWindow = nil
                }
            }
            .onTapGesture { location in
                if let window = hoveredWindow {
                    // Toggle logic: jeśli kliknięte okno jest już zaznaczone, odznacz je
                    if selectedWindow?.windowID == window.windowID {
                        selectedWindow = nil
                        onSelection(nil)  // Przekaż nil = brak zaznaczenia
                    } else {
                        selectedWindow = window
                        onSelection(window)  // Przekaż nowe zaznaczone okno
                    }
                }
            }
            .onKeyPress(.escape) {
                onCancel()
                return .handled
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                loadAvailableWindows()
            }
            .onDisappear {
                isProcessingHover = false
                hoveredWindow = nil
            }
        }

        // MARK: - Private Methods

        private func loadAvailableWindows() {
            Task {
                do {
                    let content = try await SCShareableContent.current

                    Logger.d("WindowSelection: Found \(content.windows.count) total windows")

                    let windows = content.windows.compactMap { window -> SCWindow? in
                        // Filter out system windows and very small windows
                        guard let app = window.owningApplication else {
                            return nil
                        }

                        let frame = window.frame
                        guard frame.width > 100 && frame.height > 100 else {
                            return nil
                        }

                        guard let title = window.title, !title.isEmpty else {
                            return nil
                        }

                        // Filter out our own app windows
                        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                            return nil
                        }

                        // Filter out only the most problematic system windows
                        let problematicTitles = [
                            "Force Quit Applications",
                            "Screenshot",
                        ]

                        let problematicBundleIds = [
                            "com.apple.loginwindow",
                            "com.apple.systemuiserver",
                            "com.apple.dock",
                            "com.apple.screencapture",
                        ]

                        // Check title - only filter the most problematic ones
                        if problematicTitles.contains(where: { title.contains($0) }) {
                            Logger.d("WindowSelection: Filtering out problematic title: \(title)")
                            return nil
                        }

                        // Check bundle identifier - only filter system UI elements
                        let bundleId = app.bundleIdentifier
                        if problematicBundleIds.contains(bundleId) {
                            Logger.d(
                                "WindowSelection: Filtering out problematic bundle: \(bundleId)")
                            return nil
                        }

                        // Filter out windows that are likely system dialogs (very specific sizes)
                        if (frame.width == 480 && frame.height == 270)  // Common dialog size
                            || (frame.width == 400 && frame.height == 200)  // Another common size
                            || (frame.width < 200 && frame.height < 150)
                        {  // Very small dialogs
                            return nil
                        }

                        return window
                    }

                    Logger.d("WindowSelection: After filtering: \(windows.count) windows available")
                    for window in windows.prefix(5) {
                        Logger.d(
                            "WindowSelection: Available window: \(window.title ?? "No title") - \(window.owningApplication?.applicationName ?? "No app")"
                        )
                    }

                    await MainActor.run {
                        self.availableWindows = windows
                        self.isLoading = false
                    }
                } catch {
                    Logger.e("WindowSelection: Error loading windows: \(error)")
                    await MainActor.run {
                        self.isLoading = false
                        self.availableWindows = []
                    }
                }
            }
        }

        private func updateHoveredWindow(at location: CGPoint) {
            guard !isLoading else {
                return
            }

            // Convert screen coordinates to find the window under cursor
            let screenLocation = convertToScreenCoordinates(location)

            // Safely find window under cursor
            let windowUnderCursor = findWindowUnderCursor(at: screenLocation)

            if windowUnderCursor != hoveredWindow {
                // DISABLED: Stop previous highlighting safely
                // windowHighlighter.stopHighlighting()

                hoveredWindow = windowUnderCursor

                if let window = windowUnderCursor {
                    // DISABLED: windowHighlighter.highlightWindow(window)
                }
            }
        }

        private func findWindowUnderCursor(at screenLocation: CGPoint) -> SCWindow? {
            guard !availableWindows.isEmpty else {
                return nil
            }

            // Limit to first 20 windows to prevent performance issues
            let windowsToCheck = Array(availableWindows.prefix(20))

            for window in windowsToCheck {
                let windowFrame = window.frame
                if windowFrame.contains(screenLocation) {
                    return window
                }
            }

            return nil
        }

        private func windowDisplayName(_ window: SCWindow) -> String {
            if let appName = window.owningApplication?.applicationName,
                let title = window.title, !title.isEmpty
            {
                return "\(appName) - \(title)"
            } else if let appName = window.owningApplication?.applicationName {
                return appName
            } else if let title = window.title, !title.isEmpty {
                return title
            } else {
                return "Nieznane okno"
            }
        }

        private func convertToScreenCoordinates(_ point: CGPoint) -> CGPoint {
            guard let screen = NSScreen.main else {
                return point
            }

            let screenFrame = screen.frame
            let screenHeight = screenFrame.height

            return CGPoint(
                x: screenFrame.minX + point.x,
                y: screenFrame.minY + (screenHeight - point.y)
            )
        }
    }

    // MARK: - Window Frame Highlight

    struct WindowFrameHighlight: View {
        let window: SCWindow
        let color: Color
        let label: String?

        var body: some View {
            let windowFrame = window.frame
            let screenFrame = NSScreen.main?.frame ?? .zero

            // Convert window coordinates to SwiftUI coordinates
            let swiftUIFrame = CGRect(
                x: windowFrame.minX,
                y: screenFrame.height - windowFrame.maxY,
                width: windowFrame.width,
                height: windowFrame.height
            )

            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                )
                .overlay(
                    // Window name in top-left corner
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if let label = label {
                                    Text(label)
                                        .foregroundColor(.white)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(color)
                                        .cornerRadius(3)
                                }
                                Text(windowDisplayName(window))
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(color)
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                )
                .frame(width: swiftUIFrame.width, height: swiftUIFrame.height)
                .position(x: swiftUIFrame.midX, y: swiftUIFrame.midY)
                .allowsHitTesting(false)  // Don't interfere with mouse events
        }

        private func windowDisplayName(_ window: SCWindow) -> String {
            if let appName = window.owningApplication?.applicationName,
                let title = window.title, !title.isEmpty
            {
                return "\(appName) - \(title)"
            } else if let appName = window.owningApplication?.applicationName {
                return appName
            } else if let title = window.title, !title.isEmpty {
                return title
            } else {
                return "Nieznane okno"
            }
        }
    }

    #Preview {
        WindowSelectionOverlayView(
            onSelection: { window in
                print("Selected window: \(String(describing: window))")
            },
            onCancel: {
                print("Selection cancelled")
            }
        )
    }

#endif
