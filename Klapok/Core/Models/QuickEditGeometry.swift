import Foundation

/// Crop coordinates are normalized, with the origin at the top left.
enum QuickEditGeometry {
    static let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func normalizedCrop(_ rect: CGRect) -> CGRect {
        let clipped = rect.standardized.intersection(fullFrame)
        guard !clipped.isNull, clipped.width >= 0.01, clipped.height >= 0.01 else { return fullFrame }
        return clipped
    }

    static func aspectFit(_ size: CGSize, in bounds: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: (bounds.width - fitted.width) / 2, y: (bounds.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}
