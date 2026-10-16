import AppKit
import CoreImage

/// Filters only the wallpaper, before foreground pixels and annotations are drawn.
enum BackgroundImageBlur {
    static let range = 0.0...100.0
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 6
        cache.totalCostLimit = 128 * 1024 * 1024
        return cache
    }()

    static func image(at url: URL, radius: Double) -> NSImage? {
        let radius = radius.isFinite ? min(range.upperBound, max(0, radius)) : 0
        guard radius > 0 else { return NSImage(contentsOf: url) }
        let revision = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(url.path)|\(revision)|\(radius)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let original = NSImage(contentsOf: url),
              let bitmap = CaptureFileStore.nativeBitmap(from: original), let cgImage = bitmap.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let filtered = input.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: input.extent)
        guard let output = context.createCGImage(filtered, from: input.extent) else { return original }
        let result = NSImage(cgImage: output, size: original.size)
        cache.setObject(result, forKey: key, cost: output.bytesPerRow * output.height)
        return result
    }
}
