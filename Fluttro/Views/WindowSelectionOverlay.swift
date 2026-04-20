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

    private struct WindowSelectionItem: Identifiable, Equatable {
        let id: CGWindowID
        let window: SCWindow
        let frame: CGRect
        let displayName: String

        init(window: SCWindow) {
            self.id = window.windowID
            self.window = window
            self.frame = window.frame

            if let appName = window.owningApplication?.applicationName,
                let title = window.title, !title.isEmpty
            {
                self.displayName = "\(appName) - \(title)"
            } else if let appName = window.owningApplication?.applicationName {
                self.displayName = appName
            } else if let title = window.title, !title.isEmpty {
                self.displayName = title
            } else {
                self.displayName = "Unknown window"
            }
        }

        static func == (lhs: WindowSelectionItem, rhs: WindowSelectionItem) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Window Selection View

    struct WindowSelectionOverlayView: View {
        let screenFrame: CGRect
        let onSelection: (SCWindow?) -> Void
        let onCancel: () -> Void
        @State private var availableWindows: [WindowSelectionItem] = []
        @State private var hoveredWindow: WindowSelectionItem?
        @State private var selectedWindow: WindowSelectionItem?
        @State private var isLoading: Bool = true
        @State private var lastHoverUpdate: TimeInterval = 0
        private let hoverThrottleInterval: TimeInterval = 1.0 / 30.0

        var body: some View {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea(.all)

                // Window highlighting overlays

                // Selected window (red frame)
                if let selectedWindow = selectedWindow {
                    WindowFrameHighlight(
                        item: selectedWindow,
                        screenFrame: screenFrame,
                        color: .red,
                        label: "SELECTED"
                    )
                }

                // Hovered window (blue frame) - only if different from selected
                if let hoveredWindow = hoveredWindow,
                    hoveredWindow.id != selectedWindow?.id
                {
                    WindowFrameHighlight(
                        item: hoveredWindow,
                        screenFrame: screenFrame,
                        color: .blue,
                        label: nil
                    )
                }

                // Instructions
                VStack {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)

                            Text("Loading available windows...")
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

                                Text(selectedWindow.displayName)
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
                                    Text("Hovering: \(hoveredWindow.displayName)")
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
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard !isLoading else { return }

                    // Throttle hover updates to prevent performance issues
                    let now = ProcessInfo.processInfo.systemUptime
                    if now - lastHoverUpdate >= hoverThrottleInterval {
                        lastHoverUpdate = now

                        // Find window under cursor
                        let screenLocation = convertToScreenCoordinates(location)
                        let windowUnderCursor = findWindowUnderCursor(at: screenLocation)

                        // Update hovered window with SwiftUI highlighting
                        if windowUnderCursor != hoveredWindow {
                            hoveredWindow = windowUnderCursor
                        }
                    }
                case .ended:
                    // Reset on hover end
                    hoveredWindow = nil
                }
            }
            .onTapGesture { location in
                if let window = hoveredWindow {
                    // Toggle logic: if clicked window is already selected, deselect it
                    if selectedWindow?.id == window.id {
                        selectedWindow = nil
                        onSelection(nil)  // Pass nil = no selection
                    } else {
                        selectedWindow = window
                        onSelection(window.window)  // Pass newly selected window
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
                hoveredWindow = nil
            }
        }

        // MARK: - Private Methods

        private func loadAvailableWindows() {
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                    Logger.d("WindowSelection: Found \(content.windows.count) total windows")

                    let windows = content.windows.compactMap { window -> WindowSelectionItem? in
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

                        return WindowSelectionItem(window: window)
                    }

                    Logger.d("WindowSelection: After filtering: \(windows.count) windows available")
                    for item in windows.prefix(5) {
                        Logger.d(
                            "WindowSelection: Available window: \(item.displayName)"
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

        private func findWindowUnderCursor(at screenLocation: CGPoint) -> WindowSelectionItem? {
            guard !availableWindows.isEmpty else {
                return nil
            }

            for window in availableWindows {
                if window.frame.contains(screenLocation) {
                    return window
                }
            }

            return nil
        }

        private func convertToScreenCoordinates(_ point: CGPoint) -> CGPoint {
            let screenHeight = screenFrame.height

            return CGPoint(
                x: screenFrame.minX + point.x,
                y: screenFrame.minY + (screenHeight - point.y)
            )
        }
    }

    // MARK: - Window Frame Highlight

    private struct WindowFrameHighlight: View {
        let item: WindowSelectionItem
        let screenFrame: CGRect
        let color: Color
        let label: String?

        var body: some View {
            let windowFrame = item.frame
            let localFrame = windowFrame.intersection(screenFrame)
            let frameToDraw = localFrame.isNull ? windowFrame : localFrame

            // Convert window coordinates to SwiftUI coordinates
            let swiftUIFrame = CGRect(
                x: frameToDraw.minX - screenFrame.minX,
                y: screenFrame.maxY - frameToDraw.maxY,
                width: frameToDraw.width,
                height: frameToDraw.height
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
                                Text(item.displayName)
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
                .opacity(swiftUIFrame.isEmpty ? 0 : 1)
                .allowsHitTesting(false)  // Don't interfere with mouse events
        }
    }

    #Preview {
        WindowSelectionOverlayView(
            screenFrame: NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900),
            onSelection: { _ in },
            onCancel: {}
        )
    }

#endif
