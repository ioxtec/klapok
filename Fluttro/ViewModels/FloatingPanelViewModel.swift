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

    enum CaptureMode: CaseIterable {
        case image
        case video

        var iconName: String {
            switch self {
            case .image: return "camera"
            case .video: return "video"
            }
        }

        var title: String {
            switch self {
            case .image: return "Obraz"
            case .video: return "Video"
            }
        }
    }

    enum ScreenshotType: CaseIterable {
        case fullScreen
        case area
        case window

        var iconName: String {
            switch self {
            case .fullScreen: return "rectangle.on.rectangle"
            case .area: return "viewfinder"
            case .window: return "macwindow"
            }
        }

        var title: String {
            switch self {
            case .fullScreen: return "Cały ekran"
            case .area: return "Wycinek"
            case .window: return "Okno"
            }
        }
    }

    final class FloatingPanelViewModel: ObservableObject {
        @Published var captureMode: CaptureMode = .image
        @Published var screenshotType: ScreenshotType = .fullScreen
        @Published var isCapturing: Bool = false
        @Published var isAreaSelectionActive: Bool = false
        @Published var isWindowSelectionActive: Bool = false
        @Published var selectedArea: NSRect = .zero
        @Published var selectedWindow: SCWindow?

        private let screenshotService = ScreenshotService()
        private let editorViewModel: EditorViewModel
        private var areaSelectionOverlay: AreaSelectionOverlay?

        // SwiftUI overlay manager
        @Published var areaSelectionManager: SwiftUIAreaSelectionManager

        init(editorViewModel: EditorViewModel) {
            self.editorViewModel = editorViewModel
            self.areaSelectionManager = SwiftUIAreaSelectionManager()
        }

        @MainActor
        func setScreenshotType(_ newType: ScreenshotType) {
            let oldType = screenshotType
            screenshotType = newType
            handleScreenshotTypeChange(from: oldType, to: newType)
        }

        @MainActor
        private func handleScreenshotTypeChange(
            from oldType: ScreenshotType, to newType: ScreenshotType
        ) {
            print("FloatingPanelViewModel: Screenshot type changing from \(oldType) to \(newType)")

            // Wyczyść poprzedni tryb SYNCHRONICZNIE
            switch oldType {
            case .area:
                print("FloatingPanelViewModel: Hiding area selection (old type)")
                hideAreaSelection()
            case .window:
                hideWindowSelection()
            case .fullScreen:
                break
            }

            // Aktywuj nowy tryb SYNCHRONICZNIE
            switch newType {
            case .fullScreen:
                break  // Nic specjalnego nie trzeba robić
            case .area:
                print("FloatingPanelViewModel: Showing area selection (new type)")
                showAreaSelection()
            case .window:
                showWindowSelection()
            }
        }

        @MainActor
        private func showAreaSelection() {
            print("FloatingPanelViewModel: showAreaSelection() called - USING SWIFTUI OVERLAY")

            // Najpierw wyczyść poprzedni overlay jeśli istnieje
            hideAreaSelection()

            Task {
                do {
                    print("FloatingPanelViewModel: Starting background image capture")
                    let fullScreenImage = try await screenshotService.captureMainDisplay()
                    print(
                        "FloatingPanelViewModel: Background image captured successfully: \(fullScreenImage.size)"
                    )

                    await MainActor.run {
                        // Użyj SwiftUI overlay
                        print("FloatingPanelViewModel: Showing SwiftUI area selection overlay")
                        areaSelectionManager.show(backgroundImage: fullScreenImage) { rect in
                            print(
                                "FloatingPanelViewModel: SwiftUI overlay completed with rect: \(String(describing: rect))"
                            )
                            if let rect = rect {
                                // Użytkownik potwierdził selekcję - zrób zrzut od razu
                                self.selectedArea = rect
                                Task {
                                    await self.captureSelectedArea(rect: rect)
                                }
                            } else {
                                // Użytkownik anulował
                                self.hideAreaSelection()
                            }
                        }

                        isAreaSelectionActive = true
                        print("FloatingPanelViewModel: SwiftUI overlay shown successfully")
                    }
                } catch {
                    await MainActor.run {
                        print("Błąd podczas tworzenia overlay: \(error)")
                    }
                }
            }
        }

        @MainActor
        private func hideAreaSelection() {
            print("FloatingPanelViewModel: hideAreaSelection() called - HIDING SWIFTUI OVERLAY")

            // Ukryj SwiftUI overlay
            areaSelectionManager.hide(with: nil)

            // Ustaw flagi
            isAreaSelectionActive = false
            selectedArea = .zero

            // Wyczyść stary AppKit overlay jeśli istnieje
            areaSelectionOverlay = nil

            print("FloatingPanelViewModel: hideAreaSelection() completed")
        }

        @MainActor
        private func captureSelectedArea(rect: NSRect) async {
            print("FloatingPanelViewModel: captureSelectedArea called with rect: \(rect)")

            // Ukryj overlay
            hideAreaSelection()

            do {
                // Zrób zrzut wybranego obszaru
                let image = try await screenshotService.captureArea(rect: rect)
                print("FloatingPanelViewModel: Area captured successfully")

                // Otwórz edytor
                editorViewModel.show(image: image)
                print("FloatingPanelViewModel: Editor opened with area screenshot")
            } catch {
                print("FloatingPanelViewModel: ERROR during area capture: \(error)")
            }
        }

        private func showWindowSelection() {
            isWindowSelectionActive = true
            // TODO: Implementuj podświetlanie okien
            print("Tryb wyboru okna aktywny - kliknij w okno aby je wybrać")
        }

        private func hideWindowSelection() {
            isWindowSelectionActive = false
            selectedWindow = nil
        }

        @MainActor
        func captureScreenshot() async {
            guard captureMode == .image else {
                print("Nagrywanie video nie jest jeszcze zaimplementowane")
                return
            }

            isCapturing = true
            defer { isCapturing = false }

            do {
                let image: NSImage

                switch screenshotType {
                case .fullScreen:
                    image = try await screenshotService.captureMainDisplay()

                case .area:
                    print("FloatingPanelViewModel: Area mode - checking for active selection")

                    // Sprawdź czy overlay jest aktywne i ma selekcję
                    if isAreaSelectionActive {
                        let currentSelection = areaSelectionManager.getCurrentSelection()
                        print(
                            "FloatingPanelViewModel: Got selection from SwiftUI overlay: \(currentSelection)"
                        )

                        if !currentSelection.isEmpty && currentSelection.width > 10
                            && currentSelection.height > 10
                        {
                            // Mamy prawidłową selekcję - zrób zrzut
                            image = try await screenshotService.captureArea(rect: currentSelection)
                            hideAreaSelection()
                        } else {
                            print(
                                "FloatingPanelViewModel: No valid selection - please select an area first"
                            )
                            return
                        }
                    } else {
                        print("FloatingPanelViewModel: Area selection not active")
                        return
                    }

                case .window:
                    guard let window = selectedWindow else {
                        print("Nie wybrano okna")
                        return
                    }
                    image = try await screenshotService.captureWindow(window)
                    // Wyczyść wybór po zrobieniu zrzutu
                    hideWindowSelection()
                }

                // Open editor with image
                print("FloatingPanelViewModel: Opening editor with captured image")
                editorViewModel.show(image: image)
                print("FloatingPanelViewModel: Editor opened successfully")

            } catch {
                print("FloatingPanelViewModel: ERROR during screenshot capture: \(error)")
                print("FloatingPanelViewModel: Error type: \(type(of: error))")
                print("FloatingPanelViewModel: Error description: \(error.localizedDescription)")
            }
        }
    }

#endif
