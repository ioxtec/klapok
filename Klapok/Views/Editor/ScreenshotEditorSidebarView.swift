//
//  ScreenshotEditorSidebarView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)

struct ScreenshotEditorSidebarView: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var backgroundManager: BackgroundManager

    var body: some View {
        SidebarScrollContainer {
            profilesSection
            backgroundSection
            canvasSection
            screenshotSection
        }
    }

    private var profilesSection: some View {
        SidebarDisclosureSection(
            id: "image.profiles",
            title: "Profiles",
            systemImage: "slider.horizontal.3",
            subtitle: "Presets for canvas size, spacing, corners, and shadow."
        ) {
            profileControl
        }
    }

    private var backgroundSection: some View {
        SidebarDisclosureSection(
            id: "image.background",
            title: "Background",
            systemImage: "paintpalette",
            subtitle: "Fill behind the screenshot."
        ) {
            BackgroundEditorView(backgroundManager: backgroundManager)
        }
    }

    private var canvasSection: some View {
        SidebarDisclosureSection(
            id: "image.canvas",
            title: "Canvas",
            systemImage: "rectangle.dashed",
            subtitle: "Outer frame, aspect ratio, and spacing."
        ) {
            if backgroundManager.collections.backgroundType == .none {
                SidebarHintText("Turn on Gradient or Image to edit canvas settings.")
            } else {
                SidebarAspectRatioGrid(selectedRatio: $viewModel.selectedAspectRatio)

                SidebarDivider()

                SidebarSliderControl(
                    title: "Outer padding",
                    valueText: "\(Int(viewModel.backgroundPadding)) px",
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    value: $viewModel.backgroundPadding,
                    range: 10...100,
                    step: 5
                )

                SidebarDivider()

                SidebarSliderControl(
                    title: "Canvas corners",
                    valueText: "\(Int(viewModel.backgroundCornerRadius)) px",
                    systemImage: "rectangle.roundedtop",
                    value: $viewModel.backgroundCornerRadius,
                    range: 0...50,
                    step: 1
                )
            }
        }
    }

    private var screenshotSection: some View {
        SidebarDisclosureSection(
            id: "image.screenshot",
            title: "Screenshot",
            systemImage: "photo",
            subtitle: "Source image corners and shadow."
        ) {
            if let image = viewModel.image {
                let sourceSize = image.pixelSize
                let outputSize = viewModel.calculateOutputSize(for: image)

                SidebarStackedValueRow(
                    title: "Source size",
                    value: "\(Int(sourceSize.width)) x \(Int(sourceSize.height)) px",
                    systemImage: "photo"
                )

                SidebarDivider()

                SidebarStackedValueRow(
                    title: "Output size",
                    value: "\(Int(outputSize.width)) x \(Int(outputSize.height)) px",
                    systemImage: "square.and.arrow.down"
                )

                SidebarDivider()
            }

            SidebarControlRow(title: "Round corners", systemImage: "rectangle.roundedtop") {
                Toggle("", isOn: $viewModel.enableRoundedCorners)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if viewModel.enableRoundedCorners {
                SidebarDivider()

                SidebarSliderControl(
                    title: "Corner radius",
                    valueText: "\(Int(viewModel.cornerRadius)) px",
                    systemImage: "capsule",
                    value: $viewModel.cornerRadius,
                    range: 0...50,
                    step: 1
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SidebarDivider()

            SidebarSliderControl(
                title: "Shadow",
                valueText: "\(Int(viewModel.shadowIntensity))%",
                systemImage: "circle.lefthalf.filled",
                value: $viewModel.shadowIntensity,
                range: 0...50,
                step: 1
            )
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.enableRoundedCorners)
    }

    private var profileControl: some View {
        ProfileControlView<ImageEditingProfile>(
            profileManager: profileManager,
            profiles: profileManager.imageProfiles.profiles,
            activeProfile: profileManager.getActiveImageProfile(),
            profileTypeName: "Image",
            showsHeader: false,
            usesContainer: false,
            onProfileSelected: { profile in
                profileManager.applyImageProfile(profile, to: viewModel)
            },
            onProfileAdded: { name in
                let newProfile = profileManager.createImageProfileFromCurrentSettings(
                    name: name,
                    from: viewModel
                )
                profileManager.setActiveImageProfile(newProfile)
            },
            onProfileEdited: updateProfile,
            onProfileDeleted: { profile in
                profileManager.removeImageProfile(withId: profile.id)
            },
            onImportProfiles: {
                _ = profileManager.importImageProfiles()
            },
            onExportProfiles: {
                _ = profileManager.exportImageProfiles()
            },
            onResetProfiles: {
                profileManager.resetImageProfilesToDefaults()
            }
        )
    }

    private func updateProfile(_ profile: ImageEditingProfile, newName: String) {
        if newName == profile.name {
            let updatedProfile = ImageEditingProfile(
                id: profile.id,
                name: profile.name,
                isDefault: profile.isDefault,
                createdAt: profile.createdAt,
                modifiedAt: Date(),
                backgroundAspectRatio: viewModel.selectedAspectRatio,
                backgroundPadding: viewModel.backgroundPadding,
                backgroundCornerRadius: viewModel.backgroundCornerRadius,
                shadowIntensity: viewModel.shadowIntensity
            )
            profileManager.updateImageProfile(updatedProfile)
        } else {
            var updatedProfile = profile
            updatedProfile.name = newName
            updatedProfile.modifiedAt = Date()
            profileManager.updateImageProfile(updatedProfile)
        }
    }
}

private struct SidebarAspectRatioGrid: View {
    @Binding var selectedRatio: BackgroundAspectRatio

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SidebarSubheading("Aspect ratio")

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(BackgroundAspectRatio.allCases, id: \.id) { ratio in
                    Button {
                        selectedRatio = ratio
                    } label: {
                        Text(ratio.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedRatio == ratio ? .white : .primary)
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        selectedRatio == ratio
                                            ? Color.accentColor
                                            : Color.primary.opacity(0.055)
                                    )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 0.7)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#endif
