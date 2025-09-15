//
//  FloatingPanelViewModel.swift
//  Fluttro
//
//  ViewModel for floating panel controls
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    final class FloatingPanelViewModel: ObservableObject {
        // MARK: - Published Properties

        @Published var captureMode: CaptureMode = .image
        @Published var screenshotType: ScreenshotType = .fullScreen
        @Published var isCapturing: Bool = false
        @Published var isAreaSelectionActive: Bool = false
        @Published var isWindowSelectionActive: Bool = false
        @Published var selectedArea: NSRect = .zero
        @Published var selectedWindow: SCWindow?

        // MARK: - Dependencies

        private let screenshotService = ScreenshotService()
        private let editorViewModel: EditorViewModel
        private let areaSelectionManager = AreaSelectionManager()
        @MainActor private lazy var windowSelectionManager = WindowSelectionManager()

        // MARK: - Panel Visibility

        weak var panelWindow: NSPanel?

        @MainActor
        func hideFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Hiding floating panel")
            panelWindow?.orderOut(nil)
        }

        @MainActor
        func showFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Showing floating panel")
            panelWindow?.orderFront(nil)
            // Ensure floating panel is always on top
            if let panel = panelWindow {
                WindowDepthManager.shared.ensureFloatingPanelOnTop(panel)
            }
        }

        // MARK: - Initialization

        init(editorViewModel: EditorViewModel) {
            self.editorViewModel = editorViewModel
        }

        // MARK: - Public Methods

        @MainActor
        func setScreenshotType(_ newType: ScreenshotType) {
            let oldType = screenshotType
            screenshotType = newType
            handleScreenshotTypeChange(from: oldType, to: newType)
        }

        @MainActor
        func captureScreenshot() async {
            guard captureMode == .image else {
                Logger.w("Video recording not yet implemented")
                return
            }

            isCapturing = true
            defer {
                isCapturing = false
            }

            // Hide floating panel immediately when user clicks capture button
            hideFloatingPanel()

            // Small delay to ensure panel is hidden
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

            do {
                let image: NSImage

                switch screenshotType {
                case .fullScreen:
                    image = try await screenshotService.captureMainDisplay()

                case .area:
                    Logger.d("FloatingPanelViewModel: Area mode - checking for active selection")

                    if isAreaSelectionActive {
                        let currentSelection = areaSelectionManager.getCurrentSelection()
                        Logger.d("FloatingPanelViewModel: Got selection: \(currentSelection)")

                        if !currentSelection.isEmpty && currentSelection.width > 10
                            && currentSelection.height > 10
                        {
                            // Hide area selection overlay BEFORE taking screenshot
                            Logger.d(
                                "FloatingPanelViewModel: Hiding area selection overlay before screenshot"
                            )
                            areaSelectionManager.hide(with: nil)
                            isAreaSelectionActive = false

                            // Wait a bit for the overlay to disappear
                            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

                            // Now take the screenshot
                            image = try await screenshotService.captureArea(rect: currentSelection)
                        } else {
                            Logger.w("FloatingPanelViewModel: No valid selection")
                            showFloatingPanel()
                            return
                        }
                    } else {
                        Logger.w("FloatingPanelViewModel: Area selection not active")
                        showFloatingPanel()
                        return
                    }

                case .window:
                    guard let window = selectedWindow else {
                        Logger.w("No window selected")
                        // Pokaż komunikat o błędzie
                        showNoWindowSelectedMessage()
                        showFloatingPanel()
                        return
                    }
                    image = try await screenshotService.captureWindow(window)
                }

                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Editor opened successfully")

                // Ukryj window selection po udanym zrzucie
                if screenshotType == .window {
                    hideWindowSelection()
                }

                // Panel zostanie ukryty przez AppDelegate gdy edytor się otworzy

            } catch {
                Logger.e("FloatingPanelViewModel: Screenshot error: \(error)")

                // Ukryj overlay również w przypadku błędu
                if screenshotType == .window {
                    hideWindowSelection()
                }
                if screenshotType == .area {
                    hideAreaSelection()
                }

                // Pokaż panel z powrotem tylko w przypadku błędu
                showFloatingPanel()
            }
        }

        // MARK: - Private Methods

        @MainActor
        private func handleScreenshotTypeChange(
            from oldType: ScreenshotType, to newType: ScreenshotType
        ) {
            Logger.d(
                "FloatingPanelViewModel: Screenshot type changing from \(oldType) to \(newType)")

            // Clean up old mode with delay to prevent race conditions
            switch oldType {
            case .area:
                hideAreaSelection()
            case .window:
                hideWindowSelection()
            case .fullScreen:
                break
            }

            // Add delay before activating new mode to ensure cleanup is complete
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay

                // Activate new mode
                switch newType {
                case .fullScreen:
                    break
                case .area:
                    showAreaSelection()
                case .window:
                    showWindowSelection()
                }
            }
        }

        @MainActor
        private func showAreaSelection() {
            Logger.d("FloatingPanelViewModel: Showing area selection")
            WindowDepthManager.shared.logCurrentLevels()

            hideAreaSelection()

            Task {
                do {
                    let fullScreenImage = try await screenshotService.captureMainDisplay()
                    Logger.s("FloatingPanelViewModel: Background captured: \(fullScreenImage.size)")

                    await MainActor.run {
                        areaSelectionManager.show(backgroundImage: fullScreenImage) { rect in
                            Logger.s(
                                "FloatingPanelViewModel: Area selection completed: \(String(describing: rect))"
                            )
                            if let rect = rect {
                                self.selectedArea = rect
                                Task {
                                    await self.captureSelectedArea(rect: rect)
                                }
                            } else {
                                // User cancelled (pressed Esc) - just hide area selection
                                Logger.d(
                                    "FloatingPanelViewModel: Area selection cancelled"
                                )
                                self.hideAreaSelection()
                                // Don't automatically switch to fullScreen - let user choose
                            }
                        }

                        isAreaSelectionActive = true
                        Logger.s("FloatingPanelViewModel: Area selection active")
                    }
                } catch {
                    Logger.e("FloatingPanelViewModel: Error creating overlay: \(error)")
                }
            }
        }

        @MainActor
        private func hideAreaSelection() {
            Logger.d("FloatingPanelViewModel: Hiding area selection")

            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false
            //selectedArea = .zero

            Logger.d("FloatingPanelViewModel: Area selection hidden")
        }

        @MainActor
        private func captureSelectedArea(rect: NSRect) async {
            Logger.d("FloatingPanelViewModel: Capturing selected area: \(rect)")

            // Hide area selection overlay BEFORE taking screenshot
            Logger.d("FloatingPanelViewModel: Hiding area selection overlay before screenshot")
            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false

            // Wait a bit for the overlay to disappear
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await screenshotService.captureArea(rect: rect)
                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Area screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Area capture error: \(error)")
            }
        }

        @MainActor
        private func showWindowSelection() {
            Logger.d("FloatingPanelViewModel: Showing window selection")

            hideWindowSelection()

            windowSelectionManager.show { [weak self] selectedWindow in
                Logger.d(
                    "FloatingPanelViewModel: Window selection completed: \(String(describing: selectedWindow?.title))"
                )

                // Zawsze ustaw selectedWindow (może być nil jeśli odznaczono)
                self?.selectedWindow = selectedWindow

                if let window = selectedWindow {
                    Logger.d(
                        "FloatingPanelViewModel: Window selected: \(window.title ?? "Unknown")")
                } else {
                    Logger.d("FloatingPanelViewModel: Window deselected")
                }

                // NIE zamykamy overlay - zostaje otwarty dla dalszego wyboru
            }

            isWindowSelectionActive = true
            Logger.s("FloatingPanelViewModel: Window selection active")
        }

        @MainActor
        private func hideWindowSelection() {
            Logger.d("FloatingPanelViewModel: Hiding window selection")

            windowSelectionManager.hide()
            isWindowSelectionActive = false
            selectedWindow = nil

            Logger.d("FloatingPanelViewModel: Window selection hidden")
        }

        @MainActor
        private func captureSelectedWindow(window: SCWindow) async {
            Logger.d(
                "FloatingPanelViewModel: Capturing selected window: \(window.title ?? "Unknown")")

            // Hide window selection overlay
            hideWindowSelection()

            // Small delay to ensure overlay is hidden
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await screenshotService.captureWindow(window)
                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Window screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Window capture error: \(error)")
                showFloatingPanel()  // Show panel back on error
            }
        }

        // MARK: - Panel Visibility Control

        @MainActor
        func initializeCurrentMode() {
            Logger.d("FloatingPanelViewModel: Initializing current mode: \(screenshotType)")
            // Aktywuj aktualny tryb jeśli nie jest fullScreen
            switch screenshotType {
            case .area:
                if !isAreaSelectionActive {
                    showAreaSelection()
                }
            case .window:
                if !isWindowSelectionActive {
                    showWindowSelection()
                }
            case .fullScreen:
                break
            }
        }

        @MainActor
        private func showNoWindowSelectedMessage() {
            // Pokaż alert lub notification o braku zaznaczonego okna
            let alert = NSAlert()
            alert.messageText = "No Window Selected"
            alert.informativeText = "Please select a window first by clicking on it in the overlay."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")

            // Pokaż alert przez 3 sekundy i automatycznie zamknij
            alert.runModal()
        }
    }

#endif
