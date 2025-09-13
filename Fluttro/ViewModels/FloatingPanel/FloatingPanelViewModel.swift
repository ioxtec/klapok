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

        // MARK: - Panel Visibility

        weak var panelWindow: NSPanel?

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
                            image = try await screenshotService.captureArea(rect: currentSelection)
                            // Hide area selection overlay
                            areaSelectionManager.hide(with: nil)
                            isAreaSelectionActive = false
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
                        showFloatingPanel()
                        return
                    }
                    image = try await screenshotService.captureWindow(window)
                    hideWindowSelection()
                }

                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Editor opened successfully")
                // Panel zostanie ukryty przez AppDelegate gdy edytor się otworzy

            } catch {
                Logger.e("FloatingPanelViewModel: Screenshot error: \(error)")
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

            // Clean up old mode
            switch oldType {
            case .area:
                hideAreaSelection()
            case .window:
                hideWindowSelection()
            case .fullScreen:
                break
            }

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

        @MainActor
        private func showAreaSelection() {
            Logger.d("FloatingPanelViewModel: Showing area selection")

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
                                // User cancelled (pressed Esc) - change back to fullScreen mode
                                Logger.d(
                                    "FloatingPanelViewModel: Area selection cancelled, switching to fullScreen"
                                )
                                self.hideAreaSelection()
                                self.screenshotType = .fullScreen
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

            // Hide area selection overlay
            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false

            do {
                let image = try await screenshotService.captureArea(rect: rect)
                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Area screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Area capture error: \(error)")
            }
        }

        private func showWindowSelection() {
            isWindowSelectionActive = true
            Logger.d("Window selection mode active")
        }

        private func hideWindowSelection() {
            isWindowSelectionActive = false
            selectedWindow = nil
        }

        // MARK: - Panel Visibility Control

        @MainActor
        private func hideFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Hiding floating panel for screenshot")
            panelWindow?.orderOut(nil)
        }

        @MainActor
        private func showFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Showing floating panel after screenshot")
            panelWindow?.orderFront(nil)
        }
    }

#endif
