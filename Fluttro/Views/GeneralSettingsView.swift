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

        var body: some View {
            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Permissions Section - Only show if permissions are missing
                    if !permissionsManager.hasScreenCapturePermission || 
                       !permissionsManager.hasFileAccessPermission || 
                       !permissionsManager.hasAccessibilityPermission {
                        
                        GroupBox("Uprawnienia") {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Aplikacja wymaga następujących uprawnień:")
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
                                            Text("Nagrywanie ekranu")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text("Potrzebne do robienia zrzutów ekranu i nagrywania")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if permissionsManager.hasScreenCapturePermission {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title2)
                                        } else {
                                            Button("Otwórz ustawienia") {
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
                                            Text("Dostęp do plików")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text("Potrzebny do zapisywania zrzutów ekranu")
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
                                            Text("Dostępność")
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text("Potrzebny do globalnych skrótów klawiszowych")
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
                    GroupBox("Folder zapisywania") {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsPathOption(
                                title: "Folder zapisywania",
                                path: viewModel.saveDirectory.path,
                                description: "Folder gdzie zapisywane są zrzuty ekranu",
                                infoText: "Możesz wybrać dowolny folder na swoim dysku. Aplikacja automatycznie utworzy folder 'Fluttro Screenshots' jeśli nie istnieje.",
                                isLast: true,
                                action: {
                                    viewModel.selectSaveDirectory()
                                }
                            )
                        }
                    }

                    // File Name Template Section
                    GroupBox("Nazwa pliku") {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsTextOption(
                                title: "Szablon nazwy",
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
                    GroupBox("Zachowanie aplikacji") {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsToggleOption(
                                title: "Pokaż ikonę w Docku",
                                description: "Wyświetl ikonę aplikacji w Docku",
                                isOn: $viewModel.showInDock
                            )
                            
                            SettingsToggleOption(
                                title: "Uruchom przy logowaniu",
                                description: "Automatycznie uruchom aplikację po zalogowaniu",
                                isOn: $viewModel.launchAtLogin
                            )
                            
                            SettingsToggleOption(
                                title: "Pokaż kursor myszy w zrzutach",
                                description: "Dołącz kursor myszy do zrzutów ekranu",
                                isLast: true,
                                isOn: $viewModel.showMouseCursor
                            )
                        }
                    }

                    // Reset Button
                    HStack {
                        Spacer()
                        Button("Przywróć domyślne") {
                            viewModel.resetToDefaults()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .frame(minWidth: 600, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        }
    }

    #Preview {
        GeneralSettingsView()
    }

#endif
