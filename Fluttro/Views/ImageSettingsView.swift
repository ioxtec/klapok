//
//  ImageSettingsView.swift
//  Fluttro
//
//  Image capture settings view
//

import SwiftUI

#if os(macOS)

struct ImageSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var profileManager = ProfileManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "Image profiles",
                    subtitle: "Profiles are edited in the screenshot editor. Settings only manages the stored set.",
                    systemImage: "square.stack"
                ) {
                    SettingsProfilesSummary(
                        profiles: profileManager.imageProfiles.profiles,
                        activeProfile: profileManager.imageProfiles.activeProfile,
                        resetAction: profileManager.resetImageProfilesToDefaults,
                        exportAction: { _ = profileManager.exportImageProfiles() },
                        importAction: { _ = profileManager.importImageProfiles() }
                    )
                }

                SettingsSection(
                    title: "Capture",
                    subtitle: "Real screenshot preferences used by the capture pipeline.",
                    systemImage: "camera"
                ) {
                    SettingsPickerOption(
                        title: "Screenshot size",
                        description: "Real screen size writes physical pixels. Scaled screen size uses the macOS logical size.",
                        selection: Binding(
                            get: { viewModel.capturePixelMode.rawValue },
                            set: {
                                if let mode = CapturePixelMode(rawValue: $0) {
                                    viewModel.capturePixelMode = mode
                                }
                            }
                        ),
                        options: CapturePixelMode.allCases.map {
                            ($0.rawValue, $0.displayName)
                        }
                    )

                    SettingsPickerOption(
                        title: "Review position",
                        description: "Where the quick preview appears after taking a screenshot.",
                        isLast: true,
                        selection: Binding(
                            get: { viewModel.screenshotReviewPosition.rawValue },
                            set: {
                                if let position = ScreenshotReviewPosition(rawValue: $0) {
                                    viewModel.screenshotReviewPosition = position
                                }
                            }
                        ),
                        options: ScreenshotReviewPosition.allCases.map {
                            ($0.rawValue, $0.displayName)
                        }
                    )
                }

                SettingsSection(
                    title: "Save",
                    subtitle: "Where screenshots are written before or after editing.",
                    systemImage: "folder"
                ) {
                    SettingsPathOption(
                        title: "Screenshot folder",
                        path: viewModel.saveDirectory.path,
                        description: "Used by direct saves and exported screenshots.",
                        action: viewModel.selectSaveDirectory
                    )

                    SettingsTextOption(
                        title: "Filename template",
                        description: "Preview: \(viewModel.previewFileName)",
                        infoText: "Use {datetime} for date and time or {date} for the date.",
                        isLast: true,
                        text: $viewModel.fileNameTemplate,
                        placeholder: "Screenshot-{datetime}"
                    )
                }

            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ImageSettingsView()
}

#endif
