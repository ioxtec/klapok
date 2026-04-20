//
//  VideoStreamOutput.swift
//  Fluttro
//

import Foundation

#if os(macOS)
import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit

final class VideoStreamOutput: NSObject, SCStreamOutput {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let recordingURL: URL
    private var sessionStarted = false
    private let outputSize: CGSize?

    init(recordingURL: URL, outputSize: CGSize? = nil) {
        self.recordingURL = recordingURL
        self.outputSize = outputSize
        super.init()
        setupAssetWriter()
    }

    private func setupAssetWriter() {
        do {
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try FileManager.default.removeItem(at: recordingURL)
            }

            let settings = AppSettings.shared
            let fileType: AVFileType = settings.videoFormat == "MP4" ? .mp4 : .mov

            assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: fileType)

            let videoSize = outputSize ?? ScreenPixelGeometry.captureSize(
                for: NSScreen.main,
                mode: settings.capturePixelMode
            )

            let codec: AVVideoCodecType = settings.videoCodec == "H.265" ? .hevc : .h264
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: Int(videoSize.width),
                AVVideoHeightKey: Int(videoSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: settings.videoBitrate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                    AVVideoMaxKeyFrameIntervalKey: settings.videoFrameRate * 2,
                    AVVideoExpectedSourceFrameRateKey: settings.videoFrameRate,
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC,
                    AVVideoPixelAspectRatioKey: [
                        AVVideoPixelAspectRatioHorizontalSpacingKey: 1,
                        AVVideoPixelAspectRatioVerticalSpacingKey: 1
                    ]
                ]
            ]

            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true
            videoInput = input

            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(videoSize.width),
                    kCVPixelBufferHeightKey as String: Int(videoSize.height),
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                ]
            )

            if assetWriter?.canAdd(input) == true {
                assetWriter?.add(input)
            }

            if assetWriter?.startWriting() != true {
                Logger.e("VideoStreamOutput: Failed to start video writer: \(assetWriter?.error?.localizedDescription ?? "Unknown error")")
            }
        } catch {
            Logger.e("VideoStreamOutput: Failed to setup video writer: \(error)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }

        if let assetWriter, assetWriter.status == .writing {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !sessionStarted {
                assetWriter.startSession(atSourceTime: presentationTime)
                sessionStarted = true
            }
        }

        videoInput.append(sampleBuffer)
    }

    func finishWriting() async {
        guard let videoInput else {
            Logger.e("VideoStreamOutput: No video input to finish")
            return
        }

        videoInput.markAsFinished()

        guard let assetWriter else {
            Logger.e("VideoStreamOutput: No video writer to finish")
            return
        }

        await assetWriter.finishWriting()
        if assetWriter.status != .completed {
            Logger.e("VideoStreamOutput: Video writing failed: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
        }
    }
}

#endif
