//
//  VideoExportService.swift
//  Fluttro
//

import Foundation

#if os(macOS)
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum VideoExportService {
    enum ExportError: LocalizedError {
        case exportSessionUnavailable
        case gifDestinationUnavailable
        case gifFrameGenerationFailed
        case gifFinalizeFailed

        var errorDescription: String? {
            switch self {
            case .exportSessionUnavailable:
                return "Could not create a video export session."
            case .gifDestinationUnavailable:
                return "Could not create a GIF destination."
            case .gifFrameGenerationFailed:
                return "Could not generate GIF frames."
            case .gifFinalizeFailed:
                return "Could not finalize GIF export."
            }
        }
    }

    static func exportEditedVideo(
        video: VideoRecording,
        ranges: [TimelineTimeRange]
    ) async throws -> URL {
        let asset = AVURLAsset(url: video.url)
        let exportAsset = try await editedExportAsset(from: asset, ranges: ranges)
        guard let exportSession = AVAssetExportSession(
            asset: exportAsset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportSessionUnavailable
        }

        let outputURL = uniqueOutputURL(
            baseName: "\(video.url.deletingPathExtension().lastPathComponent)_edited",
            fileExtension: "mp4",
            in: video.url.deletingLastPathComponent()
        )

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        try await exportSession.export(to: outputURL, as: .mp4)
        return outputURL
    }

    static func exportGIF(
        video: VideoRecording,
        ranges: [TimelineTimeRange],
        settings: GIFExportSettings
    ) async throws -> URL {
        let asset = AVURLAsset(url: video.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let targetSize = gifTargetSize(for: video.size, settings: settings)
        generator.maximumSize = targetSize

        let duration = max(0.1, ranges.reduce(0) { $0 + $1.duration })
        let frameCount = max(1, Int(duration * Double(settings.frameRate)))
        let frameDuration = duration / Double(frameCount)
        let frameTimes = (0..<frameCount).compactMap { index -> CMTime? in
            guard let sourceSeconds = sourceTime(
                forEditedOffset: Double(index) * frameDuration,
                in: ranges
            ) else {
                return nil
            }

            return CMTime(seconds: sourceSeconds, preferredTimescale: 600)
        }

        let outputURL = uniqueOutputURL(
            baseName: "\(video.url.deletingPathExtension().lastPathComponent)_animated",
            fileExtension: "gif",
            in: video.url.deletingLastPathComponent()
        )

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameTimes.count,
            nil
        ) else {
            throw ExportError.gifDestinationUnavailable
        }

        CGImageDestinationSetProperties(destination, gifFileProperties(settings: settings) as CFDictionary)

        let frameProperties = gifFrameProperties(frameRate: settings.frameRate)
        var generatedFrameCount = 0
        for time in frameTimes {
            do {
                let cgImage = try await generator.image(at: time).image
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                generatedFrameCount += 1
            } catch {
                Logger.w("VideoExportService: Failed to generate GIF frame at \(time.seconds)s: \(error)")
            }
        }

        guard generatedFrameCount > 0 else {
            throw ExportError.gifFrameGenerationFailed
        }

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.gifFinalizeFailed
        }

        Logger.d(
            "VideoExportService: GIF exported with \(generatedFrameCount) frames, \(settings.frameRate) fps, \(Int(targetSize.width))x\(Int(targetSize.height))px"
        )
        return outputURL
    }

    private static func editedExportAsset(
        from asset: AVURLAsset,
        ranges: [TimelineTimeRange]
    ) async throws -> AVAsset {
        guard !ranges.isEmpty else { return asset }

        let composition = AVMutableComposition()
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              )
        else {
            return asset
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let compositionAudioTrack = audioTracks.first.flatMap { _ in
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        var insertionTime = CMTime.zero
        for range in ranges {
            let sourceRange = CMTimeRange(
                start: CMTime(seconds: range.start, preferredTimescale: 1000),
                duration: CMTime(seconds: range.duration, preferredTimescale: 1000)
            )

            try compositionVideoTrack.insertTimeRange(
                sourceRange,
                of: sourceVideoTrack,
                at: insertionTime
            )

            if let sourceAudioTrack = audioTracks.first,
               let compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(
                    sourceRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }

            insertionTime = CMTimeAdd(insertionTime, sourceRange.duration)
        }

        let transform = try await sourceVideoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = transform

        return composition
    }

    private static func gifTargetSize(
        for videoSize: CGSize,
        settings: GIFExportSettings
    ) -> CGSize {
        let aspectRatio = videoSize.width / videoSize.height
        var targetWidth = CGFloat(settings.maxWidth)
        var targetHeight = CGFloat(settings.maxHeight)

        if targetWidth / targetHeight > aspectRatio {
            targetWidth = targetHeight * aspectRatio
        } else {
            targetHeight = targetWidth / aspectRatio
        }

        return CGSize(width: targetWidth, height: targetHeight)
    }

    private static func gifFileProperties(settings: GIFExportSettings) -> [String: Any] {
        [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: settings.loopMode == .infinite
                    ? 0
                    : (settings.loopMode == .once ? 1 : settings.loopCount),
                kCGImagePropertyGIFHasGlobalColorMap as String: true
            ]
        ]
    }

    private static func gifFrameProperties(frameRate: Int) -> [String: Any] {
        let frameDelay = 1.0 / Double(frameRate)
        return [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]
    }

    private static func sourceTime(
        forEditedOffset offset: TimeInterval,
        in ranges: [TimelineTimeRange]
    ) -> TimeInterval? {
        var remaining = offset

        for range in ranges {
            if remaining <= range.duration {
                return range.start + remaining
            }
            remaining -= range.duration
        }

        return ranges.last?.end
    }

    private static func uniqueOutputURL(
        baseName: String,
        fileExtension: String,
        in directory: URL
    ) -> URL {
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)_\(index)")
                .appendingPathExtension(fileExtension)
            index += 1
        }

        return candidate
    }
}

#endif
