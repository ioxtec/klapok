import XCTest
import AVFoundation
import CoreImage
import ScreenCaptureKit
@testable import Klapok

@MainActor
final class RecordingFinalizationTests: XCTestCase {
    private var folder: URL!
    private var original: VideoEditingProfile!

    override func setUp() {
        folder = TestHelpers.createTempDirectory()
        original = VideoEditingProfile.fromAppSettings(.shared, name: "Original")
        AppSettings.shared.videoCodec = "H.264"
        AppSettings.shared.videoFormat = "MOV"
        AppSettings.shared.videoFrameRate = 30
    }

    override func tearDown() {
        original.applyToAppSettings(.shared)
        TestHelpers.removeDirectory(folder)
    }

    func testNoFramesCannotBeReportedAsSuccessfulRecording() async {
        let output = VideoStreamOutput(recordingURL: folder.appendingPathComponent("empty.mov"),
                                       outputSize: CGSize(width: 160, height: 100))
        do {
            try await output.finishWriting()
            XCTFail("An empty recording must fail")
        } catch { XCTAssertFalse(output.hasReceivedFirstFrame) }
    }

    func testWriterSetupFailureIsPropagated() async {
        let output = VideoStreamOutput(recordingURL: folder.appendingPathComponent("missing/file.mov"),
                                       outputSize: CGSize(width: 160, height: 100))
        do { try await output.finishWriting(); XCTFail("Writer setup must fail") } catch { }
    }

    func testStaticScreenKeepsRecordingDurationUntilStop() async throws {
        let url = folder.appendingPathComponent("static.mov")
        let output = VideoStreamOutput(recordingURL: url, outputSize: CGSize(width: 160, height: 100))
        output.appendVideoSampleBuffer(try videoSample(at: 0))
        try await output.finishWriting(elapsedDuration: 1.5)
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let end = CMTimeRangeGetEnd(try await track.load(.timeRange)).seconds
        XCTAssertEqual(end, 1.5, accuracy: 0.05)
        let frame = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(seconds: 1.4, preferredTimescale: 600))
        XCTAssertEqual(frame.image.width, 160)
        XCTAssertEqual(frame.image.height, 100)
    }

    func testAudioTailIsPreservedAndThumbnailsStayWithinVideoTrack() async throws {
        let source = folder.appendingPathComponent("audio.mov")
        let output = VideoStreamOutput(recordingURL: source, outputSize: CGSize(width: 160, height: 100), capturesAudio: true)
        output.appendVideoSampleBuffer(try videoSample(at: 0))
        for index in 0..<20 {
            try await Task.sleep(for: .milliseconds(15))
            output.appendAudioSampleBuffer(try audioSample(at: Double(index) / 10))
        }
        try await output.finishWriting()
        let asset = AVURLAsset(url: source)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let video = try XCTUnwrap(videoTracks.first)
        let audio = try XCTUnwrap(audioTracks.first)
        let videoEnd = CMTimeRangeGetEnd(try await video.load(.timeRange)).seconds
        let audioEnd = CMTimeRangeGetEnd(try await audio.load(.timeRange)).seconds
        XCTAssertGreaterThan(audioEnd, 1.8)
        XCTAssertEqual(videoEnd, audioEnd, accuracy: 0.06)

        // Reproduce an imported file whose audio outlasts its video.
        let composition = AVMutableComposition()
        let v = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
        let a = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
        try v.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: 0.8, preferredTimescale: 600)), of: video, at: .zero)
        try a.insertTimeRange(try await audio.load(.timeRange), of: audio, at: .zero)
        let tailed = folder.appendingPathComponent("long-audio.mov")
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        try await exporter.export(to: tailed, as: .mov)
        let recording = VideoRecording(url: tailed, duration: audioEnd, size: CGSize(width: 160, height: 100), frameRate: 30)
        let thumbnails = await TimelineThumbnailGenerator.generate(for: recording, width: 864)
        XCTAssertEqual(thumbnails.count, 12)
        XCTAssertTrue(thumbnails.allSatisfy { $0.time >= 0 && $0.time < 0.8 })
    }

    func testThumbnailWidthRejectsInvalidNumbers() {
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: .nan), 6)
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: .infinity), 6)
        XCTAssertEqual(TimelineThumbnailGenerator.targetCount(for: 100_000), 36)
    }

    private func videoSample(at seconds: Double) throws -> CMSampleBuffer {
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 160, 100, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer), kCVReturnSuccess)
        let pixels = try XCTUnwrap(buffer)
        CIContext().render(CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.7)).cropped(to: CGRect(x: 0, y: 0, width: 160, height: 100)), to: pixels)
        var format: CMVideoFormatDescription?
        XCTAssertEqual(CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels, formatDescriptionOut: &format), noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: CMTime(seconds: seconds, preferredTimescale: 600), decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels,
            formatDescription: try XCTUnwrap(format), sampleTiming: &timing, sampleBufferOut: &sample), noErr)
        return try XCTUnwrap(sample)
    }

    private func audioSample(at seconds: Double) throws -> CMSampleBuffer {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000, channels: 2, interleaved: true))
        var description: CMAudioFormatDescription?
        XCTAssertEqual(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: format.streamDescription,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description), noErr)
        var block: CMBlockBuffer?
        let size = 4800 * 4
        XCTAssertEqual(CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil,
            blockLength: size, blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
            dataLength: size, flags: 0, blockBufferOut: &block), noErr)
        let data = try XCTUnwrap(block)
        XCTAssertEqual(CMBlockBufferFillDataBytes(with: 0, blockBuffer: data, offsetIntoDestination: 0, dataLength: size), noErr)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48000),
            presentationTimeStamp: CMTime(seconds: seconds, preferredTimescale: 48000), decodeTimeStamp: .invalid)
        var sampleSize = 4
        var sample: CMSampleBuffer?
        XCTAssertEqual(CMSampleBufferCreateReady(allocator: kCFAllocatorDefault, dataBuffer: data,
            formatDescription: try XCTUnwrap(description), sampleCount: 4800, sampleTimingEntryCount: 1,
            sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sample), noErr)
        return try XCTUnwrap(sample)
    }
}
