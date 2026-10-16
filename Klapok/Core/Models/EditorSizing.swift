import CoreGraphics

/// Source-pixel values shared by annotation controls and large-image defaults.
enum EditorSizing {
    static let fontSizes = [12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72, 96, 128, 160, 192, 256, 384, 512, 768, 1024]
    static let strokeWidths = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 32, 48, 64, 96, 128, 192, 256]
    static func paddingRange(for size: CGSize, current: Double) -> ClosedRange<Double> {
        0...max(current, min(2000, max(100, Double(min(size.width, size.height)) / 4)))
    }

    static func cornerRange(for size: CGSize, current: Double) -> ClosedRange<Double> {
        0...max(current, min(2000, max(50, Double(min(size.width, size.height)) / 2)))
    }

    static func annotationScale(for size: CGSize) -> CGFloat {
        let longestEdge = max(size.width, size.height)
        guard longestEdge.isFinite else { return 1 }
        return min(16, max(1, longestEdge / 1600))
    }
}
