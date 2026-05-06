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
    private let stateLock = NSLock()
    private var firstFrameArrivalDate: Date?

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
            let writerSettings = VideoCaptureConfigurationBuilder.writerSettings(
                outputSize: outputSize ?? ScreenPixelGeometry.captureSize(
                    for: NSScreen.main,
                    mode: settings.capturePixelMode
                ),
                settings: settings
            )

            assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: writerSettings.fileType)

            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: writerSettings.outputSettings
            )
            input.expectsMediaDataInRealTime = true
            videoInput = input

            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: input,
                sourcePixelBufferAttributes: writerSettings.pixelBufferAttributes
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
                stateLock.lock()
                if firstFrameArrivalDate == nil {
                    firstFrameArrivalDate = Date()
                }
                stateLock.unlock()
            }
        }

        videoInput.append(sampleBuffer)
    }

    var hasReceivedFirstFrame: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return firstFrameArrivalDate != nil
    }

    var firstFrameDate: Date? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return firstFrameArrivalDate
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
