//
//  VideoSettingsView.swift
//  Klapok
//
//  Video capture settings view
//

import SwiftUI

#if os(macOS)
import AppKit

struct VideoSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "Recording profiles".localized,
                    subtitle: "Profiles are selected before capture and store the recording options below.".localized,
                    systemImage: "square.stack.3d.up"
                ) {
                    SettingsProfilesSummary(
                        profiles: profileManager.videoProfiles.profiles,
                        activeProfile: profileManager.videoProfiles.activeProfile,
                        isModified: profileManager.getActiveVideoProfile().map { !$0.matchesAppSettings(settings) } ?? true,
                        resetAction: { profileManager.resetVideoProfilesToDefaults() },
                        exportAction: { _ = profileManager.exportVideoProfiles() },
                        importAction: { _ = profileManager.importVideoProfiles() }
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.videoQualityTitle.localized,
                    subtitle: "These options apply to new recordings before you open the video editor.".localized,
                    systemImage: "slider.horizontal.3"
                ) {
                    SettingsPickerOption(
                        title: LocalizationKeys.resolutionTitle.localized,
                        description: "Source keeps the captured screen size. Presets downscale to a fixed output size.".localized,
                        selection: $settings.videoResolution,
                        options: [
                            ("Source", "Source".localized),
                            ("1080p", "1080p"),
                            ("720p", "720p"),
                            ("480p", "480p")
                        ]
                    )

                    SettingsPickerOption(
                        title: "Source size".localized,
                        description: "Used when Resolution is set to Source.".localized,
                        selection: Binding(
                            get: { settings.capturePixelMode.rawValue },
                            set: {
                                if let mode = CapturePixelMode(rawValue: $0) {
                                    settings.capturePixelMode = mode
                                }
                            }
                        ),
                        options: CapturePixelMode.allCases.map {
                            ($0.rawValue, $0.videoDisplayName)
                        }
                    )

                    SettingsValueOption(
                        title: "Expected recording size".localized,
                        description: expectedRecordingDescription,
                        value: "\(Int(expectedRecordingSize.width)) x \(Int(expectedRecordingSize.height)) px"
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.fpsTitle.localized,
                        description: LocalizationKeys.fpsDescription.localized,
                        selection: $settings.videoFrameRateString,
                        options: [
                            ("60", "60 FPS"),
                            ("30", "30 FPS"),
                            ("25", "25 FPS"),
                            ("24", "24 FPS")
                        ]
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.bitrateTitle.localized,
                        description: LocalizationKeys.bitrateDescription.localized,
                        isLast: true,
                        selection: $settings.videoBitrateString,
                        options: [
                            ("10 Mbps", "10 Mbps"),
                            ("5 Mbps", "5 Mbps"),
                            ("2 Mbps", "2 Mbps"),
                            ("1 Mbps", "1 Mbps")
                        ]
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.audioTitle.localized,
                    subtitle: "Audio capture options used while recording.".localized,
                    systemImage: "speaker.wave.2"
                ) {
                    SettingsToggleOption(
                        title: LocalizationKeys.recordSystemAudioTitle.localized,
                        description: LocalizationKeys.recordSystemAudioDescription.localized,
                        isLast: true,
                        isOn: $settings.recordSystemAudio
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.recordingBehaviorTitle.localized,
                    subtitle: "Recording behavior applied before capture starts.".localized,
                    systemImage: "record.circle"
                ) {
                    SettingsToggleOption(
                        title: "Enable countdown before screen recording".localized,
                        description: "Adds a short delay before a new video recording starts.".localized,
                        isOn: $settings.enableRecordingCountdown
                    )

                    if settings.enableRecordingCountdown {
                        SettingsPickerOption(
                            title: "Countdown duration".localized,
                            description: "Choose how many seconds to wait before recording begins.".localized,
                            selection: Binding(
                                get: { String(settings.recordingCountdownSeconds) },
                                set: { newValue in
                                    settings.recordingCountdownSeconds = Int(newValue) ?? 3
                                }
                            ),
                            options: (1...30).map { value in
                                let label = "\(value) s"
                                return (String(value), label)
                            }
                        )
                    }

                    SettingsToggleOption(
                        title: LocalizationKeys.showMouseCursorVideoTitle.localized,
                        description: LocalizationKeys.showMouseCursorVideoDescription.localized,
                        isLast: true,
                        isOn: $settings.showMouseCursor
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.filesTitle.localized,
                    subtitle: "Where new recordings are saved before review or export.".localized,
                    systemImage: "folder"
                ) {
                    SettingsPathOption(
                        title: "Video folder".localized,
                        path: settings.videoSaveDirectory.path,
                        description: "Where screen recordings are saved.".localized,
                        action: selectVideoSaveDirectory
                    )

                    SettingsTextOption(
                        title: LocalizationKeys.filenameTemplateOptionTitle.localized,
                        description: "Preview: %@".localized(with: "\(settings.formattedVideoFileName).\(settings.videoFormat.lowercased())"),
                        infoText: "Use {datetime} for date and time or {date} for the date.".localized,
                        text: $settings.videoFileNameTemplate,
                        placeholder: "Video-{datetime}"
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.formatTitle.localized,
                        description: "WebM is hidden because the writer currently exports MP4 or MOV only.".localized,
                        selection: $settings.videoFormat,
                        options: [
                            ("MP4", "MP4"),
                            ("MOV", "QuickTime MOV")
                        ]
                    )

                    SettingsPickerOption(
                        title: "Codec".localized,
                        description: "H.264 is safest. HEVC can create smaller files on newer Macs.".localized,
                        isLast: true,
                        selection: $settings.videoCodec,
                        options: [
                            ("H.264", "H.264"),
                            ("H.265", "HEVC (H.265)")
                        ]
                    )
                }

                SettingsSection(
                    title: "Editor export".localized,
                    subtitle: "What happens after a recording is already captured.".localized,
                    systemImage: "square.and.arrow.up"
                ) {
                    SettingsInfoOption(
                        title: "Trimmed video export".localized,
                        description: "Trimmed video export uses the shared format, codec, and quality above. Scaling and export audio stay in the video editor sidebar. GIF export keeps its own controls there as well.".localized,
                        isLast: true
                    )
                }

            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("settings.content.video")
        .id(languageManager.selectedLanguage.rawValue)
    }

    private func selectVideoSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Video Save Directory".localized
        panel.message = "Choose a directory where video recordings will be saved.".localized
        panel.directoryURL = settings.videoSaveDirectory
        WindowPlacement.centerModalPanel(panel)

        if panel.runModal() == .OK, let url = panel.url {
            settings.videoSaveDirectory = url
        }
    }

    private var expectedRecordingSize: CGSize {
        switch settings.videoResolution {
        case "Source":
            return ScreenPixelGeometry.captureSize(
                for: NSScreen.main,
                mode: settings.capturePixelMode
            )
        case "1080p":
            return CGSize(width: 1920, height: 1080)
        case "720p":
            return CGSize(width: 1280, height: 720)
        case "480p":
            return CGSize(width: 854, height: 480)
        default:
            return CGSize(width: 1920, height: 1080)
        }
    }

    private var expectedRecordingDescription: String {
        if settings.videoResolution == "Source" {
            return settings.capturePixelMode == .realPixels
                ? "Pixel-perfect physical display size.".localized
                : "macOS scaled logical display size.".localized
        }

        return "Fixed preset selected instead of source size.".localized
    }
}

private extension CapturePixelMode {
    var videoDisplayName: String {
        switch self {
        case .realPixels:
            return "Real screen size".localized
        case .scaledScreenSize:
            return "Scaled screen size".localized
        }
    }
}

#endif
