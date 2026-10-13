import AppKit
import CoreImage
@preconcurrency import AVFoundation

/// One renderer shared by playback, video export and GIF export.
enum VideoFrameRenderer {
    struct OverlayImage {
        let image: CIImage
        let start: Double
        let end: Double
    }

    @MainActor
    static func composition(asset: AVAsset, size: CGSize, crop: CGRect,
                            overlays: [TimelineOverlayTrack]) async throws -> AVVideoComposition {
        let crop = QuickEditGeometry.normalizedCrop(crop)
        let images = overlays.compactMap { rasterize($0, size: size) }
        let generated = try await AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage
            let extent = source.extent
            let region = CGRect(x: extent.minX + crop.minX * extent.width,
                y: extent.minY + (1 - crop.maxY) * extent.height,
                width: crop.width * extent.width, height: crop.height * extent.height)
            var frame = source.cropped(to: region)
                .transformed(by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
                .transformed(by: CGAffineTransform(scaleX: size.width / region.width, y: size.height / region.height))
            let time = request.compositionTime.seconds
            for overlay in images where time >= overlay.start && time < overlay.end {
                frame = overlay.image.composited(over: frame)
            }
            request.finish(with: frame.cropped(to: CGRect(origin: .zero, size: size)), context: nil)
        })
        guard let composition = generated.mutableCopy() as? AVMutableVideoComposition else {
            throw VideoExportService.ExportError.exportSessionUnavailable
        }
        composition.renderSize = size
        return composition
    }

    @MainActor
    private static func rasterize(_ track: TimelineOverlayTrack, size: CGSize) -> OverlayImage? {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let start = CGPoint(x: track.x * size.width, y: track.y * size.height)
        let end = CGPoint(x: (track.x + track.width) * size.width, y: (track.y + track.height) * size.height)
        let type: AnnotationType = track.kind == .text ? .text : (track.kind == .callout ? .arrow : .highlight)
        let annotation = Annotation(type: type, startPoint: start, endPoint: end, text: track.text,
            fontSize: max(16, size.height * 0.035), fontWeight: .semibold, color: track.color,
            strokeWidth: max(2, size.height * 0.004), fillOpacity: 0.3,
            arrowheadSize: max(12, size.height * 0.02))
        ImageCompositeRenderer.drawAnnotations([annotation], in: NSRect(origin: .zero, size: size), imageSize: size)
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = bitmap.cgImage else { return nil }
        return OverlayImage(image: CIImage(cgImage: cgImage), start: track.start, end: track.end)
    }
}
