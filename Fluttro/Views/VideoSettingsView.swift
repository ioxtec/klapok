//
//  VideoSettingsView.swift
//  Fluttro
//
//  Video capture settings view
//

import SwiftUI

#if os(macOS)

struct VideoSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Video Quality Section
                GroupBox(LocalizationKeys.videoQualityTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsPickerOption(
                            title: LocalizationKeys.resolutionTitle.localized,
                            description: LocalizationKeys.resolutionDescription.localized,
                            selection: .constant("Source"),
                            options: [("Source", "Źródło"), ("1080p", "1080p"), ("720p", "720p"), ("480p", "480p")]
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.fpsTitle.localized,
                            description: LocalizationKeys.fpsDescription.localized,
                            selection: .constant("30"),
                            options: [("60", "60 FPS"), ("30", "30 FPS"), ("24", "24 FPS")]
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.bitrateTitle.localized,
                            description: LocalizationKeys.bitrateDescription.localized,
                            isLast: true,
                            selection: .constant("Auto"),
                            options: [("Auto", "Auto"), ("High", "Wysoki"), ("Medium", "Średni"), ("Low", "Niski")]
                        )
                    }
                }
                
                // Audio Settings Section
                GroupBox(LocalizationKeys.audioTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: LocalizationKeys.recordSystemAudioTitle.localized,
                            description: LocalizationKeys.recordSystemAudioDescription.localized,
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.recordMicrophoneTitle.localized,
                            description: LocalizationKeys.recordMicrophoneDescription.localized,
                            isOn: .constant(false)
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.audioQualityTitle.localized,
                            description: LocalizationKeys.audioQualityDescription.localized,
                            isLast: true,
                            selection: .constant("High"),
                            options: [("High", "Wysoka"), ("Medium", "Średnia"), ("Low", "Niska")]
                        )
                    }
                }
                
                // Recording Behavior Section
                GroupBox(LocalizationKeys.recordingBehaviorTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: LocalizationKeys.showRecordingTimerTitle.localized,
                            description: LocalizationKeys.showRecordingTimerDescription.localized,
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.showMouseCursorVideoTitle.localized,
                            description: LocalizationKeys.showMouseCursorVideoDescription.localized,
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.autoStopAfterTimeTitle.localized,
                            description: LocalizationKeys.autoStopAfterTimeDescription.localized,
                            isOn: .constant(false)
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.maxTimeTitle.localized,
                            description: LocalizationKeys.maxTimeDescription.localized,
                            isLast: true,
                            selection: .constant("10min"),
                            options: [("5min", "5 min"), ("10min", "10 min"), ("30min", "30 min"), ("unlimited", "Bez limitu")]
                        )
                    }
                }
                
                // File Settings Section
                GroupBox(LocalizationKeys.filesTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(LocalizationKeys.formatTitle.localized)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Picker("Format", selection: .constant("MP4")) {
                                    Text("MP4").tag("MP4")
                                    Text("MOV").tag("MOV")
                                    Text("WebM").tag("WebM")
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.compressAfterRecordingTitle.localized,
                            description: LocalizationKeys.compressAfterRecordingDescription.localized,
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.deleteAfterRecordingTitle.localized,
                            description: LocalizationKeys.deleteAfterRecordingDescription.localized,
                            isLast: true,
                            isOn: .constant(false)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24) // Add bottom spacing
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
}

#Preview {
    VideoSettingsView()
}

#endif
