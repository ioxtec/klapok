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
            VStack(alignment: .leading, spacing: 24) {
                // Language Selection Section
                GroupBox(LocalizationKeys.languageTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
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
                                (AppLanguage.polish.rawValue, LocalizationKeys.languageOptionPolish.localized),
                                (AppLanguage.german.rawValue, LocalizationKeys.languageOptionGerman.localized)
                            ]
                        )
                    }
                }
                
                // Permissions Section - Only show if permissions are missing
                    if !permissionsManager.hasScreenCapturePermission || 
                       !permissionsManager.hasFileAccessPermission || 
                       !permissionsManager.hasAccessibilityPermission {
                        
                        GroupBox(LocalizationKeys.permissionsTitle.localized) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(LocalizationKeys.permissionsDescription.localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                    .padding(.bottom, 12)
                                
                                Divider()
                                    .background(Color.gray.opacity(0.08))
                                    .padding(.leading, 16)
                                
                                // Screen Recording Permission
                                SettingsOptionView {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationKeys.permissionScreenRecordingTitle.localized)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(LocalizationKeys.permissionScreenRecordingDescription.localized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if permissionsManager.hasScreenCapturePermission {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        } else {
                                            Button(LocalizationKeys.openSettingsButton.localized) {
                                                permissionsManager.openScreenRecordingSettings()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                }
                                
                                // File Access Permission
                                SettingsOptionView {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationKeys.permissionFileAccessTitle.localized)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(LocalizationKeys.permissionFileAccessDescription.localized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if permissionsManager.hasFileAccessPermission {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        } else {
                                            Button("Otwórz ustawienia") {
                                                permissionsManager.openSystemPreferences()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                }
                                
                                // Accessibility Permission
                                SettingsOptionView(isLast: true) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(LocalizationKeys.permissionAccessibilityTitle.localized)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(LocalizationKeys.permissionAccessibilityDescription.localized)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if permissionsManager.hasAccessibilityPermission {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        } else {
                                            Button("Otwórz ustawienia") {
                                                permissionsManager.openAccessibilitySettings()
                                            }
                                            .buttonStyle(.borderedProminent)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Save Directory Section
                    GroupBox(LocalizationKeys.saveDirectoryTitle.localized) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsPathOption(
                                title: LocalizationKeys.saveDirectoryOptionTitle.localized,
                                path: viewModel.saveDirectory.path,
                                description: LocalizationKeys.saveDirectoryDescription.localized,
                                infoText: "Możesz wybrać dowolny folder na swoim dysku. Aplikacja automatycznie utworzy folder 'Fluttro Screenshots' jeśli nie istnieje.",
                                isLast: true,
                                action: {
                                    viewModel.selectSaveDirectory()
                                }
                            )
                        }
                    }

                    // File Name Template Section
                    GroupBox(LocalizationKeys.filenameTemplateTitle.localized) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsTextOption(
                                title: LocalizationKeys.filenameTemplateOptionTitle.localized,
                                description: "Podgląd: \(viewModel.previewFileName)",
                                infoText: "Użyj zmiennych {datetime} dla pełnej daty i czasu, {date} dla samej daty. Nazwy plików są automatycznie generowane na podstawie tego szablonu.",
                                text: $viewModel.fileNameTemplate,
                                placeholder: "Screenshot-{datetime}"
                            )
                            
                            SettingsInfoOption(
                                title: "Dostępne zmienne",
                                description: "{datetime} - pełna data i czas, {date} - sama data",
                                infoText: "Zmienne są automatycznie zastępowane rzeczywistymi wartościami podczas zapisywania zrzutów.",
                                isLast: true
                            )
                        }
                    }

                    // App Behavior Section
                    GroupBox(LocalizationKeys.appBehaviorTitle.localized) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsToggleOption(
                                title: LocalizationKeys.showInDockTitle.localized,
                                description: LocalizationKeys.showInDockDescription.localized,
                                isOn: $viewModel.showInDock
                            )
                            
                            SettingsToggleOption(
                                title: LocalizationKeys.launchAtLoginTitle.localized,
                                description: LocalizationKeys.launchAtLoginDescription.localized,
                                isOn: $viewModel.launchAtLogin
                            )
                            
                            SettingsToggleOption(
                                title: LocalizationKeys.showMouseCursorTitle.localized,
                                description: LocalizationKeys.showMouseCursorDescription.localized,
                                isLast: true,
                                isOn: $viewModel.showMouseCursor
                            )
                        }
                    }

                    // Reset Button
                    HStack {
                        Spacer()
                        Button(LocalizationKeys.resetDefaultsButton.localized) {
                            viewModel.resetToDefaults()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24) // Add bottom spacing
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        }
    }

    #Preview {
        GeneralSettingsView()
    }

#endif
