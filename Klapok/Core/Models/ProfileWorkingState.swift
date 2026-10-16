import AppKit

extension ImageEditingProfile {
    /// Compare only editable appearance, without loading embedded image bytes.
    func matchesEditorSettings(_ editor: EditorViewModel, background: BackgroundManager) -> Bool {
        let legacyOriginal = appearance == nil && name == "Original" && backgroundPadding == 0 && shadowIntensity == 0
        guard editor.selectedAspectRatio == backgroundAspectRatio,
              editor.backgroundPadding == backgroundPadding,
              editor.backgroundCornerRadius == (legacyOriginal ? 0 : backgroundCornerRadius),
              editor.shadowIntensity == shadowIntensity else { return false }
        guard let appearance = appearance ?? (legacyOriginal ? ImageProfileAppearance(backgroundType: .none) : nil) else {
            return true
        }
        guard background.collections.backgroundType == appearance.backgroundType,
              editor.enableRoundedCorners == appearance.roundsImageCorners,
              editor.cornerRadius == appearance.imageCornerRadius,
              ColorData(color: editor.selectedBackgroundColor) == appearance.imageBackgroundColor else { return false }
        switch appearance.backgroundType {
        case .none:
            return true
        case .gradient:
            guard let saved = appearance.gradient, let current = background.collections.selectedGradient else {
                return appearance.gradient == nil && background.collections.selectedGradient == nil
            }
            return saved.color1 == current.color1 && saved.color2 == current.color2
                && saved.opacity == current.opacity && saved.direction == current.direction && saved.stops == current.stops
        case .image:
            guard let saved = appearance.backgroundImage, let current = background.collections.selectedImage else { return false }
            return saved.id == current.id && saved.opacity == current.opacity
                && saved.scaleMode == current.scaleMode && saved.blurRadius == current.blurRadius
        }
    }
}

extension VideoEditingProfile {
    func matchesAppSettings(_ settings: AppSettings) -> Bool {
        resolution == settings.videoResolution && frameRate == settings.videoFrameRate
            && bitrate == settings.videoBitrate && codec == settings.videoCodec && format == settings.videoFormat
            && recordSystemAudio == settings.recordSystemAudio && showMouseCursor == settings.showMouseCursor
            && enableRecordingCountdown == settings.enableRecordingCountdown
            && recordingCountdownSeconds == settings.recordingCountdownSeconds
    }
}
