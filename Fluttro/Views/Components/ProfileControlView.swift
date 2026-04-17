//
//  ProfileControlView.swift
//  Fluttro
//
//  Compact profile control for sidebar
//

import SwiftUI

#if os(macOS)

// MARK: - Profile Control View

struct ProfileControlView<T: Profile>: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var showingAddProfile = false
    @State private var showingDeleteAlert = false
    @State private var selectedProfile: T?
    @State private var newProfileName = ""
    
    let profiles: [T]
    let activeProfile: T?
    let profileTypeName: String
    let showsHeader: Bool
    let usesContainer: Bool
    let onProfileSelected: (T) -> Void
    let onProfileAdded: (String) -> Void
    let onProfileEdited: (T, String) -> Void
    let onProfileDeleted: (T) -> Void
    let onImportProfiles: () -> Void
    let onExportProfiles: () -> Void
    let onResetProfiles: () -> Void
    
    init(
        profileManager: ProfileManager,
        profiles: [T],
        activeProfile: T?,
        profileTypeName: String,
        showsHeader: Bool = true,
        usesContainer: Bool = true,
        onProfileSelected: @escaping (T) -> Void,
        onProfileAdded: @escaping (String) -> Void,
        onProfileEdited: @escaping (T, String) -> Void,
        onProfileDeleted: @escaping (T) -> Void,
        onImportProfiles: @escaping () -> Void,
        onExportProfiles: @escaping () -> Void,
        onResetProfiles: @escaping () -> Void
    ) {
        self.profileManager = profileManager
        self.profiles = profiles
        self.activeProfile = activeProfile
        self.profileTypeName = profileTypeName
        self.showsHeader = showsHeader
        self.usesContainer = usesContainer
        self.onProfileSelected = onProfileSelected
        self.onProfileAdded = onProfileAdded
        self.onProfileEdited = onProfileEdited
        self.onProfileDeleted = onProfileDeleted
        self.onImportProfiles = onImportProfiles
        self.onExportProfiles = onExportProfiles
        self.onResetProfiles = onResetProfiles
    }
    
    var body: some View {
        Group {
            if usesContainer {
                controlContent
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    )
            } else {
                controlContent
            }
        }
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(
                profileName: $newProfileName,
                profileTypeName: profileTypeName,
                onSave: { name in
                    onProfileAdded(name)
                    newProfileName = ""
                }
            )
        }
        .alert("Delete Profile", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let profile = selectedProfile {
                    onProfileDeleted(profile)
                }
            }
        } message: {
            if let profile = selectedProfile {
                Text("Are you sure you want to delete the profile '\(profile.name)'? This action cannot be undone.")
            }
        }
    }

    private var controlContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                HStack {
                    Text("Profiles")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    optionsMenu
                }
            }
            
            // Profile controls
            HStack(spacing: 6) {
                // Profile dropdown
                Picker("", selection: Binding(
                    get: { activeProfile?.id ?? UUID() },
                    set: { id in
                        if let profile = profiles.first(where: { $0.id == id }) {
                            onProfileSelected(profile)
                        }
                    }
                )) {
                    ForEach(profiles, id: \.id) { profile in
                        HStack {
                            Text(profile.name)
                            if profile.isDefault {
                                Text("(Default)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                // Add profile button
                Button(action: {
                    showingAddProfile = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add new profile")
                
                // Save profile button (only show if there's an active profile)
                if let activeProfile = activeProfile {
                    Button(action: {
                        onProfileEdited(activeProfile, activeProfile.name)
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Save changes to current profile")
                }
                
                // Delete profile button (only show if there's an active profile and it's not default)
                if let activeProfile = activeProfile, !activeProfile.isDefault {
                    Button(action: {
                        selectedProfile = activeProfile
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                    .help("Delete profile")
                }

                if !showsHeader {
                    optionsMenu
                }
            }
        }
    }

    private var optionsMenu: some View {
        Menu {
            Button("Import Profiles") {
                onImportProfiles()
            }

            Button("Export Profiles") {
                onExportProfiles()
            }

            Divider()

            Button("Reset to Defaults") {
                onResetProfiles()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 22, height: 22)
    }
}

// MARK: - Add Profile Sheet

struct AddProfileSheet: View {
    @Binding var profileName: String
    let profileTypeName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New \(profileTypeName) Profile")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.headline)
                
                TextField("Enter profile name", text: $profileName)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(profileName)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 200)
    }
}

// MARK: - Profile Info View

struct ProfileInfoView<T: Profile>: View {
    let profile: T
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if profile.isDefault {
                    Text("(Default)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                        )
                }
                
                Spacer()
            }
            
            Text("Created: \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if profile.modifiedAt != profile.createdAt {
                Text("Modified: \(profile.modifiedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ProfileControlView<ImageEditingProfile>(
            profileManager: ProfileManager.shared,
            profiles: ImageEditingProfile.createDefaultProfiles(),
            activeProfile: ImageEditingProfile.createDefaultProfiles().first,
            profileTypeName: "Image",
            onProfileSelected: { _ in },
            onProfileAdded: { _ in },
            onProfileEdited: { _, _ in },
            onProfileDeleted: { _ in },
            onImportProfiles: { },
            onExportProfiles: { },
            onResetProfiles: { }
        )
    }
    .padding()
    .frame(width: 300)
}

#endif
