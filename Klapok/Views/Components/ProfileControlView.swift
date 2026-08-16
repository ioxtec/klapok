//
//  ProfileControlView.swift
//  Klapok
//
//  Compact profile control for sidebar
//

import SwiftUI

#if os(macOS)

@MainActor
private final class ProfileControlViewState<T: Profile>: ObservableObject {
    @Published var showingAddProfile = false
    @Published var showingDeleteAlert = false
    @Published var showingProfileOptions = false
    @Published var selectedProfile: T?
    @Published var newProfileName = ""
}

// MARK: - Profile Control View

struct ProfileControlView<T: Profile>: View {
    @ObservedObject var profileManager: ProfileManager
    @StateObject private var viewState = ProfileControlViewState<T>()
    
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

    private var showingAddProfile: Bool {
        get { viewState.showingAddProfile }
        nonmutating set { viewState.showingAddProfile = newValue }
    }

    private var showingDeleteAlert: Bool {
        get { viewState.showingDeleteAlert }
        nonmutating set { viewState.showingDeleteAlert = newValue }
    }

    private var showingProfileOptions: Bool {
        get { viewState.showingProfileOptions }
        nonmutating set { viewState.showingProfileOptions = newValue }
    }

    private var selectedProfile: T? {
        get { viewState.selectedProfile }
        nonmutating set { viewState.selectedProfile = newValue }
    }

    private var newProfileName: String {
        get { viewState.newProfileName }
        nonmutating set { viewState.newProfileName = newValue }
    }

    private var showingAddProfileBinding: Binding<Bool> {
        Binding(get: { showingAddProfile }, set: { showingAddProfile = $0 })
    }

    private var showingDeleteAlertBinding: Binding<Bool> {
        Binding(get: { showingDeleteAlert }, set: { showingDeleteAlert = $0 })
    }

    private var showingProfileOptionsBinding: Binding<Bool> {
        Binding(get: { showingProfileOptions }, set: { showingProfileOptions = $0 })
    }

    private var newProfileNameBinding: Binding<String> {
        Binding(get: { newProfileName }, set: { newProfileName = $0 })
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
        .sheet(isPresented: showingAddProfileBinding) {
            AddProfileSheet(
                profileName: newProfileNameBinding,
                profileTypeName: profileTypeName,
                onSave: { name in
                    onProfileAdded(name)
                    newProfileName = ""
                }
            )
        }
        .alert("Delete Profile", isPresented: showingDeleteAlertBinding) {
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
                SidebarSubheading("Profiles")
            }

            HStack(spacing: 9) {
                Text("Profile")
                    .font(SidebarStyle.bodyFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 10)

                profilePicker
                    .frame(width: 150)
            }
            .frame(minHeight: 29)

            HStack(spacing: 7) {
                ProfileActionButton(title: "Add", systemImage: "plus") {
                    showingAddProfile = true
                }
                .help("Add new profile")

                if let activeProfile = activeProfile {
                    ProfileActionButton(title: "Save", systemImage: "square.and.arrow.down") {
                        onProfileEdited(activeProfile, activeProfile.name)
                    }
                    .help("Save changes to current profile")
                }

                if let activeProfile = activeProfile, !activeProfile.isDefault {
                    ProfileActionButton(
                        title: "Delete",
                        systemImage: "trash",
                        role: .destructive
                    ) {
                        selectedProfile = activeProfile
                        showingDeleteAlert = true
                    }
                    .help("Delete profile")
                }

                Spacer(minLength: 0)

                Button {
                    showingProfileOptions.toggle()
                } label: {
                    SidebarChevronButtonLabel()
                }
                .buttonStyle(.plain)
                .help("More profile actions")
                .popover(isPresented: showingProfileOptionsBinding, arrowEdge: .trailing) {
                    ProfileOptionsPopover(
                        onImportProfiles: {
                            showingProfileOptions = false
                            onImportProfiles()
                        },
                        onExportProfiles: {
                            showingProfileOptions = false
                            onExportProfiles()
                        },
                        onResetProfiles: {
                            showingProfileOptions = false
                            onResetProfiles()
                        }
                    )
                }
            }
            .frame(minHeight: 29)
        }
    }

    private var profilePicker: some View {
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
        .controlSize(.small)
        .font(SidebarStyle.bodyFont)
    }
}

private struct ProfileActionButton: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(role == .destructive ? .red : .primary)
                .frame(
                    width: SidebarStyle.actionButtonSize.width,
                    height: SidebarStyle.actionButtonSize.height
                )
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(role == .destructive ? Color.red.opacity(0.16) : Color.primary.opacity(0.055))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(role == .destructive ? Color.red.opacity(0.18) : Color.primary.opacity(0.06), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileOptionsPopover: View {
    let onImportProfiles: () -> Void
    let onExportProfiles: () -> Void
    let onResetProfiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProfileOptionButton(title: "Import Profiles", systemImage: "square.and.arrow.down") {
                onImportProfiles()
            }

            ProfileOptionButton(title: "Export Profiles", systemImage: "square.and.arrow.up") {
                onExportProfiles()
            }

            Divider()
                .opacity(0.55)

            ProfileOptionButton(
                title: "Reset to Defaults",
                systemImage: "arrow.counterclockwise",
                role: .destructive
            ) {
                onResetProfiles()
            }
        }
        .padding(10)
        .frame(width: 190)
    }
}

private struct ProfileOptionButton: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let action: () -> Void

    init(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(SidebarStyle.bodyFont)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(role == .destructive ? .red : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.001))
        }
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
        .centeredSheetWindow()
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

#endif
