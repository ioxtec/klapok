//
//  WindowDepthManager.swift
//  Fluttro
//
//  Manages window levels to ensure proper layering
//

import Foundation

#if os(macOS)
    import AppKit

    /// Manages window depth levels to ensure proper layering
    final class WindowDepthManager {
        static let shared = WindowDepthManager()

        // MARK: - Window Level Constants

        /// Base level for all Fluttro windows
        private let baseLevel = Int(CGWindowLevelForKey(.screenSaverWindow))

        /// Window level definitions
        enum WindowType {
            case editor
            case floatingPanel
            case pinnedFloatingPanel
            case windowSelectionOverlay
            case areaSelectionOverlay

            var offset: Int {
                switch self {
                case .editor:
                    return 0  // Normal level
                case .areaSelectionOverlay:
                    return 20  // Above normal overlays
                case .windowSelectionOverlay:
                    return 25  // Above area selection
                case .floatingPanel:
                    return 100  // Above all overlays
                case .pinnedFloatingPanel:
                    return 120  // Pinned panel stays above the regular floating panel
                }
            }
        }

        // MARK: - Private Init

        private init() {}

        // MARK: - Public Methods

        /// Gets the appropriate window level for a window type
        func level(for windowType: WindowType) -> NSWindow.Level {
            let level = baseLevel + windowType.offset
            Logger.d("WindowDepthManager: Level for \(windowType) = \(level)")
            return NSWindow.Level(rawValue: level)
        }

        /// Sets the window level for a window
        func setLevel(for window: NSWindow, type: WindowType) {
            let level = self.level(for: type)
            window.level = level
            Logger.d("WindowDepthManager: Set window level to \(level.rawValue) for type \(type)")
        }

        /// Ensures floating panel is always on top
        func ensureFloatingPanelOnTop(_ panel: NSPanel, pinned: Bool = false) {
            setLevel(for: panel, type: pinned ? .pinnedFloatingPanel : .floatingPanel)
            Logger.d("WindowDepthManager: Ensured floating panel is on top")
        }

        /// Gets all window levels for debugging
        func getAllLevels() -> [String: Int] {
            return [
                "editor": level(for: .editor).rawValue,
                "areaSelectionOverlay": level(for: .areaSelectionOverlay).rawValue,
                "windowSelectionOverlay": level(for: .windowSelectionOverlay).rawValue,
                "floatingPanel": level(for: .floatingPanel).rawValue,
                "pinnedFloatingPanel": level(for: .pinnedFloatingPanel).rawValue,
            ]
        }

        /// Logs current window levels for debugging
        func logCurrentLevels() {
            let levels = getAllLevels()
            Logger.d("WindowDepthManager: Current levels:")
            for (type, level) in levels.sorted(by: { $0.value < $1.value }) {
                Logger.d("  \(type): \(level)")
            }
        }
    }

#endif
