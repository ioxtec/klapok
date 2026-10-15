import AppKit
import CoreImage
@preconcurrency import AVFoundation

/// One renderer shared by playback, video export and GIF export.
enum VideoFrameRenderer {
    private enum FrameError: LocalizedError {
        case unavailableFrame(String)
        var errorDescription: String? {
            if case let .unavailableFrame(reason) = self { return "Could not render video frame: \(reason)." }
            return nil
        }
    }

    static func isUsableFrameExtent(_ extent: CGRect) -> Bool {
        !extent.isNull && !extent.isInfinite && !extent.isEmpty
            && extent.origin.x.isFinite && extent.origin.y.isFinite && extent.width.isFinite && extent.height.isFinite
            && extent.width > 0 && extent.height > 0
    }
    struct OverlayImage {
        let image: CIImage
        let cgImage: CGImage
        let start: Double
        let end: Double
    }

    @MainActor
    static func composition(asset: AVAsset, size: CGSize, crop: CGRect,
                            overlays: [TimelineOverlayTrack]) async throws -> AVVideoComposition {
        let crop = QuickEditGeometry.normalizedCrop(crop)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw VideoExportService.ExportError.exportSessionUnavailable }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let orientedBounds = CGRect(origin: .zero, size: naturalSize).applying(transform).standardized
        let sourceFrameBounds = CGRect(origin: .zero, size: orientedBounds.size)
        let images = overlays.compactMap { rasterize($0, size: size) }
        let generated = try await AVVideoComposition.videoComposition(with: asset, applyingCIFiltersWithHandler: { request in
            let source = request.sourceImage
            // AVFoundation supplies an infinite solid-color image for gaps before
            // the first sample. This is a valid frame, bounded by the source video.
            let extent = source.extent.isInfinite ? sourceFrameBounds : source.extent
            // Never calculate transform scales from an empty/invalid source extent.
            guard isUsableFrameExtent(extent), size.width.isFinite, size.height.isFinite,
                  size.width > 0, size.height > 0 else {
                request.finish(with: FrameError.unavailableFrame("source extent \(extent), output \(size)"))
                return
            }
            let region = CGRect(x: extent.minX + crop.minX * extent.width,
                y: extent.minY + (1 - crop.maxY) * extent.height,
                width: crop.width * extent.width, height: crop.height * extent.height)
            guard isUsableFrameExtent(region) else {
                request.finish(with: FrameError.unavailableFrame("crop extent \(region)"))
                return
            }
            let clipped: CIImage? = source.cropped(to: region)
            let translated: CIImage? = clipped?.transformed(by: CGAffineTransform(translationX: -region.minX, y: -region.minY))
            let scaled: CIImage? = translated?.transformed(by: CGAffineTransform(scaleX: size.width / region.width, y: size.height / region.height))
            guard var frame = scaled else {
                request.finish(with: FrameError.unavailableFrame("scaling to \(size)"))
                return
            }
            let time = request.compositionTime.seconds
            for overlay in images where time >= overlay.start && time < overlay.end {
                let composited: CIImage? = overlay.image.composited(over: frame)
                guard let composited else {
                    request.finish(with: FrameError.unavailableFrame("annotation composition"))
                    return
                }
                frame = composited
            }
            // Core Image declares these APIs nonnull, but invalid source frames can
            // still return nil. Never pass such an object to AVFoundation's finish.
            let output: CIImage? = frame.cropped(to: CGRect(origin: .zero, size: size))
            guard let output else {
                request.finish(with: FrameError.unavailableFrame("output crop"))
                return
            }
            request.finish(with: output, context: nil)
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
        let type = track.kind.annotationType
        let annotation = Annotation(type: type, startPoint: start, endPoint: end, text: track.text,
            fontSize: max(6, size.height * track.fontScale), fontWeight: track.fontWeight, color: track.color,
            strokeWidth: max(1, size.height * track.strokeScale), fillOpacity: track.fillOpacity,
            arrowheadSize: max(12, size.height * 0.02), arrowStyle: track.arrowStyle)
        if track.kind == .text {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            let rect = CGRect(x: start.x, y: size.height - start.y - track.height * size.height,
                width: max(1, track.width * size.width), height: max(1, track.height * size.height))
            NSAttributedString(string: track.text, attributes: [
                .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: track.fontWeight.nsWeight),
                .foregroundColor: track.color.toNSColor(), .paragraphStyle: paragraph
            ]).draw(in: rect)
        } else {
            ImageCompositeRenderer.drawAnnotations([annotation], in: NSRect(origin: .zero, size: size), imageSize: size)
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = bitmap.cgImage else { return nil }
        return OverlayImage(image: CIImage(cgImage: cgImage), cgImage: cgImage, start: track.start, end: track.end)
    }

    @MainActor
    static func previewImage(_ track: TimelineOverlayTrack, size: CGSize) -> NSImage? {
        guard size.width >= 1, size.height >= 1, let rendered = rasterize(track, size: size) else { return nil }
        return NSImage(cgImage: rendered.cgImage, size: size)
    }
}
