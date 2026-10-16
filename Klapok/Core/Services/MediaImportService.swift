import AppKit
import AVFoundation
import ImageIO

/// Loads images at native pixel dimensions and stages videos without modifying originals.
enum MediaImportService {
    enum ImportError: LocalizedError {
        case invalidImage
        case invalidVideo

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "This file could not be opened as an image.".localized
            case .invalidVideo: return "This file does not contain a playable video track.".localized
            }
        }
    }

    static func loadImage(from url: URL) throws -> NSImage {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary) else { throw ImportError.invalidImage }
        let result = NSImage(size: NSSize(width: image.width, height: image.height))
        result.addRepresentation(NSBitmapImageRep(cgImage: image))
        return result
    }

    static func importVideo(from url: URL, into directory: URL) async throws -> VideoRecording {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        // A private copy keeps deferred playback/export working after the open-panel grant ends.
        let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: copy)
            let asset = AVURLAsset(url: copy)
            guard try await asset.load(.isPlayable),
                  let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw ImportError.invalidVideo
            }
            let duration = try await asset.load(.duration).seconds
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let bounds = CGRect(origin: .zero, size: naturalSize).applying(transform)
            let rate = try await track.load(.nominalFrameRate)
            guard duration.isFinite, duration > 0, bounds.width > 0, bounds.height > 0 else {
                throw ImportError.invalidVideo
            }
            return VideoRecording(url: copy, duration: duration,
                size: CGSize(width: abs(bounds.width), height: abs(bounds.height)),
                frameRate: rate > 0 ? Double(rate) : 30)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }
}
