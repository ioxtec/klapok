//
//  VideoCaptureConfigurationBuilder.swift
//  Klapok
//
//  Pure mapping from app settings to screen capture and writer configuration.
//

import Foundation

#if os(macOS)
import AVFoundation
import CoreMedia
import ScreenCaptureKit

struct VideoStreamCaptureSettings {
    let outputSize: CGSize
    let minimumFrameInterval: CMTime
    let queueDepth: Int
    let showsCursor: Bool
    let capturesAudio: Bool

    func makeStreamConfiguration() -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(outputSize.width)
        configuration.height = Int(outputSize.height)
        configuration.minimumFrameInterval = minimumFrameInterval
        configuration.queueDepth = queueDepth
        configuration.showsCursor = showsCursor
        configuration.capturesAudio = capturesAudio
        return configuration
    }
}

struct VideoWriterSettings {
    let fileType: AVFileType
    let codec: AVVideoCodecType
    let videoSize: CGSize
    let averageBitRate: Int
    let expectedSourceFrameRate: Int
    let maxKeyFrameInterval: Int

    var outputSettings: [String: Any] {
        [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
    }

    var pixelBufferAttributes: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
    }

    private var compressionProperties: [String: Any] {
        var properties: [String: Any] = [
            AVVideoAverageBitRateKey: averageBitRate,
            AVVideoMaxKeyFrameIntervalKey: maxKeyFrameInterval,
            AVVideoExpectedSourceFrameRateKey: expectedSourceFrameRate,
            AVVideoAllowFrameReorderingKey: false,
            AVVideoPixelAspectRatioKey: [
                AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                AVVideoPixelAspectRatioVerticalSpacingKey: 1
            ]
        ]

        if codec == .h264 {
            properties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264BaselineAutoLevel
            properties[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCAVLC
        }

        return properties
    }
}

enum VideoCaptureConfigurationBuilder {
    static func outputSize(
        sourceSize: CGSize,
        settings: AppSettings = .shared
    ) -> CGSize {
        if settings.videoResolution == "Source" {
            return normalizedVideoSize(sourceSize)
        }

        let (width, height) = parseResolution(settings.videoResolution)
        return normalizedVideoSize(CGSize(width: width, height: height))
    }

    static func streamSettings(
        sourceSize: CGSize,
        settings: AppSettings = .shared
    ) -> VideoStreamCaptureSettings {
        let resolvedOutputSize = outputSize(sourceSize: sourceSize, settings: settings)
        return VideoStreamCaptureSettings(
            outputSize: resolvedOutputSize,
            minimumFrameInterval: CMTime(value: 1, timescale: Int32(settings.videoFrameRate)),
            queueDepth: 5,
            showsCursor: settings.showMouseCursor,
            capturesAudio: settings.recordSystemAudio
        )
    }

    static func writerSettings(
        outputSize: CGSize,
        settings: AppSettings = .shared
    ) -> VideoWriterSettings {
        VideoWriterSettings(
            fileType: settings.videoFormat == "MP4" ? .mp4 : .mov,
            codec: settings.videoCodec == "H.265" ? .hevc : .h264,
            videoSize: outputSize,
            averageBitRate: settings.videoBitrate,
            expectedSourceFrameRate: settings.videoFrameRate,
            maxKeyFrameInterval: settings.videoFrameRate * 2
        )
    }

    private static func parseResolution(_ resolution: String) -> (Int, Int) {
        switch resolution {
        case "1080p":
            return (1920, 1080)
        case "720p":
            return (1280, 720)
        case "480p":
            return (854, 480)
        default:
            return (1920, 1080)
        }
    }

    private static func normalizedVideoSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: normalizedPixelDimension(size.width),
            height: normalizedPixelDimension(size.height)
        )
    }

    private static func normalizedPixelDimension(_ value: CGFloat) -> CGFloat {
        guard value.isFinite, value > 0 else { return 2 }

        let rounded = max(2, Int(value.rounded()))
        let even = rounded.isMultiple(of: 2) ? rounded : rounded + 1
        return CGFloat(even)
    }
}

#endif
