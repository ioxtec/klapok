//
//  LocalizationHelper.swift
//  Fluttro
//
//  Localization helper for String Catalogs
//

import Foundation

/// Helper function for localization using String Catalogs
/// Uses NSLocalizedString with String Catalog keys
func localized(_ key: String, comment: String = "") -> String {
    return NSLocalizedString(key, comment: comment)
}

/// Extension for String to make localization easier
extension String {
    /// Get localized string using String Catalog
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Get localized string with parameters
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

/// Localization keys - centralized for better maintenance
struct LocalizationKeys {
    
    // MARK: - App
    static let appName = "app_name"
    
    // MARK: - Language
    static let languageTitle = "language_title"
    static let languageDescription = "language_description"
    static let languageOptionSystem = "language_option_system"
    static let languageOptionEnglish = "language_option_english"
    static let languageOptionPolish = "language_option_polish"
    static let languageOptionGerman = "language_option_german"
    
    // MARK: - Image Settings
    static let imageQualityTitle = "image_quality_title"
    static let formatTitle = "format_title"
    static let formatDescription = "format_description"
    static let qualityTitle = "quality_title"
    static let qualityDescription = "quality_description"
    static let editorTitle = "editor_title"
    static let defaultGradientTitle = "default_gradient_title"
    static let defaultGradientDescription = "default_gradient_description"
    static let defaultPaddingTitle = "default_padding_title"
    static let defaultPaddingDescription = "default_padding_description"
    static let captureBehaviorTitle = "capture_behavior_title"
    
    // MARK: - Video Settings
    static let videoQualityTitle = "video_quality_title"
    static let resolutionTitle = "resolution_title"
    static let resolutionDescription = "resolution_description"
    static let fpsTitle = "fps_title"
    static let fpsDescription = "fps_description"
    static let bitrateTitle = "bitrate_title"
    static let bitrateDescription = "bitrate_description"
    static let audioTitle = "audio_title"
    static let recordSystemAudioTitle = "record_system_audio_title"
    static let recordSystemAudioDescription = "record_system_audio_description"
    static let recordMicrophoneTitle = "record_microphone_title"
    static let recordMicrophoneDescription = "record_microphone_description"
    static let audioQualityTitle = "audio_quality_title"
    static let audioQualityDescription = "audio_quality_description"
    static let recordingBehaviorTitle = "recording_behavior_title"
    static let showRecordingTimerTitle = "show_recording_timer_title"
    static let showRecordingTimerDescription = "show_recording_timer_description"
    static let showMouseCursorVideoTitle = "show_mouse_cursor_video_title"
    static let showMouseCursorVideoDescription = "show_mouse_cursor_video_description"
    static let autoStopAfterTimeTitle = "auto_stop_after_time_title"
    static let autoStopAfterTimeDescription = "auto_stop_after_time_description"
    static let maxTimeTitle = "max_time_title"
    static let maxTimeDescription = "max_time_description"
    static let filesTitle = "files_title"
    static let compressAfterRecordingTitle = "compress_after_recording_title"
    static let compressAfterRecordingDescription = "compress_after_recording_description"
    static let deleteAfterRecordingTitle = "delete_after_recording_title"
    static let deleteAfterRecordingDescription = "delete_after_recording_description"
    
    // MARK: - Permissions
    static let permissionsTitle = "permissions_title"
    static let permissionsDescription = "permissions_description"
    
    static let permissionScreenRecordingTitle = "permission_screen_recording_title"
    static let permissionScreenRecordingDescription = "permission_screen_recording_description"
    
    static let permissionFileAccessTitle = "permission_file_access_title"
    static let permissionFileAccessDescription = "permission_file_access_description"
    
    static let permissionAccessibilityTitle = "permission_accessibility_title"
    static let permissionAccessibilityDescription = "permission_accessibility_description"
    
    static let openSettingsButton = "open_settings_button"
    
    // MARK: - Settings
    static let saveDirectoryTitle = "save_directory_title"
    static let saveDirectoryOptionTitle = "save_directory_option_title"
    static let saveDirectoryDescription = "save_directory_description"
    
    static let filenameTemplateTitle = "filename_template_title"
    static let filenameTemplateOptionTitle = "filename_template_option_title"
    
    static let appBehaviorTitle = "app_behavior_title"
    
    static let showInDockTitle = "show_in_dock_title"
    static let showInDockDescription = "show_in_dock_description"
    
    static let launchAtLoginTitle = "launch_at_login_title"
    static let launchAtLoginDescription = "launch_at_login_description"
    
    static let showMouseCursorTitle = "show_mouse_cursor_title"
    static let showMouseCursorDescription = "show_mouse_cursor_description"
    
    // MARK: - Buttons
    static let chooseFolderButton = "choose_folder_button"
    static let resetDefaultsButton = "reset_defaults_button"
}
