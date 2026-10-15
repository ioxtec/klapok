//
//  SettingsViewModel.swift
//  Klapok
//
//  ViewModel for application settings
//

import Foundation
import Combine

#if os(macOS)
    import AppKit

    @MainActor
    final class SettingsViewModel: ObservableObject {
        // MARK: - Dependencies

        private let appSettings = AppSettings.shared
        private var settingsSubscription: AnyCancellable?
        private var isSynchronizing = false

        // MARK: - Published Properties

        @Published var saveDirectory: URL {
            didSet {
                if !isSynchronizing { appSettings.saveDirectory = saveDirectory }
            }
        }

        @Published var fileNameTemplate: String {
            didSet {
                if !isSynchronizing { appSettings.fileNameTemplate = fileNameTemplate }
            }
        }

        @Published var screenshotReviewPosition: ScreenshotReviewPosition {
            didSet {
                if !isSynchronizing { appSettings.screenshotReviewPosition = screenshotReviewPosition }
            }
        }

        @Published var capturePixelMode: CapturePixelMode {
            didSet {
                if !isSynchronizing { appSettings.capturePixelMode = capturePixelMode }
            }
        }

        @Published var defaultCaptureType: CaptureType {
            didSet {
                if !isSynchronizing { appSettings.defaultCaptureType = defaultCaptureType }
            }
        }

        @Published var screenshotShowsMouseCursor: Bool {
            didSet {
                if !isSynchronizing { appSettings.screenshotShowsMouseCursor = screenshotShowsMouseCursor }
            }
        }

        @Published var showInDock: Bool {
            didSet {
                if !isSynchronizing { appSettings.showInDock = showInDock }
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
            settingsSubscription = appSettings.objectWillChange.receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.synchronizeFromSettings() }
        }

        private func synchronizeFromSettings() {
            isSynchronizing = true
            defer { isSynchronizing = false }
            if saveDirectory != appSettings.saveDirectory { saveDirectory = appSettings.saveDirectory }
            if fileNameTemplate != appSettings.fileNameTemplate { fileNameTemplate = appSettings.fileNameTemplate }
            if screenshotReviewPosition != appSettings.screenshotReviewPosition { screenshotReviewPosition = appSettings.screenshotReviewPosition }
            if capturePixelMode != appSettings.capturePixelMode { capturePixelMode = appSettings.capturePixelMode }
            if defaultCaptureType != appSettings.defaultCaptureType { defaultCaptureType = appSettings.defaultCaptureType }
            if screenshotShowsMouseCursor != appSettings.screenshotShowsMouseCursor { screenshotShowsMouseCursor = appSettings.screenshotShowsMouseCursor }
            if showInDock != appSettings.showInDock { showInDock = appSettings.showInDock }
        }

        // MARK: - Public Methods

        func selectSaveDirectory() {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.title = String(localized: "Choose a folder for screenshots")
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
