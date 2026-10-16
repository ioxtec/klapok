import AppKit
import SwiftUI

/// Self-contained background and image styling, portable between profile libraries.
struct ImageProfileAppearance: Codable {
    var backgroundType: BackgroundType
    var gradient: CustomGradient?
    var backgroundImage: BackgroundImage?
    var backgroundImageData: Data?
    var roundsImageCorners: Bool
    var imageCornerRadius: Double
    var imageBackgroundColor: ColorData

    init(backgroundType: BackgroundType = .gradient, gradient: CustomGradient? = nil,
         backgroundImage: BackgroundImage? = nil, backgroundImageData: Data? = nil,
         roundsImageCorners: Bool = false, imageCornerRadius: Double = 12,
         imageBackgroundColor: ColorData = ColorData(color: .clear)) {
        self.backgroundType = backgroundType
        self.gradient = gradient
        self.backgroundImage = backgroundImage
        self.backgroundImageData = backgroundImageData
        self.roundsImageCorners = roundsImageCorners
        self.imageCornerRadius = imageCornerRadius
        self.imageBackgroundColor = imageBackgroundColor
    }

    static func capture(from editor: EditorViewModel, background: BackgroundManager) -> Self {
        let selectedImage = background.collections.selectedImage
        return Self(backgroundType: background.collections.backgroundType,
                    gradient: background.collections.selectedGradient,
                    backgroundImage: selectedImage,
                    backgroundImageData: selectedImage.flatMap { background.profileImageData(for: $0) },
                    roundsImageCorners: editor.enableRoundedCorners,
                    imageCornerRadius: editor.cornerRadius,
                    imageBackgroundColor: ColorData(color: editor.selectedBackgroundColor))
    }

    func apply(to editor: EditorViewModel, background: BackgroundManager) throws {
        try background.restoreProfileBackground(self)
        editor.enableRoundedCorners = roundsImageCorners
        editor.cornerRadius = imageCornerRadius
        editor.selectedBackgroundColor = imageBackgroundColor.color
    }
}
