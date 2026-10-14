//
//  VideoEditorSidebarView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)

struct VideoEditorSidebarView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    let video: VideoRecording?
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var exportManager: ExportManager
    let formatDuration: (TimeInterval) -> String
    let formatFileSize: (URL) -> String
    let formatDate: (URL) -> String

    var body: some View {
        sidebarContent
            .environment(\.compactEditorSidebar, true)
    }

    private var sidebarContent: some View {
        SidebarScrollContainer(leadingInset: 2, trailingInset: 4) {
            SidebarDisclosureSection(
                id: "video.profiles",
                title: "Profiles".localized,
                systemImage: "slider.horizontal.3",
                subtitle: "Presets for new recordings: size, frame rate, audio, cursor, and countdown.".localized,
                defaultExpanded: false
            ) {
                profileControl
            }

            SidebarDisclosureSection(
                id: "video.source",
                title: "Video".localized,
                systemImage: "film",
                subtitle: "Source file, duration, and capture details.".localized
            ) {
                if let video {
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarValueRow(title: "File".localized, value: video.url.lastPathComponent, systemImage: "doc")
                        SidebarValueRow(title: "Duration".localized, value: formatDuration(video.duration), systemImage: "clock")
                        SidebarValueRow(title: "Size".localized, value: formatFileSize(video.url), systemImage: "internaldrive")
                        SidebarValueRow(title: "Created".localized, value: formatDate(video.url), systemImage: "calendar")
                        SidebarValueRow(title: "Frame rate".localized, value: "\(Int(video.frameRate)) FPS", systemImage: "speedometer")
                        SidebarValueRow(
                            title: "Resolution".localized,
                            value: "\(Int(video.size.width)) x \(Int(video.size.height))",
                            systemImage: "rectangle"
                        )
                    }
                } else {
                    VideoSidebarHint("No video selected.".localized)
                }
            }

            SidebarDisclosureSection(
                id: "video.export",
                title: "Export".localized,
                systemImage: "square.and.arrow.up",
                subtitle: "Trimmed video uses the shared format and codec from video settings. GIF export keeps its own controls here.".localized
            ) {
                ExportTypeSelector(exportManager: exportManager)

                if exportManager.settings.exportType == .video {
                    VideoExportSettingsView(
                        exportManager: exportManager,
                        settings: settings
                    )
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
            profileTypeName: "Video".localized,
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
            let updatedProfile = profile.updating(from: settings)
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
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#endif
