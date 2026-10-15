//
//  VideoStreamOutput.swift
//  Klapok
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
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let recordingURL: URL
    private var sessionStarted = false
    private let outputSize: CGSize?
    private let capturesAudio: Bool
    private let stateLock = NSLock()
    private var firstFrameArrivalDate: Date?
    private var lastVideoEndTime: CMTime?
    private var lastAudioEndTime: CMTime?
    private var firstPresentationTime: CMTime?
    private var lastPixelBuffer: CVPixelBuffer?
    private let frameDuration: CMTime

    init(recordingURL: URL, outputSize: CGSize? = nil, capturesAudio: Bool = false) {
        self.recordingURL = recordingURL
        self.outputSize = outputSize
        self.capturesAudio = capturesAudio
        self.frameDuration = CMTime(value: 1, timescale: Int32(AppSettings.shared.videoFrameRate))
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

            if capturesAudio {
                let audioInput = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey: 2,
                        AVSampleRateKey: 48_000,
                        AVEncoderBitRateKey: 192_000
                    ]
                )
                audioInput.expectsMediaDataInRealTime = true
                self.audioInput = audioInput

                if assetWriter?.canAdd(audioInput) == true {
                    assetWriter?.add(audioInput)
                } else {
                    Logger.w("VideoStreamOutput: Could not add audio input to asset writer")
                    self.audioInput = nil
                }
            }

            if assetWriter?.startWriting() != true {
                Logger.e("VideoStreamOutput: Failed to start video writer: \(assetWriter?.error?.localizedDescription ?? "Unknown error")")
            }
        } catch {
            Logger.e("VideoStreamOutput: Failed to setup video writer: \(error)")
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            appendVideoSampleBuffer(sampleBuffer)
        case .audio:
            appendAudioSampleBuffer(sampleBuffer)
        default:
            break
        }
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

    func finishWriting(elapsedDuration: TimeInterval? = nil) async throws {
        guard let assetWriter else { throw CaptureError.invalidRequest("Video writer was not created") }
        guard assetWriter.status == .writing, sessionStarted, let lastVideoEndTime else {
            throw assetWriter.error ?? CaptureError.invalidRequest("No video frames were written")
        }
        guard let videoInput else {
            throw CaptureError.invalidRequest("Video input was not created")
        }
        var end = lastVideoEndTime
        if let lastAudioEndTime, CMTimeCompare(lastAudioEndTime, end) > 0 { end = lastAudioEndTime }
        if let elapsedDuration, elapsedDuration.isFinite, elapsedDuration > 0, let firstPresentationTime {
            let stop = CMTimeAdd(firstPresentationTime, CMTime(seconds: elapsedDuration, preferredTimescale: 60000))
            if CMTimeCompare(stop, end) > 0 { end = stop }
        }
        if CMTimeCompare(end, lastVideoEndTime) > 0, let lastPixelBuffer, let pixelBufferAdaptor {
            let deadline = Date().addingTimeInterval(5)
            while !videoInput.isReadyForMoreMediaData, assetWriter.status == .writing, Date() < deadline {
                try await Task.sleep(for: .milliseconds(2))
            }
            let paddingTime = CMTimeMaximum(lastVideoEndTime, CMTimeSubtract(end, frameDuration))
            guard videoInput.isReadyForMoreMediaData,
                  pixelBufferAdaptor.append(lastPixelBuffer, withPresentationTime: paddingTime) else {
                throw assetWriter.error ?? CaptureError.invalidRequest("Could not finish the last video frame")
            }
        }
        assetWriter.endSession(atSourceTime: end)

        videoInput.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter.finishWriting()
        if assetWriter.status != .completed {
            throw assetWriter.error ?? CaptureError.invalidRequest("Video writing did not complete")
        }
    }

    func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard isCompleteVideoFrame(sampleBuffer) else { return }
        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
        guard let pixelBufferAdaptor, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let assetWriter, assetWriter.status == .writing {
            if !sessionStarted {
                assetWriter.startSession(atSourceTime: presentationTime)
                sessionStarted = true
                firstPresentationTime = presentationTime
            }
        }

        if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
            Logger.e("VideoStreamOutput: Failed to append video sample buffer: \(assetWriter?.error?.localizedDescription ?? "Unknown writer error")")
        } else {
            let sampleDuration = CMSampleBufferGetDuration(sampleBuffer)
            let duration = sampleDuration.isNumeric && sampleDuration.seconds > 0 ? sampleDuration : frameDuration
            lastVideoEndTime = CMTimeAdd(presentationTime, duration)
            lastPixelBuffer = pixelBuffer
            stateLock.lock()
            if firstFrameArrivalDate == nil { firstFrameArrivalDate = Date() }
            stateLock.unlock()
        }
    }

    func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard capturesAudio, sessionStarted else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let audioInput, audioInput.isReadyForMoreMediaData else { return }

        if !audioInput.append(sampleBuffer) {
            Logger.e("VideoStreamOutput: Failed to append audio sample buffer: \(assetWriter?.error?.localizedDescription ?? "Unknown writer error")")
        } else {
            let end = CMTimeAdd(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), CMSampleBufferGetDuration(sampleBuffer))
            if end.isNumeric { lastAudioEndTime = end }
        }
    }

    private func isCompleteVideoFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
            let firstAttachment = attachments.first
        else {
            return true
        }

        if let rawStatus = firstAttachment[.status] as? Int,
           let status = SCFrameStatus(rawValue: rawStatus) {
            return status == .complete
        }

        if let rawStatus = firstAttachment[.status] as? NSNumber,
           let status = SCFrameStatus(rawValue: rawStatus.intValue) {
            return status == .complete
        }

        return true
    }
}

#endif
