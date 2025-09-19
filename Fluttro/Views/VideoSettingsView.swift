//
//  VideoSettingsView.swift
//  Fluttro
//
//  Video capture settings view
//

import SwiftUI

#if os(macOS)
import AppKit

struct VideoSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Video Quality Section
                GroupBox(LocalizationKeys.videoQualityTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsPickerOption(
                            title: LocalizationKeys.resolutionTitle.localized,
                            description: LocalizationKeys.resolutionDescription.localized,
                            selection: $settings.videoResolution,
                            options: [("Source", "Źródło"), ("1080p", "1080p"), ("720p", "720p"), ("480p", "480p")]
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.fpsTitle.localized,
                            description: LocalizationKeys.fpsDescription.localized,
                            selection: $settings.videoFrameRateString,
                            options: [("60", "60 FPS"), ("30", "30 FPS"), ("24", "24 FPS")]
                        )
                        
                        SettingsPickerOption(
                            title: LocalizationKeys.bitrateTitle.localized,
                            description: LocalizationKeys.bitrateDescription.localized,
                            isLast: true,
                            selection: $settings.videoBitrateString,
                            options: [("5 Mbps", "5 Mbps"), ("10 Mbps", "10 Mbps"), ("2 Mbps", "2 Mbps"), ("1 Mbps", "1 Mbps")]
                        )
                    }
                }
                
                // Audio Settings Section
                GroupBox(LocalizationKeys.audioTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: LocalizationKeys.recordSystemAudioTitle.localized,
                            description: LocalizationKeys.recordSystemAudioDescription.localized,
                            isOn: $settings.recordSystemAudio
                        )
                        
                        SettingsToggleOption(
                            title: LocalizationKeys.recordMicrophoneTitle.localized,
                            description: LocalizationKeys.recordMicrophoneDescription.localized,
                            isOn: $settings.recordMicrophone
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
                            isOn: $settings.showMouseCursor
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
                        // Video Save Directory
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Video Save Location")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Text(settings.videoSaveDirectory.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button("Choose...") {
                                        selectVideoSaveDirectory()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        
                        // Video File Name Template
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("File Name Template")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                TextField("Video-{datetime}", text: $settings.videoFileNameTemplate)
                                    .textFieldStyle(.roundedBorder)
                                
                                Text("Available placeholders: {datetime}, {date}")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(LocalizationKeys.formatTitle.localized)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Picker("Format", selection: $settings.videoFormat) {
                                        Text("MP4").tag("MP4")
                                        Text("MOV").tag("MOV")
                                        Text("WebM").tag("WebM")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Picker("Codec", selection: $settings.videoCodec) {
                                        Text("H.264").tag("H.264")
                                        Text("H.265 (HEVC)").tag("H.265")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
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
                            isLast: false,
                            isOn: .constant(false)
                        )
                        
                        // Reset to Defaults Button
                        SettingsOptionView(isLast: true) {
                            HStack {
                                Button("Reset to Defaults") {
                                    settings.resetToDefaults()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Spacer()
                                
                                Text("Restore all video settings to safe defaults")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Permissions Section
                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Screen Recording Permission")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button("Grant Permission") {
                                        requestScreenRecordingPermission()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Required for video recording functionality")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Microphone Permission")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button("Grant Permission") {
                                        requestMicrophonePermission()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Required for microphone recording")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        SettingsOptionView(isLast: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("File Access Permission")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button("Choose Folder") {
                                        selectVideoSaveDirectory()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Text("Required for saving videos to custom locations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24) // Add bottom spacing
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
    
    private func selectVideoSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Video Save Directory"
        panel.message = "Choose a directory where video recordings will be saved."
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                settings.videoSaveDirectory = url
            }
        }
    }
    
    private func requestScreenRecordingPermission() {
        // This will trigger the system permission dialog
        // The actual permission request happens when we try to use ScreenCaptureKit
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission"
        alert.informativeText = "To record your screen, Fluttro needs screen recording permission. This permission will be requested when you first try to record a video."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func requestMicrophonePermission() {
        // This will trigger the system permission dialog
        let alert = NSAlert()
        alert.messageText = "Microphone Permission"
        alert.informativeText = "To record microphone audio, Fluttro needs microphone permission. This permission will be requested when you first try to record with microphone enabled."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }
}

#Preview {
    VideoSettingsView()
}

#endif
