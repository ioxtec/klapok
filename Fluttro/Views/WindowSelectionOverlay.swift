//
//  WindowSelectionOverlay.swift
//  Fluttro
//
//  Advanced window selection overlay with hover preview and window highlighting
//

import SwiftUI

#if os(macOS)
    import AppKit
    import CoreGraphics
    import ScreenCaptureKit

    private struct WindowSelectionItem: Identifiable, Equatable {
        let id: CGWindowID
        let window: SCWindow
        let frame: CGRect
        let displayName: String
        let zOrder: Int
        let area: CGFloat

        init(window: SCWindow, zOrder: Int) {
            self.id = window.windowID
            self.window = window
            self.frame = window.frame
            self.zOrder = zOrder
            self.area = window.frame.width * window.frame.height

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

    private struct WindowServerMetadata {
        let windowID: CGWindowID
        let zOrder: Int
        let layer: Int
        let alpha: Double
    }

    @MainActor
    private final class WindowSelectionOverlayState: ObservableObject {
        @Published var availableWindows: [WindowSelectionItem] = []
        @Published var hoveredWindow: WindowSelectionItem?
        @Published var selectedWindow: WindowSelectionItem?
        @Published var isLoading = true
        @Published var lastHoverUpdate: TimeInterval = 0
    }

    private enum WindowSelectionCoordinateSpace {
        static func desktopBounds() -> CGRect {
            NSScreen.screens
                .map(\.frame)
                .reduce(.null) { partialResult, frame in
                    partialResult.isNull ? frame : partialResult.union(frame)
                }
        }

        static func topLeftScreenFrame(for appKitScreenFrame: CGRect) -> CGRect {
            let desktop = desktopBounds()
            guard !desktop.isNull else { return appKitScreenFrame }

            return CGRect(
                x: appKitScreenFrame.minX - desktop.minX,
                y: desktop.maxY - appKitScreenFrame.maxY,
                width: appKitScreenFrame.width,
                height: appKitScreenFrame.height
            )
        }

        static func topLeftPoint(
            from point: CGPoint,
            in appKitScreenFrame: CGRect
        ) -> CGPoint {
            let screenFrame = topLeftScreenFrame(for: appKitScreenFrame)
            return CGPoint(
                x: screenFrame.minX + point.x,
                y: screenFrame.minY + point.y
            )
        }

        static func localFrame(
            for windowFrame: CGRect,
            in appKitScreenFrame: CGRect
        ) -> CGRect {
            let screenFrame = topLeftScreenFrame(for: appKitScreenFrame)
            let visibleFrame = windowFrame.intersection(screenFrame)
            let frameToDraw = visibleFrame.isNull ? windowFrame : visibleFrame

            return CGRect(
                x: frameToDraw.minX - screenFrame.minX,
                y: frameToDraw.minY - screenFrame.minY,
                width: frameToDraw.width,
                height: frameToDraw.height
            )
        }
    }

    // MARK: - Window Selection View

    struct WindowSelectionOverlayView: View {
        let captureMode: CaptureMode
        let screenFrame: CGRect
        let onSelection: (SCWindow?) -> Void
        let onCancel: () -> Void
        @StateObject private var viewState = WindowSelectionOverlayState()
        private let hoverThrottleInterval: TimeInterval = 1.0 / 30.0

        private var availableWindows: [WindowSelectionItem] {
            get { viewState.availableWindows }
            nonmutating set { viewState.availableWindows = newValue }
        }

        private var hoveredWindow: WindowSelectionItem? {
            get { viewState.hoveredWindow }
            nonmutating set { viewState.hoveredWindow = newValue }
        }

        private var selectedWindow: WindowSelectionItem? {
            get { viewState.selectedWindow }
            nonmutating set { viewState.selectedWindow = newValue }
        }

        private var isLoading: Bool {
            get { viewState.isLoading }
            nonmutating set { viewState.isLoading = newValue }
        }

        private var lastHoverUpdate: TimeInterval {
            get { viewState.lastHoverUpdate }
            nonmutating set { viewState.lastHoverUpdate = newValue }
        }

        private var selectionTitle: String {
            captureMode == .video ? "Select a window to record" : "Select a window to capture"
        }

        private var selectedHint: String {
            captureMode == .video
                ? "Click the record button to start • ESC to cancel"
                : "Click the camera button to capture • ESC to cancel"
        }

        private var unselectedHint: String {
            captureMode == .video
                ? "Click on a window to select it • ESC to cancel"
                : "Click on a window to select it • ESC to cancel"
        }

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
                                Text(selectionTitle)
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
                                    ? selectedHint
                                    : unselectedHint
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
                    let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                    let windowServerMetadata = loadWindowServerMetadata()
                    let windowServerMetadataByID = Dictionary(
                        uniqueKeysWithValues: windowServerMetadata.map { ($0.windowID, $0) }
                    )

                    Logger.d("WindowSelection: Found \(content.windows.count) total windows")

                    let windows = content.windows.compactMap { window -> WindowSelectionItem? in
                        // Filter out system windows and very small windows
                        guard let app = window.owningApplication else {
                            return nil
                        }

                        guard let metadata = windowServerMetadataByID[window.windowID] else {
                            return nil
                        }

                        let frame = window.frame
                        guard frame.width > 100 && frame.height > 100 else {
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
                            "com.apple.notificationcenterui",
                            "com.apple.notificationcenter",
                            "com.apple.controlcenter",
                        ]

                        let title = window.title ?? ""

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

                        if app.applicationName == "NotificationCenter" {
                            Logger.d("WindowSelection: Filtering out NotificationCenter window: \(title)")
                            return nil
                        }

                        if metadata.layer != 0 || metadata.alpha <= 0.01 {
                            Logger.d(
                                "WindowSelection: Filtering out non-standard window \(title) layer=\(metadata.layer) alpha=\(metadata.alpha)"
                            )
                            return nil
                        }

                        // Filter out windows that are likely system dialogs (very specific sizes)
                        if (frame.width == 480 && frame.height == 270)  // Common dialog size
                            || (frame.width == 400 && frame.height == 200)  // Another common size
                            || (frame.width < 200 && frame.height < 150)
                        {  // Very small dialogs
                            return nil
                        }

                        return WindowSelectionItem(window: window, zOrder: metadata.zOrder)
                    }
                    .sorted { lhs, rhs in
                        if lhs.zOrder != rhs.zOrder {
                            return lhs.zOrder < rhs.zOrder
                        }
                        return lhs.area < rhs.area
                    }

                    Logger.d("WindowSelection: After filtering: \(windows.count) windows available")
                    for item in windows.prefix(5) {
                        Logger.d(
                            "WindowSelection: Available window: \(item.displayName) z=\(item.zOrder)"
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

            let candidates = availableWindows.filter { $0.frame.contains(screenLocation) }
            guard !candidates.isEmpty else { return nil }

            let screenArea = max(1, screenFrame.width * screenFrame.height)

            return candidates.sorted { lhs, rhs in
                let lhsNearlyFullscreen = lhs.area / screenArea > 0.8
                let rhsNearlyFullscreen = rhs.area / screenArea > 0.8
                if lhsNearlyFullscreen != rhsNearlyFullscreen {
                    return !lhsNearlyFullscreen && rhsNearlyFullscreen
                }

                let minArea = max(1, min(lhs.area, rhs.area))
                let maxArea = max(lhs.area, rhs.area)
                if maxArea / minArea > 1.35, abs(lhs.zOrder - rhs.zOrder) <= 6 {
                    return lhs.area < rhs.area
                }

                if lhs.zOrder != rhs.zOrder {
                    return lhs.zOrder < rhs.zOrder
                }

                return lhs.area < rhs.area
            }.first
        }

        private func convertToScreenCoordinates(_ point: CGPoint) -> CGPoint {
            WindowSelectionCoordinateSpace.topLeftPoint(from: point, in: screenFrame)
        }

        private func loadWindowServerMetadata() -> [WindowServerMetadata] {
            guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]]
            else {
                return []
            }

            return windowInfo.enumerated().compactMap { index, entry in
                guard let number = entry[kCGWindowNumber as String] as? NSNumber else {
                    return nil
                }

                let layer = (entry[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
                let alpha = (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0

                return WindowServerMetadata(
                    windowID: CGWindowID(number.uint32Value),
                    zOrder: index,
                    layer: layer,
                    alpha: alpha
                )
            }
        }
    }

    // MARK: - Window Frame Highlight

    private struct WindowFrameHighlight: View {
        let item: WindowSelectionItem
        let screenFrame: CGRect
        let color: Color
        let label: String?

        var body: some View {
            let swiftUIFrame = WindowSelectionCoordinateSpace.localFrame(
                for: item.frame,
                in: screenFrame
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

#endif
