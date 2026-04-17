//
//  SettingsViewModel.swift
//  Fluttro
//
//  ViewModel for application settings
//

import Foundation

#if os(macOS)
    import AppKit

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

        @Published var hotkeyModifiers: NSEvent.ModifierFlags {
            didSet {
                appSettings.hotkeyModifiers = hotkeyModifiers
            }
        }

        @Published var hotkeyKeyCode: UInt16 {
            didSet {
                appSettings.hotkeyKeyCode = hotkeyKeyCode
            }
        }

        @Published var showInDock: Bool {
            didSet {
                appSettings.showInDock = showInDock
            }
        }

        @Published var launchAtLogin: Bool {
            didSet {
                appSettings.launchAtLogin = launchAtLogin
            }
        }

        // Legacy settings
        @Published var showMouseCursor: Bool = false

        // MARK: - Computed Properties

        var hotkeyDisplayString: String {
            return appSettings.hotkeyDisplayString
        }

        var previewFileName: String {
            return appSettings.formattedFileName + ".png"
        }

        // MARK: - Initialization

        init() {
            // Initialize with current settings
            self.saveDirectory = appSettings.saveDirectory
            self.fileNameTemplate = appSettings.fileNameTemplate
            self.screenshotReviewPosition = appSettings.screenshotReviewPosition
            self.hotkeyModifiers = appSettings.hotkeyModifiers
            self.hotkeyKeyCode = appSettings.hotkeyKeyCode
            self.showInDock = appSettings.showInDock
            self.launchAtLogin = appSettings.launchAtLogin
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
            hotkeyModifiers = appSettings.hotkeyModifiers
            hotkeyKeyCode = appSettings.hotkeyKeyCode
            showInDock = appSettings.showInDock
            launchAtLogin = appSettings.launchAtLogin
        }

        func openSaveDirectory() {
            NSWorkspace.shared.open(saveDirectory)
        }
    }

#endif
