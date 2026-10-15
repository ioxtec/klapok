//
//  TimelineThumbnailGenerator.swift
//  Klapok
//

import Foundation

#if os(macOS)
import AppKit
import AVFoundation

enum TimelineThumbnailGenerator {
    static func targetCount(for width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return 6 }
        return max(6, min(36, Int(min(width, 2592) / 72)))
    }

    static func generate(for video: VideoRecording, width: CGFloat) async -> [TimelineThumbnail] {
        let targetCount = targetCount(for: width)
        let asset = AVURLAsset(url: video.url)

        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let range = try? await track.load(.timeRange),
              range.start.seconds.isFinite, range.duration.seconds.isFinite,
              range.duration.seconds > 0 else { return [] }
        let start = range.start.seconds
        let duration = range.duration.seconds

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 144, height: 82)

        let step = duration / Double(targetCount)
        let tolerance = CMTime(seconds: max(0.25, step), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var thumbnails: [TimelineThumbnail] = []

        for index in 0..<targetCount {
            guard !Task.isCancelled else { return [] }
            let seconds = start + min(max(0, duration - 0.01), (Double(index) + 0.5) * step)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)

            do {
                let generated = try await generator.image(at: time)
                let image = NSImage(
                    cgImage: generated.image,
                    size: CGSize(width: generated.image.width, height: generated.image.height)
                )
                thumbnails.append(TimelineThumbnail(time: seconds, image: image))
            } catch {
                Logger.w("TimelineThumbnailGenerator: Failed to generate thumbnail at \(seconds)s: \(error)")
            }
        }

        if thumbnails.isEmpty {
            thumbnails = await fallbackThumbnails(
                from: generator,
                start: start,
                duration: duration,
                targetCount: targetCount
            )
        }

        return thumbnails
    }

    private static func fallbackThumbnails(
        from generator: AVAssetImageGenerator,
        start: TimeInterval,
        duration: TimeInterval,
        targetCount: Int
    ) async -> [TimelineThumbnail] {
        let fallbackTimes = [0, duration * 0.25, duration * 0.5, duration * 0.75].map { start + $0 }
        var fallbackImage: NSImage?

        for seconds in fallbackTimes {
            do {
                let generated = try await generator.image(
                    at: CMTime(seconds: seconds, preferredTimescale: 600)
                )
                fallbackImage = NSImage(
                    cgImage: generated.image,
                    size: CGSize(width: generated.image.width, height: generated.image.height)
                )
                break
            } catch {
                Logger.w("TimelineThumbnailGenerator: Fallback thumbnail failed at \(seconds)s: \(error)")
            }
        }

        if fallbackImage == nil {
            let times = fallbackTimes.map {
                CMTime(seconds: $0, preferredTimescale: 600)
            }

            for await result in generator.images(for: times) {
                if case .success(_, let cgImage, _) = result {
                    fallbackImage = NSImage(
                        cgImage: cgImage,
                        size: CGSize(width: cgImage.width, height: cgImage.height)
                    )
                    break
                }
            }
        }

        guard let fallbackImage else { return [] }

        return (0..<targetCount).map { index in
            TimelineThumbnail(
                time: start + duration * (Double(index) + 0.5) / Double(targetCount),
                image: fallbackImage
            )
        }
    }
}

#endif
