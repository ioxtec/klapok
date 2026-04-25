//
//  CaptureOutputValidationTests.swift
//  FluttroTests
//
//  Integration tests for saved screenshot and video output metadata.
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit
import AVFoundation
import CoreMedia
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class CaptureOutputValidationTests: XCTestCase {
    private var settings: AppSettings!
    private var testDirectory: URL!

    override func setUp() {
        super.setUp()
        testDirectory = TestHelpers.createTempDirectory()
        settings = AppSettings.shared
        settings.resetToDefaults()
        settings.saveDirectory = testDirectory.appendingPathComponent("Screenshots")
        settings.videoSaveDirectory = testDirectory.appendingPathComponent("Videos")
    }

    override func tearDown() {
        if let testDirectory {
            TestHelpers.removeDirectory(testDirectory)
        }
        settings.resetToDefaults()
        settings = nil
        testDirectory = nil
        super.tearDown()
    }

    func testSavedScreenshotCreatesPNGWithExpectedResolution() throws {
        settings.fileNameTemplate = "ScreenshotValidation"
        let image = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 320, height: 180))

        let savedURL = try XCTUnwrap(settings.saveScreenshot(image))

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(savedURL.pathExtension.lowercased(), "png")
        XCTAssertEqual(UTType(filenameExtension: savedURL.pathExtension), .png)

        let metadata = try imageMetadata(at: savedURL)
        XCTAssertEqual(metadata.pixelWidth, 320)
        XCTAssertEqual(metadata.pixelHeight, 180)
    }

    func testSavedMP4RecordingMatchesConfiguredH264Output() async throws {
        try await assertSavedRecordingMatchesSettings(
            format: "MP4",
            codec: "H.264",
            expectedFileType: .mpeg4Movie,
            expectedCodec: kCMVideoCodecType_H264
        )
    }

    func testSavedMOVRecordingMatchesConfiguredHEVCOutput() async throws {
        try await assertSavedRecordingMatchesSettings(
            format: "MOV",
            codec: "H.265",
            expectedFileType: .quickTimeMovie,
            expectedCodec: kCMVideoCodecType_HEVC
        )
    }

    private func assertSavedRecordingMatchesSettings(
        format: String,
        codec: String,
        expectedFileType: UTType,
        expectedCodec: CMVideoCodecType
    ) async throws {
        settings.videoFileNameTemplate = "RecordingValidation"
        settings.videoFormat = format
        settings.videoCodec = codec
        settings.videoFrameRate = 24
        settings.videoBitrate = 1_000_000

        let size = CGSize(width: 320, height: 180)
        let sourceURL = testDirectory
            .appendingPathComponent("source-\(format.lowercased())-\(codec.replacingOccurrences(of: ".", with: ""))")
            .appendingPathExtension(format.lowercased())

        try await makeTestVideo(
            at: sourceURL,
            fileType: format == "MP4" ? .mp4 : .mov,
            codec: codec == "H.265" ? .hevc : .h264,
            size: size,
            frameRate: settings.videoFrameRate,
            bitRate: settings.videoBitrate
        )

        let savedURL = try XCTUnwrap(settings.saveVideo(sourceURL))

        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path))
        XCTAssertEqual(savedURL.pathExtension.lowercased(), format.lowercased())
        XCTAssertEqual(UTType(filenameExtension: savedURL.pathExtension), expectedFileType)

        let metadata = try await videoMetadata(at: savedURL)
        XCTAssertEqual(metadata.width, Int(size.width))
        XCTAssertEqual(metadata.height, Int(size.height))
        XCTAssertEqual(metadata.codec, expectedCodec)
    }

    private func imageMetadata(at url: URL) throws -> (pixelWidth: Int, pixelHeight: Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = try XCTUnwrap(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    private func videoMetadata(at url: URL) async throws -> (width: Int, height: Int, codec: CMVideoCodecType) {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let transformedSize = naturalSize.applying(transform)
        let formatDescriptions = try await track.load(.formatDescriptions)
        let formatDescription = try XCTUnwrap(formatDescriptions.first)

        return (
            Int(abs(transformedSize.width).rounded()),
            Int(abs(transformedSize.height).rounded()),
            CMFormatDescriptionGetMediaSubType(formatDescription)
        )
    }

    private func makeTestVideo(
        at url: URL,
        fileType: AVFileType,
        codec: AVVideoCodecType,
        size: CGSize,
        frameRate: Int,
        bitRate: Int
    ) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: frameRate
            ]
        ]

        guard writer.canApply(outputSettings: outputSettings, forMediaType: .video) else {
            throw XCTSkip("Codec \(codec.rawValue) is not available for \(fileType.rawValue) on this Mac.")
        }

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )

        guard writer.canAdd(input) else {
            throw XCTSkip("Cannot add video input for \(codec.rawValue) in \(fileType.rawValue).")
        }

        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)

        try await appendFrames(
            to: writer,
            input: input,
            adaptor: adaptor,
            size: size,
            frameRate: frameRate
        )

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    private func appendFrames(
        to writer: AVAssetWriter,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        size: CGSize,
        frameRate: Int
    ) async throws {
        let frameCount = max(1, frameRate)

        for frameIndex in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            let buffer = try Self.pixelBuffer(width: Int(size.width), height: Int(size.height), frameIndex: frameIndex)
            let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))
            guard adaptor.append(buffer, withPresentationTime: time) else {
                writer.cancelWriting()
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }

    private nonisolated static func pixelBuffer(width: Int, height: Int, frameIndex: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ] as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw CocoaError(.coderInvalidValue)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw CocoaError(.coderInvalidValue)
        }

        let byteCount = CVPixelBufferGetBytesPerRow(pixelBuffer) * height
        memset(baseAddress, Int32((frameIndex * 7) % 255), byteCount)
        return pixelBuffer
    }
}

#endif
