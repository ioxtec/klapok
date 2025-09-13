//
//  AdvancedSettingsView.swift
//  Fluttro
//
//  Advanced settings view
//

import SwiftUI

#if os(macOS)

    struct AdvancedSettingsView: View {
        @StateObject private var viewModel = SettingsViewModel()
        @State private var isRecordingHotkey = false

        var body: some View {
            Form {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Zaawansowane")
                        .font(.title2)
                        .padding(.bottom)

                    // Hotkey Section
                    GroupBox("Skrót klawiszowy") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Aktualny skrót:")
                                    .frame(width: 120, alignment: .leading)
                                Spacer()
                                Text(viewModel.hotkeyDisplayString)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(6)
                            }

                            HStack {
                                Button(isRecordingHotkey ? "Naciśnij nowy skrót..." : "Zmień skrót")
                                {
                                    if isRecordingHotkey {
                                        isRecordingHotkey = false
                                    } else {
                                        startHotkeyRecording()
                                    }
                                }
                                .disabled(isRecordingHotkey)

                                Spacer()
                            }

                            if isRecordingHotkey {
                                Text("Naciśnij kombinację klawiszy dla nowego skrótu")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Debug Section
                    GroupBox("Debug") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Wersja:")
                                    .frame(width: 80, alignment: .leading)
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Build:")
                                    .frame(width: 80, alignment: .leading)
                                Spacer()
                                Text("Debug")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Button("Wyczyść cache") {
                                    // TODO: Implement cache clearing
                                    Logger.i("Cache cleared")
                                }
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Spacer()
                }
            }
            .padding()
            .frame(minWidth: 450, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        }

        private func startHotkeyRecording() {
            isRecordingHotkey = true
            // TODO: Implement hotkey recording
            // This would involve capturing key events and updating the hotkey

            // For now, simulate recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isRecordingHotkey = false
            }
        }
    }

    #Preview {
        AdvancedSettingsView()
    }

#endif
