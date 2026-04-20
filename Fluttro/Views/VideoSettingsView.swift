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
    @StateObject private var settings = AppSettings.shared
    @StateObject private var profileManager = ProfileManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "Video profiles",
                    subtitle: "Profiles are selected and applied from the recorder. Settings keeps profile import/export compact.",
                    systemImage: "square.stack.3d.up"
                ) {
                    SettingsProfilesSummary(
                        profiles: profileManager.videoProfiles.profiles,
                        activeProfile: profileManager.videoProfiles.activeProfile,
                        resetAction: profileManager.resetVideoProfilesToDefaults,
                        exportAction: { _ = profileManager.exportVideoProfiles() },
                        importAction: { _ = profileManager.importVideoProfiles() }
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.videoQualityTitle.localized,
                    subtitle: "Recording quality used by new videos.",
                    systemImage: "slider.horizontal.3"
                ) {
                    SettingsPickerOption(
                        title: LocalizationKeys.resolutionTitle.localized,
                        description: "Source keeps the captured screen size. Presets downscale to a fixed output size.",
                        selection: $settings.videoResolution,
                        options: [
                            ("Source", "Source"),
                            ("1080p", "1080p"),
                            ("720p", "720p"),
                            ("480p", "480p")
                        ]
                    )

                    SettingsPickerOption(
                        title: "Source size",
                        description: "Used when Resolution is set to Source.",
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
                        title: "Expected recording size",
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
                    subtitle: "Audio options that are currently wired to recording.",
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
                    subtitle: "Recording behavior applied before capture starts.",
                    systemImage: "record.circle"
                ) {
                    SettingsToggleOption(
                        title: LocalizationKeys.showMouseCursorVideoTitle.localized,
                        description: LocalizationKeys.showMouseCursorVideoDescription.localized,
                        isLast: true,
                        isOn: $settings.showMouseCursor
                    )
                }

                SettingsSection(
                    title: LocalizationKeys.filesTitle.localized,
                    subtitle: "Video file destination and container format.",
                    systemImage: "folder"
                ) {
                    SettingsPathOption(
                        title: "Video folder",
                        path: settings.videoSaveDirectory.path,
                        description: "Where screen recordings are saved.",
                        action: selectVideoSaveDirectory
                    )

                    SettingsTextOption(
                        title: "Filename template",
                        description: "Preview: \(settings.formattedVideoFileName).\(settings.videoFormat.lowercased())",
                        infoText: "Use {datetime} for date and time or {date} for the date.",
                        text: $settings.videoFileNameTemplate,
                        placeholder: "Video-{datetime}"
                    )

                    SettingsPickerOption(
                        title: LocalizationKeys.formatTitle.localized,
                        description: "WebM is hidden because the writer currently exports MP4 or MOV only.",
                        selection: $settings.videoFormat,
                        options: [
                            ("MP4", "MP4"),
                            ("MOV", "QuickTime MOV")
                        ]
                    )

                    SettingsPickerOption(
                        title: "Codec",
                        description: "H.264 is safest. HEVC can create smaller files on newer Macs.",
                        isLast: true,
                        selection: $settings.videoCodec,
                        options: [
                            ("H.264", "H.264"),
                            ("H.265", "HEVC (H.265)")
                        ]
                    )
                }

            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: normalizeUnsupportedValues)
    }

    private func selectVideoSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select Video Save Directory"
        panel.message = "Choose a directory where video recordings will be saved."
        panel.directoryURL = settings.videoSaveDirectory

        if panel.runModal() == .OK, let url = panel.url {
            settings.videoSaveDirectory = url
        }
    }

    private func normalizeUnsupportedValues() {
        if settings.videoFormat == "WebM" {
            settings.videoFormat = "MP4"
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
                ? "Pixel-perfect physical display size."
                : "macOS scaled logical display size."
        }

        return "Fixed preset selected instead of source size."
    }
}

private extension CapturePixelMode {
    var videoDisplayName: String {
        switch self {
        case .realPixels:
            return "Real screen size"
        case .scaledScreenSize:
            return "Scaled screen size"
        }
    }
}

#Preview {
    VideoSettingsView()
}

#endif
