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

        var body: some View {
            Form {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ogólne")
                        .font(.title2)
                        .padding(.bottom)

                    // Save Directory Section
                    GroupBox("Folder zapisywania") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Folder:")
                                    .frame(width: 80, alignment: .leading)
                                Text(viewModel.saveDirectory.lastPathComponent)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }

                            Text(viewModel.saveDirectory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)

                            HStack {
                                Button("Wybierz folder...") {
                                    viewModel.selectSaveDirectory()
                                }

                                Spacer()

                                Button("Otwórz") {
                                    viewModel.openSaveDirectory()
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // File Name Template Section
                    GroupBox("Nazwa pliku") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Szablon:")
                                    .frame(width: 80, alignment: .leading)
                                TextField("Szablon nazwy", text: $viewModel.fileNameTemplate)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Podgląd: \(viewModel.previewFileName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Dostępne zmienne: {datetime}, {date}")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // App Behavior Section
                    GroupBox("Zachowanie aplikacji") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Pokaż ikonę w Docku", isOn: $viewModel.showInDock)
                            Toggle("Uruchom przy logowaniu", isOn: $viewModel.launchAtLogin)
                            Toggle(
                                "Pokaż kursor myszy w zrzutach", isOn: $viewModel.showMouseCursor)
                        }
                        .padding(.vertical, 8)
                    }

                    Spacer()

                    // Reset Button
                    HStack {
                        Spacer()
                        Button("Przywróć domyślne") {
                            viewModel.resetToDefaults()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .frame(minWidth: 450, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
        }
    }

    #Preview {
        GeneralSettingsView()
    }

#endif
