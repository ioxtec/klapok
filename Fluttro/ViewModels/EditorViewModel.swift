//
//  EditorViewModel.swift
//  Fluttro
//

import Combine
import Foundation

#if os(macOS)
    import AppKit

    final class EditorViewModel: ObservableObject {
        @Published var image: NSImage?
        @Published var isPresented: Bool = false
        @Published var isCapturing: Bool = false

        private let screenshotService = ScreenshotService()

        @MainActor
        func show(image: NSImage) {
            print("EditorViewModel.show() wywołane z obrazem: \(image.size)")
            self.image = image
            self.isPresented = true
        }

        @MainActor
        func close() {
            print("EditorViewModel.close() wywołane")
            self.isPresented = false
            self.image = nil  // Wyczyść obraz aby zwolnić pamięć
        }

        // MARK: - Screenshot Methods

        @MainActor
        func captureFullScreen() async {
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await screenshotService.captureMainDisplay()
                show(image: image)
            } catch {
                print("Błąd podczas robienia zrzutu całego ekranu: \(error)")
            }
        }

        @MainActor
        func captureSelectedArea() async {
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await screenshotService.captureSelectedArea()
                show(image: image)
            } catch ScreenshotError.userCancelled {
                // User cancelled, do nothing
            } catch {
                print("Błąd podczas robienia zrzutu wybranego obszaru: \(error)")
            }
        }

        @MainActor
        func captureSelectedWindow() async {
            isCapturing = true
            defer { isCapturing = false }

            do {
                let image = try await screenshotService.captureSelectedWindow()
                show(image: image)
            } catch ScreenshotError.userCancelled {
                // User cancelled, do nothing
            } catch ScreenshotError.noWindowSelected {
                print("Brak dostępnych okien do zrzutu")
            } catch {
                print("Błąd podczas robienia zrzutu okna: \(error)")
            }
        }
    }

#endif
