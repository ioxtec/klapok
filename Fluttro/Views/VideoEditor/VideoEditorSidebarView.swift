//
//  VideoEditorSidebarView.swift
//  Fluttro
//

import SwiftUI

#if os(macOS)

struct VideoEditorSidebarView: View {
    let video: VideoRecording?
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var exportManager: ExportManager
    let formatDuration: (TimeInterval) -> String
    let formatFileSize: (URL) -> String
    let formatDate: (URL) -> String

    var body: some View {
        sidebarContent
    }

    private var sidebarContent: some View {
        SidebarScrollContainer(leadingInset: 2, trailingInset: 4) {
            SidebarDisclosureSection(
                id: "video.profiles",
                title: "Profiles",
                systemImage: "slider.horizontal.3",
                subtitle: "Presets for export format, quality, size, and audio."
            ) {
                profileControl
            }

            SidebarDisclosureSection(
                id: "video.source",
                title: "Video",
                systemImage: "film",
                subtitle: "Source file, duration, and capture details."
            ) {
                if let video {
                    VStack(alignment: .leading, spacing: 9) {
                        SidebarValueRow(title: "File", value: video.url.lastPathComponent, systemImage: "doc")
                        SidebarDivider()
                        SidebarValueRow(title: "Duration", value: formatDuration(video.duration), systemImage: "clock")
                        SidebarDivider()
                        SidebarValueRow(title: "Size", value: formatFileSize(video.url), systemImage: "internaldrive")
                        SidebarDivider()
                        SidebarValueRow(title: "Created", value: formatDate(video.url), systemImage: "calendar")
                        SidebarDivider()
                        SidebarValueRow(title: "Frame rate", value: "\(Int(video.frameRate)) FPS", systemImage: "speedometer")
                        SidebarDivider()
                        SidebarValueRow(
                            title: "Resolution",
                            value: "\(Int(video.size.width)) x \(Int(video.size.height))",
                            systemImage: "rectangle"
                        )
                    }
                } else {
                    VideoSidebarHint("No video selected.")
                }
            }

            SidebarDisclosureSection(
                id: "video.export",
                title: "Export",
                systemImage: "square.and.arrow.up",
                subtitle: "Trimmed video or GIF output settings."
            ) {
                ExportTypeSelector(exportManager: exportManager)

                if exportManager.settings.exportType == .video {
                    VideoExportSettingsView(exportManager: exportManager)
                } else {
                    GIFExportSettingsView(
                        exportManager: exportManager,
                        sourceSize: video?.size
                    )
                }
            }
        }
    }

    private var profileControl: some View {
        ProfileControlView<VideoEditingProfile>(
            profileManager: profileManager,
            profiles: profileManager.videoProfiles.profiles,
            activeProfile: profileManager.getActiveVideoProfile(),
            profileTypeName: "Video",
            showsHeader: false,
            usesContainer: false,
            onProfileSelected: { profile in
                profileManager.applyVideoProfile(profile, to: settings)
            },
            onProfileAdded: { name in
                let newProfile = profileManager.createVideoProfileFromCurrentSettings(
                    name: name,
                    from: settings
                )
                profileManager.setActiveVideoProfile(newProfile)
            },
            onProfileEdited: updateProfile,
            onProfileDeleted: { profile in
                profileManager.removeVideoProfile(withId: profile.id)
            },
            onImportProfiles: {
                _ = profileManager.importVideoProfiles()
            },
            onExportProfiles: {
                _ = profileManager.exportVideoProfiles()
            },
            onResetProfiles: {
                profileManager.resetVideoProfilesToDefaults()
            }
        )
    }

    private func updateProfile(_ profile: VideoEditingProfile, newName: String) {
        if newName == profile.name {
            let updatedProfile = VideoEditingProfile(
                id: profile.id,
                name: profile.name,
                isDefault: profile.isDefault,
                createdAt: profile.createdAt,
                modifiedAt: Date(),
                resolution: settings.videoResolution,
                frameRate: settings.videoFrameRate,
                bitrate: settings.videoBitrate,
                codec: settings.videoCodec,
                format: settings.videoFormat,
                recordSystemAudio: settings.recordSystemAudio,
                showMouseCursor: settings.showMouseCursor
            )
            profileManager.updateVideoProfile(updatedProfile)
        } else {
            var updatedProfile = profile
            updatedProfile.name = newName
            updatedProfile.modifiedAt = Date()
            profileManager.updateVideoProfile(updatedProfile)
        }
    }
}

private struct VideoSidebarHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(SidebarStyle.bodyFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#endif
