//
//  VideoExportService.swift
//  Klapok
//

import Foundation

#if os(macOS)
import AppKit
@preconcurrency import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum VideoExportService {
    enum ExportError: LocalizedError {
        case exportSessionUnavailable
        case assetReaderUnavailable
        case assetWriterUnavailable
        case exportFailed(String)
        case gifDestinationUnavailable
        case gifFrameGenerationFailed
        case gifFinalizeFailed

        var errorDescription: String? {
            switch self {
            case .exportSessionUnavailable:
                return "Could not create a video export session."
            case .assetReaderUnavailable:
                return "Could not create a video reader."
            case .assetWriterUnavailable:
                return "Could not create a video writer."
            case .exportFailed(let message):
                return message
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
        ranges: [TimelineTimeRange],
        settings: VideoExportSettings,
        crop: CGRect = QuickEditGeometry.fullFrame,
        overlays: [TimelineOverlayTrack] = []
    ) async throws -> URL {
        let asset = AVURLAsset(url: video.url)
        let exportAsset = try await editedExportAsset(
            from: asset,
            ranges: ranges,
            includeAudio: settings.audioOption != .exclude
        )
        let targetSize = targetVideoSize(
            from: CGSize(width: video.size.width * crop.width, height: video.size.height * crop.height),
            scaling: settings.scaling,
            customScaleFactor: settings.customScaleFactor
        )
        let videoComposition = try await VideoFrameRenderer.composition(asset: exportAsset, size: targetSize,
            crop: crop, overlays: overlays)
        let appSettings = AppSettings.shared
        let sourceFrameRate = try await sourceFrameRate(for: exportAsset)
        let outputConfiguration = editedVideoOutputConfiguration(
            targetSize: targetSize,
            quality: settings.quality,
            format: appSettings.videoFormat,
            codec: appSettings.videoCodec,
            frameRate: sourceFrameRate
        )

        let outputURL = uniqueOutputURL(
            baseName: "\(video.url.deletingPathExtension().lastPathComponent)_edited",
            fileExtension: outputConfiguration.fileExtension,
            in: video.url.deletingLastPathComponent()
        )

        try await transcodeEditedVideo(
            asset: exportAsset,
            videoComposition: videoComposition,
            audioOption: settings.audioOption,
            outputURL: outputURL,
            configuration: outputConfiguration
        )
        return outputURL
    }

    static func exportGIF(
        video: VideoRecording,
        ranges: [TimelineTimeRange],
        settings: GIFExportSettings,
        crop: CGRect = QuickEditGeometry.fullFrame,
        overlays: [TimelineOverlayTrack] = []
    ) async throws -> URL {
        let asset = AVURLAsset(url: video.url)
        let editedAsset = try await editedExportAsset(from: asset, ranges: ranges, includeAudio: false)
        let generator = AVAssetImageGenerator(asset: editedAsset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let targetSize = gifTargetSize(for: CGSize(width: video.size.width * crop.width,
            height: video.size.height * crop.height), settings: settings)
        generator.videoComposition = try await VideoFrameRenderer.composition(asset: editedAsset,
            size: targetSize, crop: crop, overlays: overlays)
        generator.maximumSize = targetSize

        let duration = max(0.1, ranges.reduce(0) { $0 + $1.duration })
        let frameCount = max(1, Int(duration * Double(settings.frameRate)))
        let frameDuration = duration / Double(frameCount)
        let frameTimes = (0..<frameCount).map { index in
            CMTime(seconds: Double(index) * frameDuration, preferredTimescale: 600)
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

    @MainActor
    static func previewItem(video: VideoRecording, ranges: [TimelineTimeRange], crop: CGRect,
                            overlays: [TimelineOverlayTrack]) async throws -> AVPlayerItem {
        let asset = try await editedExportAsset(from: AVURLAsset(url: video.url), ranges: ranges, includeAudio: true)
        let item = AVPlayerItem(asset: asset)
        let size = targetVideoSize(from: CGSize(width: video.size.width * crop.width,
            height: video.size.height * crop.height), scaling: .custom, customScaleFactor: 1)
        item.videoComposition = try await VideoFrameRenderer.composition(asset: asset, size: size, crop: crop, overlays: overlays)
        return item
    }

    private static func editedExportAsset(
        from asset: AVURLAsset,
        ranges: [TimelineTimeRange],
        includeAudio: Bool
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

        let audioTracks = includeAudio ? try await asset.loadTracks(withMediaType: .audio) : []
        let compositionAudioTrack = includeAudio ? audioTracks.first.flatMap { _ in
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        } : nil

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

    private static func targetVideoSize(
        from sourceSize: CGSize,
        scaling: VideoScaling,
        customScaleFactor: Double
    ) -> CGSize {
        let scaleFactor: Double
        switch scaling {
        case .custom:
            scaleFactor = customScaleFactor
        default:
            scaleFactor = scaling.scaleFactor
        }

        let width = normalizedPixelDimension(Double(sourceSize.width) * scaleFactor)
        let height = normalizedPixelDimension(Double(sourceSize.height) * scaleFactor)
        return CGSize(width: width, height: height)
    }

    private static func normalizedPixelDimension(_ value: Double) -> CGFloat {
        let rounded = max(2, Int(value.rounded()))
        let even = rounded.isMultiple(of: 2) ? rounded : rounded + 1
        return CGFloat(even)
    }

    private static func makeVideoComposition(
        for asset: AVAsset,
        targetSize: CGSize
    ) async throws -> AVMutableVideoComposition? {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            return nil
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let sourceSize = orientedVideoSize(naturalSize: naturalSize, transform: preferredTransform)

        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        let scaledTransform = preferredTransform.concatenating(
            CGAffineTransform(scaleX: scaleX, y: scaleY)
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: .zero,
            duration: try await asset.load(.duration)
        )

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(scaledTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]

        let composition = AVMutableVideoComposition()
        composition.instructions = [instruction]
        composition.renderSize = targetSize
        let timescale = Int32(max(1, Int(frameRate.rounded())))
        composition.frameDuration = CMTime(value: 1, timescale: timescale)
        return composition
    }

    private static func sourceFrameRate(for asset: AVAsset) async throws -> Int {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            return 30
        }

        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let resolvedFrameRate = nominalFrameRate > 0 ? Int(nominalFrameRate.rounded()) : 30
        return max(1, resolvedFrameRate)
    }

    private static func transcodeEditedVideo(
        asset: AVAsset,
        videoComposition: AVVideoComposition?,
        audioOption: AudioExportOption,
        outputURL: URL,
        configuration: EditedVideoOutputConfiguration
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw ExportError.assetReaderUnavailable
        }

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: configuration.fileType) else {
            throw ExportError.assetWriterUnavailable
        }

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ExportError.exportFailed("No video track available for export.")
        }

        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: [videoTrack],
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        videoOutput.videoComposition = videoComposition
        videoOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(videoOutput) else {
            throw ExportError.exportFailed("Could not attach the video reader output.")
        }
        reader.add(videoOutput)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: configuration.videoOutputSettings
        )
        videoInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput) else {
            throw ExportError.exportFailed("Could not attach the video writer input.")
        }
        writer.add(videoInput)

        let audioPair = try await makeAudioPipeline(
            for: asset,
            audioOption: audioOption,
            writer: writer,
            reader: reader
        )
        let readerBox = UncheckedSendableBox(reader)
        let writerBox = UncheckedSendableBox(writer)
        let videoInputBox = UncheckedSendableBox(videoInput)
        let videoOutputBox = UncheckedSendableBox(videoOutput)
        let audioPairBox = audioPair.map(UncheckedSendableBox.init)

        guard reader.startReading() else {
            throw ExportError.exportFailed(reader.error?.localizedDescription ?? "Video reading failed to start.")
        }

        guard writer.startWriting() else {
            throw ExportError.exportFailed(writer.error?.localizedDescription ?? "Video writing failed to start.")
        }

        writer.startSession(atSourceTime: .zero)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let stateQueue = DispatchQueue(label: "Klapok.VideoExportService.State")
            let videoQueue = DispatchQueue(label: "Klapok.VideoExportService.Video")
            let audioQueue = DispatchQueue(label: "Klapok.VideoExportService.Audio")
            var videoFinished = false
            var audioFinished = audioPair == nil
            var resumed = false

            func resumeOnce(with result: Result<Void, Error>) {
                stateQueue.sync {
                    guard !resumed else { return }
                    resumed = true
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            func completeStream(
                finishedVideo: Bool = false,
                finishedAudio: Bool = false
            ) {
                stateQueue.sync {
                    if finishedVideo {
                        videoFinished = true
                    }
                    if finishedAudio {
                        audioFinished = true
                    }
                }

                if videoFinished && audioFinished {
                    writerBox.value.finishWriting {
                        if readerBox.value.status == .failed {
                            resumeOnce(
                                with: .failure(
                                    ExportError.exportFailed(
                                        readerBox.value.error?.localizedDescription ?? "Video reader failed during export."
                                    )
                                )
                            )
                            return
                        }

                        if writerBox.value.status == .failed {
                            resumeOnce(
                                with: .failure(
                                    ExportError.exportFailed(
                                        writerBox.value.error?.localizedDescription ?? "Video writer failed during export."
                                    )
                                )
                            )
                            return
                        }

                        resumeOnce(with: .success(()))
                    }
                }
            }

            videoInputBox.value.requestMediaDataWhenReady(on: videoQueue) {
                while videoInputBox.value.isReadyForMoreMediaData {
                    if let sampleBuffer = videoOutputBox.value.copyNextSampleBuffer() {
                        if !videoInputBox.value.append(sampleBuffer) {
                            readerBox.value.cancelReading()
                            writerBox.value.cancelWriting()
                            resumeOnce(
                                with: .failure(
                                    ExportError.exportFailed(
                                        writerBox.value.error?.localizedDescription ?? "Failed while writing video frames."
                                    )
                                )
                            )
                            return
                        }
                    } else {
                        videoInputBox.value.markAsFinished()
                        completeStream(finishedVideo: true)
                        return
                    }
                }
            }

            if let audioPairBox {
                audioPairBox.value.input.requestMediaDataWhenReady(on: audioQueue) {
                    while audioPairBox.value.input.isReadyForMoreMediaData {
                        if let sampleBuffer = audioPairBox.value.output.copyNextSampleBuffer() {
                            if !audioPairBox.value.input.append(sampleBuffer) {
                                readerBox.value.cancelReading()
                                writerBox.value.cancelWriting()
                                resumeOnce(
                                    with: .failure(
                                        ExportError.exportFailed(
                                            writerBox.value.error?.localizedDescription ?? "Failed while writing audio samples."
                                        )
                                    )
                                )
                                return
                            }
                        } else {
                            audioPairBox.value.input.markAsFinished()
                            completeStream(finishedAudio: true)
                            return
                        }
                    }
                }
            }
        }
    }

    private static func makeAudioPipeline(
        for asset: AVAsset,
        audioOption: AudioExportOption,
        writer: AVAssetWriter,
        reader: AVAssetReader
    ) async throws -> (output: AVAssetReaderAudioMixOutput, input: AVAssetWriterInput)? {
        guard audioOption != .exclude else {
            return nil
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            return nil
        }

        let audioOutput = AVAssetReaderAudioMixOutput(
            audioTracks: audioTracks,
            audioSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM
            ]
        )
        audioOutput.alwaysCopiesSampleData = false

        if audioOption == .mute {
            let parameters = audioTracks.map { track -> AVMutableAudioMixInputParameters in
                let inputParameters = AVMutableAudioMixInputParameters(track: track)
                inputParameters.setVolume(0, at: .zero)
                return inputParameters
            }
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = parameters
            audioOutput.audioMix = audioMix
        }

        guard reader.canAdd(audioOutput) else {
            throw ExportError.exportFailed("Could not attach the audio reader output.")
        }
        reader.add(audioOutput)

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44_100,
                AVEncoderBitRateKey: 192_000
            ]
        )
        audioInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(audioInput) else {
            throw ExportError.exportFailed("Could not attach the audio writer input.")
        }
        writer.add(audioInput)

        return (audioOutput, audioInput)
    }

    private static func editedVideoOutputConfiguration(
        targetSize: CGSize,
        quality: VideoQuality,
        format: String,
        codec: String,
        frameRate: Int
    ) -> EditedVideoOutputConfiguration {
        let resolvedCodec: AVVideoCodecType = codec == "H.265" ? .hevc : .h264
        let resolvedFileType: AVFileType = format == "MOV" ? .mov : .mp4
        let resolvedFileExtension = format == "MOV" ? "mov" : "mp4"
        let maxKeyFrameInterval = max(1, frameRate * 2)

        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: quality.bitrate,
            AVVideoExpectedSourceFrameRateKey: frameRate,
            AVVideoMaxKeyFrameIntervalKey: maxKeyFrameInterval,
            AVVideoAllowFrameReorderingKey: false,
            AVVideoPixelAspectRatioKey: [
                AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                AVVideoPixelAspectRatioVerticalSpacingKey: 1
            ]
        ]

        if resolvedCodec == .h264 {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        return EditedVideoOutputConfiguration(
            fileType: resolvedFileType,
            fileExtension: resolvedFileExtension,
            videoOutputSettings: [
                AVVideoCodecKey: resolvedCodec,
                AVVideoWidthKey: Int(targetSize.width),
                AVVideoHeightKey: Int(targetSize.height),
                AVVideoCompressionPropertiesKey: compressionProperties
            ]
        )
    }

    private static func orientedVideoSize(
        naturalSize: CGSize,
        transform: CGAffineTransform
    ) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    private static func gifTargetSize(
        for videoSize: CGSize,
        settings: GIFExportSettings
    ) -> CGSize {
        guard
            videoSize.width.isFinite,
            videoSize.height.isFinite,
            videoSize.width > 0,
            videoSize.height > 0
        else {
            return CGSize(
                width: max(2, CGFloat(settings.maxWidth)),
                height: max(2, CGFloat(settings.maxHeight))
            )
        }

        let aspectRatio = videoSize.width / videoSize.height
        var targetWidth = CGFloat(settings.maxWidth)
        var targetHeight = CGFloat(settings.maxHeight)

        guard aspectRatio.isFinite, aspectRatio > 0 else {
            return CGSize(width: max(2, targetWidth), height: max(2, targetHeight))
        }

        if targetWidth / targetHeight > aspectRatio {
            targetWidth = targetHeight * aspectRatio
        } else {
            targetHeight = targetWidth / aspectRatio
        }

        return CGSize(width: max(2, targetWidth), height: max(2, targetHeight))
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

private struct EditedVideoOutputConfiguration {
    let fileType: AVFileType
    let fileExtension: String
    let videoOutputSettings: [String: Any]
}

private struct AudioPipeline {
    let output: AVAssetReaderAudioMixOutput
    let input: AVAssetWriterInput
}

private final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

#endif
