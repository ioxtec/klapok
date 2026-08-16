//
//  SettingsViewModel.swift
//  Fluttro
//
//  ViewModel for application settings
//

import Foundation

#if os(macOS)
    import AppKit

    @MainActor
    final class SettingsViewModel: ObservableObject {
        // MARK: - Dependencies

        private let appSettings = AppSettings.shared

        // MARK: - Published Properties

        @Published var saveDirectory: URL {
            didSet {
                appSettings.saveDirectory = saveDirectory
            }
        }

        @Published var fileNameTemplate: String {
            didSet {
                appSettings.fileNameTemplate = fileNameTemplate
            }
        }

        @Published var screenshotReviewPosition: ScreenshotReviewPosition {
            didSet {
                appSettings.screenshotReviewPosition = screenshotReviewPosition
            }
        }

        @Published var capturePixelMode: CapturePixelMode {
            didSet {
                appSettings.capturePixelMode = capturePixelMode
            }
        }

        @Published var defaultCaptureType: CaptureType {
            didSet {
                appSettings.defaultCaptureType = defaultCaptureType
            }
        }

        @Published var screenshotShowsMouseCursor: Bool {
            didSet {
                appSettings.screenshotShowsMouseCursor = screenshotShowsMouseCursor
            }
        }

        @Published var showInDock: Bool {
            didSet {
                appSettings.showInDock = showInDock
            }
        }

        // MARK: - Computed Properties

        var previewFileName: String {
            return appSettings.formattedFileName + ".png"
        }

        // MARK: - Initialization

        init() {
            // Initialize with current settings
            self.saveDirectory = appSettings.saveDirectory
            self.fileNameTemplate = appSettings.fileNameTemplate
            self.screenshotReviewPosition = appSettings.screenshotReviewPosition
            self.capturePixelMode = appSettings.capturePixelMode
            self.defaultCaptureType = appSettings.defaultCaptureType
            self.screenshotShowsMouseCursor = appSettings.screenshotShowsMouseCursor
            self.showInDock = appSettings.showInDock
        }

        // MARK: - Public Methods

        func selectSaveDirectory() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.title = "Wybierz folder do zapisywania zrzutów"
            panel.directoryURL = saveDirectory
            WindowPlacement.centerModalPanel(panel)

            if panel.runModal() == .OK, let url = panel.url {
                saveDirectory = url
            }
        }

        func resetToDefaults() {
            appSettings.resetToDefaults()

            // Update local properties
            saveDirectory = appSettings.saveDirectory
            fileNameTemplate = appSettings.fileNameTemplate
            screenshotReviewPosition = appSettings.screenshotReviewPosition
            capturePixelMode = appSettings.capturePixelMode
            defaultCaptureType = appSettings.defaultCaptureType
            screenshotShowsMouseCursor = appSettings.screenshotShowsMouseCursor
            showInDock = appSettings.showInDock
        }

        func openSaveDirectory() {
            NSWorkspace.shared.open(saveDirectory)
        }
    }

#endif
