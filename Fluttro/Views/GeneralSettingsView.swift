//
//  GeneralSettingsView.swift
//  Fluttro
//
//  General settings view
//

import SwiftUI

#if os(macOS)

struct GeneralSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: LocalizationKeys.languageTitle.localized,
                    subtitle: LocalizationKeys.languageDescription.localized,
                    systemImage: "globe"
                ) {
                    SettingsPickerOption(
                        title: LocalizationKeys.languageTitle.localized,
                        description: LocalizationKeys.languageDescription.localized,
                        isLast: true,
                        selection: Binding(
                            get: { languageManager.selectedLanguage.rawValue },
                            set: {
                                if let newLanguage = AppLanguage(rawValue: $0) {
                                    languageManager.selectedLanguage = newLanguage
                                }
                            }
                        ),
                        options: [
                            (AppLanguage.system.rawValue, LocalizationKeys.languageOptionSystem.localized),
                            (AppLanguage.english.rawValue, LocalizationKeys.languageOptionEnglish.localized),
                            (AppLanguage.polish.rawValue, LocalizationKeys.languageOptionPolish.localized)
                        ]
                    )
                }

                if shouldShowPermissions {
                    SettingsSection(
                        title: LocalizationKeys.permissionsTitle.localized,
                        subtitle: LocalizationKeys.permissionsDescription.localized,
                        systemImage: "hand.raised"
                    ) {
                        PermissionOption(
                            title: LocalizationKeys.permissionScreenRecordingTitle.localized,
                            description: LocalizationKeys.permissionScreenRecordingDescription.localized,
                            isGranted: permissionsManager.hasScreenCapturePermission,
                            action: permissionsManager.openScreenRecordingSettings
                        )

                        PermissionOption(
                            title: LocalizationKeys.permissionFileAccessTitle.localized,
                            description: LocalizationKeys.permissionFileAccessDescription.localized,
                            isGranted: permissionsManager.hasFileAccessPermission,
                            action: permissionsManager.openSystemPreferences
                        )

                        PermissionOption(
                            title: LocalizationKeys.permissionAccessibilityTitle.localized,
                            description: LocalizationKeys.permissionAccessibilityDescription.localized,
                            isGranted: permissionsManager.hasAccessibilityPermission,
                            isLast: true,
                            action: permissionsManager.openAccessibilitySettings
                        )
                    }
                }

                SettingsSection(
                    title: LocalizationKeys.appBehaviorTitle.localized,
                    subtitle: LocalizationKeys.appBehaviorDescription.localized,
                    systemImage: "macwindow"
                ) {
                    SettingsToggleOption(
                        title: LocalizationKeys.showInDockTitle.localized,
                        description: LocalizationKeys.showInDockDescription.localized,
                        isOn: $viewModel.showInDock
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.capturePixelModeTitle.localized,
                        description: LocalizationKeys.capturePixelModeDescription.localized,
                        selection: Binding(
                            get: { viewModel.capturePixelMode.rawValue },
                            set: {
                                if let mode = CapturePixelMode(rawValue: $0) {
                                    viewModel.capturePixelMode = mode
                                }
                            }
                        ),
                        options: CapturePixelMode.allCases.map {
                            ($0.rawValue, $0.displayName)
                        }
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.reviewPositionTitle.localized,
                        description: LocalizationKeys.reviewPositionDescription.localized,
                        selection: Binding(
                            get: { viewModel.screenshotReviewPosition.rawValue },
                            set: {
                                if let position = ScreenshotReviewPosition(rawValue: $0) {
                                    viewModel.screenshotReviewPosition = position
                                }
                            }
                        ),
                        options: ScreenshotReviewPosition.allCases.map {
                            ($0.rawValue, $0.displayName)
                        }
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.defaultCaptureTargetTitle.localized,
                        description: LocalizationKeys.defaultCaptureTargetDescription.localized,
                        isLast: true,
                        selection: Binding(
                            get: { viewModel.defaultCaptureType.rawValue },
                            set: {
                                if let type = CaptureType(rawValue: $0) {
                                    viewModel.defaultCaptureType = type
                                }
                            }
                        ),
                        options: CaptureType.allCases.map {
                            ($0.rawValue, $0.title)
                        }
                    )
                }

                HStack {
                    Spacer()

                    Button(LocalizationKeys.resetDefaultsButton.localized) {
                        viewModel.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("settings.content.general")
    }

    private var shouldShowPermissions: Bool {
        !permissionsManager.hasScreenCapturePermission ||
            !permissionsManager.hasFileAccessPermission ||
            !permissionsManager.hasAccessibilityPermission
    }
}

private struct PermissionOption: View {
    let title: String
    let description: String
    let isGranted: Bool
    var isLast: Bool = false
    let action: () -> Void

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 24)

                if isGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                        .font(.title3)
                } else {
                    Button(LocalizationKeys.openSettingsButton.localized) {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

#endif
