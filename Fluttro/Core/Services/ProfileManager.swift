//
//  ProfileManager.swift
//  Fluttro
//
//  Manages video and image editing profiles/presets
//

import Foundation

#if os(macOS)
import AppKit

// MARK: - Profile Manager

@MainActor
final class ProfileManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var imageProfiles: ProfileCollection<ImageEditingProfile>
    @Published var videoProfiles: ProfileCollection<VideoEditingProfile>
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let imageProfilesURL: URL
    private let videoProfilesURL: URL
    
    // MARK: - Initialization
    
    init() {
        // Set up file URLs
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let profilesDirectory = documentsPath.appendingPathComponent("Fluttro Profiles")
        
        self.imageProfilesURL = profilesDirectory.appendingPathComponent("image_profiles.json")
        self.videoProfilesURL = profilesDirectory.appendingPathComponent("video_profiles.json")
        
        // Initialize with empty collections
        self.imageProfiles = ProfileCollection<ImageEditingProfile>()
        self.videoProfiles = ProfileCollection<VideoEditingProfile>()
        
        // Create profiles directory if it doesn't exist
        createProfilesDirectoryIfNeeded()
        
        // Load existing profiles or create defaults
        loadProfiles()
    }
    
    // MARK: - Image Profile Management
    
    func addImageProfile(_ profile: ImageEditingProfile) {
        imageProfiles.addProfile(profile)
        saveImageProfiles()
    }
    
    func updateImageProfile(_ profile: ImageEditingProfile) {
        imageProfiles.updateProfile(profile)
        saveImageProfiles()
    }
    
    func removeImageProfile(withId id: UUID) {
        imageProfiles.removeProfile(withId: id)
        saveImageProfiles()
    }
    
    func setActiveImageProfile(_ profile: ImageEditingProfile) {
        imageProfiles.setActiveProfile(profile)
        saveImageProfiles()
    }
    
    func getActiveImageProfile() -> ImageEditingProfile? {
        return imageProfiles.activeProfile
    }
    
    // MARK: - Video Profile Management
    
    func addVideoProfile(_ profile: VideoEditingProfile) {
        videoProfiles.addProfile(profile)
        saveVideoProfiles()
    }
    
    func updateVideoProfile(_ profile: VideoEditingProfile) {
        videoProfiles.updateProfile(profile)
        saveVideoProfiles()
    }
    
    func removeVideoProfile(withId id: UUID) {
        videoProfiles.removeProfile(withId: id)
        saveVideoProfiles()
    }
    
    func setActiveVideoProfile(_ profile: VideoEditingProfile) {
        videoProfiles.setActiveProfile(profile)
        saveVideoProfiles()
    }
    
    func getActiveVideoProfile() -> VideoEditingProfile? {
        return videoProfiles.activeProfile
    }
    
    // MARK: - Profile Application
    
    func applyImageProfile(_ profile: ImageEditingProfile, to viewModel: EditorViewModel) {
        profile.applyToEditorViewModel(viewModel)
        setActiveImageProfile(profile)
    }
    
    func applyVideoProfile(_ profile: VideoEditingProfile, to settings: AppSettings) {
        profile.applyToAppSettings(settings)
        setActiveVideoProfile(profile)
    }
    
    // MARK: - Profile Creation from Current Settings
    
    func createImageProfileFromCurrentSettings(name: String, from viewModel: EditorViewModel) -> ImageEditingProfile {
        let profile = ImageEditingProfile.fromEditorViewModel(viewModel, name: name)
        addImageProfile(profile)
        return profile
    }
    
    func createVideoProfileFromCurrentSettings(name: String, from settings: AppSettings) -> VideoEditingProfile {
        let profile = VideoEditingProfile.fromAppSettings(settings, name: name)
        addVideoProfile(profile)
        return profile
    }
    
    // MARK: - Reset to Defaults
    
    func resetImageProfilesToDefaults() {
        let defaultProfiles = ImageEditingProfile.createDefaultProfiles()
        imageProfiles = ProfileCollection(profiles: defaultProfiles, activeProfileId: defaultProfiles.first?.id)
        saveImageProfiles()
    }
    
    func resetVideoProfilesToDefaults() {
        let defaultProfiles = VideoEditingProfile.createDefaultProfiles()
        videoProfiles = ProfileCollection(profiles: defaultProfiles, activeProfileId: defaultProfiles.first?.id)
        saveVideoProfiles()
    }
    
    // MARK: - File Operations
    
    private func createProfilesDirectoryIfNeeded() {
        let profilesDirectory = imageProfilesURL.deletingLastPathComponent()
        
        if !fileManager.fileExists(atPath: profilesDirectory.path) {
            do {
                try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
                print("ProfileManager: Created profiles directory at \(profilesDirectory.path)")
            } catch {
                print("ProfileManager: Failed to create profiles directory: \(error)")
            }
        }
    }
    
    private func loadProfiles() {
        loadImageProfiles()
        loadVideoProfiles()
    }
    
    private func loadImageProfiles() {
        if fileManager.fileExists(atPath: imageProfilesURL.path) {
            do {
                let data = try Data(contentsOf: imageProfilesURL)
                let collection = try JSONDecoder().decode(ProfileCollection<ImageEditingProfile>.self, from: data)
                self.imageProfiles = collection
                print("ProfileManager: Loaded \(collection.profiles.count) image profiles")
            } catch {
                print("ProfileManager: Failed to load image profiles: \(error)")
                resetImageProfilesToDefaults()
            }
        } else {
            print("ProfileManager: No image profiles file found, creating defaults")
            resetImageProfilesToDefaults()
        }
    }
    
    private func loadVideoProfiles() {
        if fileManager.fileExists(atPath: videoProfilesURL.path) {
            do {
                let data = try Data(contentsOf: videoProfilesURL)
                let collection = try JSONDecoder().decode(ProfileCollection<VideoEditingProfile>.self, from: data)
                let normalizedProfiles = normalizeBuiltInVideoProfiles(collection)
                self.videoProfiles = normalizedProfiles.collection

                if normalizedProfiles.didUpdateProfiles {
                    saveVideoProfiles()
                }

                if normalizedProfiles.didUpdateActiveProfileResolution,
                   AppSettings.shared.videoResolution == "1080p" {
                    AppSettings.shared.videoResolution = "Source"
                }

                print("ProfileManager: Loaded \(normalizedProfiles.collection.profiles.count) video profiles")
            } catch {
                print("ProfileManager: Failed to load video profiles: \(error)")
                resetVideoProfilesToDefaults()
            }
        } else {
            print("ProfileManager: No video profiles file found, creating defaults")
            resetVideoProfilesToDefaults()
        }
    }

    private func normalizeBuiltInVideoProfiles(
        _ collection: ProfileCollection<VideoEditingProfile>
    ) -> (collection: ProfileCollection<VideoEditingProfile>, didUpdateProfiles: Bool, didUpdateActiveProfileResolution: Bool) {
        var normalized = collection
        var didUpdateProfiles = false
        var didUpdateActiveProfileResolution = false

        for index in normalized.profiles.indices {
            guard normalized.profiles[index].isDefault,
                  normalized.profiles[index].name == "High Quality",
                  normalized.profiles[index].resolution == "1080p" else {
                continue
            }

            normalized.profiles[index].resolution = "Source"
            normalized.profiles[index].modifiedAt = Date()
            didUpdateProfiles = true

            if normalized.activeProfileId == normalized.profiles[index].id {
                didUpdateActiveProfileResolution = true
            }
        }

        return (normalized, didUpdateProfiles, didUpdateActiveProfileResolution)
    }
    
    private func saveImageProfiles() {
        do {
            let data = try JSONEncoder().encode(imageProfiles)
            try data.write(to: imageProfilesURL)
            print("ProfileManager: Saved \(imageProfiles.profiles.count) image profiles")
        } catch {
            print("ProfileManager: Failed to save image profiles: \(error)")
        }
    }
    
    private func saveVideoProfiles() {
        do {
            let data = try JSONEncoder().encode(videoProfiles)
            try data.write(to: videoProfilesURL)
            print("ProfileManager: Saved \(videoProfiles.profiles.count) video profiles")
        } catch {
            print("ProfileManager: Failed to save video profiles: \(error)")
        }
    }
    
    // MARK: - Import/Export
    
    func exportImageProfiles() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "fluttro_image_profiles.json"
        savePanel.title = "Export Image Profiles"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let data = try JSONEncoder().encode(imageProfiles)
                try data.write(to: url)
                print("ProfileManager: Exported image profiles to \(url.path)")
                return url
            } catch {
                print("ProfileManager: Failed to export image profiles: \(error)")
            }
        }
        return nil
    }
    
    func exportVideoProfiles() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "fluttro_video_profiles.json"
        savePanel.title = "Export Video Profiles"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let data = try JSONEncoder().encode(videoProfiles)
                try data.write(to: url)
                print("ProfileManager: Exported video profiles to \(url.path)")
                return url
            } catch {
                print("ProfileManager: Failed to export video profiles: \(error)")
            }
        }
        return nil
    }
    
    func importImageProfiles() -> Bool {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.title = "Import Image Profiles"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let collection = try JSONDecoder().decode(ProfileCollection<ImageEditingProfile>.self, from: data)
                self.imageProfiles = collection
                saveImageProfiles()
                print("ProfileManager: Imported image profiles from \(url.path)")
                return true
            } catch {
                print("ProfileManager: Failed to import image profiles: \(error)")
                return false
            }
        }
        return false
    }
    
    func importVideoProfiles() -> Bool {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.title = "Import Video Profiles"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let collection = try JSONDecoder().decode(ProfileCollection<VideoEditingProfile>.self, from: data)
                self.videoProfiles = collection
                saveVideoProfiles()
                print("ProfileManager: Imported video profiles from \(url.path)")
                return true
            } catch {
                print("ProfileManager: Failed to import video profiles: \(error)")
                return false
            }
        }
        return false
    }
}

// MARK: - Profile Manager Singleton

extension ProfileManager {
    static let shared = ProfileManager()
}

#endif
