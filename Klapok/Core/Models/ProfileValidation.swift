import AppKit

enum ProfileImportError: LocalizedError {
    case emptyCollection, invalidCollection, invalidSettings, invalidBackground

    var errorDescription: String? {
        switch self {
        case .emptyCollection: return "The profile file is empty. Your existing profiles have not been changed.".localized
        case .invalidCollection: return "The profile file contains duplicate identifiers or an invalid selection.".localized
        case .invalidSettings: return "The profile file contains unsupported or invalid settings.".localized
        case .invalidBackground: return "The profile background image is missing or could not be read.".localized
        }
    }
}

extension ProfileCollection {
    func validated() throws -> Self {
        guard !profiles.isEmpty else { throw ProfileImportError.emptyCollection }
        let ids = Set(profiles.map(\.id))
        guard ids.count == profiles.count,
              activeProfileId.map({ ids.contains($0) }) ?? true else { throw ProfileImportError.invalidCollection }
        for profile in profiles {
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ProfileImportError.invalidSettings
            }
            if let image = profile as? ImageEditingProfile {
                guard image.backgroundPadding.isFinite, (0...10000).contains(image.backgroundPadding),
                      image.backgroundCornerRadius.isFinite, (0...10000).contains(image.backgroundCornerRadius),
                      image.shadowIntensity.isFinite, (0...100).contains(image.shadowIntensity),
                      image.imageQuality.isFinite, (0...1).contains(image.imageQuality) else {
                    throw ProfileImportError.invalidSettings
                }
                if let appearance = image.appearance {
                    guard appearance.imageCornerRadius.isFinite, (0...10000).contains(appearance.imageCornerRadius) else {
                        throw ProfileImportError.invalidSettings
                    }
                    if appearance.backgroundType == .image {
                        guard let blur = appearance.backgroundImage?.blurRadius,
                              blur.isFinite, BackgroundImageBlur.range.contains(blur) else {
                            throw ProfileImportError.invalidSettings
                        }
                        guard appearance.backgroundImage != nil, let data = appearance.backgroundImageData,
                              NSBitmapImageRep(data: data) != nil else { throw ProfileImportError.invalidBackground }
                    }
                }
            }
            if let video = profile as? VideoEditingProfile {
                guard ["Source", "1080p", "720p", "480p"].contains(video.resolution),
                      (1...240).contains(video.frameRate), (1...100_000_000).contains(video.bitrate),
                      ["H.264", "H.265"].contains(video.codec), ["MP4", "MOV"].contains(video.format),
                      (1...30).contains(video.recordingCountdownSeconds) else { throw ProfileImportError.invalidSettings }
            }
        }
        var result = self
        if result.activeProfileId == nil { result.activeProfileId = profiles.first?.id }
        return result
    }
}
