//
//  GeneralSettingsView.swift
//  Klapok
//
//  General settings view
//

import SwiftUI

#if os(macOS)

struct GeneralSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var permissionsManager = PermissionsManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var iconManager = AppIconManager.shared
    @State private var iconChangeFailed = false

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
                        options: AppLanguage.allCases.map { language in
                            (language.rawValue, language == .system
                                ? LocalizationKeys.languageOptionSystem.localized
                                : language.displayName)
                        }
                    )
                }

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

                        SettingsOptionView(isLast: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Button("Refresh status".localized, systemImage: "arrow.clockwise") {
                                        permissionsManager.checkAllPermissions()
                                    }
                                    .accessibilityIdentifier("settings.permissions.refresh")
                                    if permissionsManager.isMonitoringPermissions {
                                        ProgressView().controlSize(.small)
                                        Text("Checking permissions automatically…".localized)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                if permissionsManager.hasOpenedPermissionSettings {
                                    Text("If macOS asks you to restart Klapok, reopen it to apply the change.".localized)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
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

                SettingsSection(
                    title: "Dock icon".localized,
                    subtitle: "Changes the icon while Klapok is running. Finder and the App Store keep the default icon.".localized,
                    systemImage: "app.dashed"
                ) {
                    SettingsOptionView(isLast: true) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(AppIconChoice.allCases) { choice in
                                Button {
                                    iconChangeFailed = !iconManager.select(choice)
                                } label: {
                                    VStack(spacing: 8) {
                                        if let image = choice.image() {
                                            Image(nsImage: image)
                                                .resizable().interpolation(.high)
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 88, height: 88)
                                        }
                                        Text(choice.title)
                                            .font(.callout)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity, minHeight: 34)
                                        Image(systemName: iconManager.selection == choice ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(iconManager.selection == choice ? Color.accentColor : .secondary)
                                    }
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(iconManager.selection == choice ? Color.accentColor.opacity(0.1) : .clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(choice.title)
                                .accessibilityAddTraits(iconManager.selection == choice ? .isSelected : [])
                                .accessibilityIdentifier("settings.icon.\(choice.rawValue)")
                            }
                        }
                    }
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
        .alert("Could not change the icon".localized, isPresented: $iconChangeFailed) {
            Button("OK", role: .cancel) { }
        }
        .background {
            SettingsWindowVisibilityObserver { visible in
                if visible { permissionsManager.settingsPanelAppeared() }
                else { permissionsManager.settingsPanelDisappeared() }
            }.frame(width: 0, height: 0)
        }
        .onDisappear { permissionsManager.settingsPanelDisappeared() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsManager.applicationBecameActive()
        }
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
                    Label("Granted".localized, systemImage: "checkmark.circle.fill")
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
