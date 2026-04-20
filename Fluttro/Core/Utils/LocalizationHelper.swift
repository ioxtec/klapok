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
    static let takeScreenshotMenu = "take_screenshot_menu"
    static let recordScreenMenu = "record_screen_menu"
    static let settingsMenu = "settings_menu"
    static let quitMenu = "quit_menu"
    static let statusItemTooltip = "status_item_tooltip"

    // MARK: - Capture
    static let captureModeImage = "capture_mode_image"
    static let captureModeVideo = "capture_mode_video"
    static let captureTypeFullScreen = "capture_type_full_screen"
    static let captureTypeArea = "capture_type_area"
    static let captureTypeWindow = "capture_type_window"
    static let defaultCaptureTargetTitle = "default_capture_target_title"
    static let defaultCaptureTargetDescription = "default_capture_target_description"
    static let captureModeToggleHelp = "capture_mode_toggle_help"
    static let closePanelHelp = "close_panel_help"
    static let recordFullScreenHelp = "record_full_screen_help"
    static let recordAreaHelp = "record_area_help"
    static let recordWindowHelp = "record_window_help"
    static let stopRecordingHelp = "stop_recording_help"
    static let fullScreenCaptureHelp = "full_screen_capture_help"
    static let areaCaptureHelp = "area_capture_help"
    static let windowCaptureHelp = "window_capture_help"
    
    // MARK: - Language
    static let languageTitle = "language_title"
    static let languageDescription = "language_description"
    static let languageOptionSystem = "language_option_system"
    static let languageOptionEnglish = "language_option_english"
    static let languageOptionPolish = "language_option_polish"
    
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
    static let recordingBehaviorTitle = "recording_behavior_title"
    static let showMouseCursorVideoTitle = "show_mouse_cursor_video_title"
    static let showMouseCursorVideoDescription = "show_mouse_cursor_video_description"
    static let filesTitle = "files_title"
    
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
    static let appBehaviorDescription = "app_behavior_description"
    static let capturePixelModeTitle = "capture_pixel_mode_title"
    static let capturePixelModeDescription = "capture_pixel_mode_description"
    static let capturePixelModeReal = "capture_pixel_mode_real"
    static let capturePixelModeScaled = "capture_pixel_mode_scaled"
    static let reviewPositionTitle = "review_position_title"
    static let reviewPositionDescription = "review_position_description"
    static let reviewPositionBottomRight = "review_position_bottom_right"
    static let reviewPositionBottomLeft = "review_position_bottom_left"
    static let reviewPositionTopRight = "review_position_top_right"
    static let reviewPositionTopLeft = "review_position_top_left"
    static let reviewPositionBottomCenter = "review_position_bottom_center"
    
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
