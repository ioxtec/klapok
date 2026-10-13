import XCTest
import AppKit
import AVFoundation
import CoreImage
@testable import Klapok

@MainActor
final class QuickEditorTests: XCTestCase {
    func testImageCropPreservesAnnotationsAndCanBeUndone() throws {
        let image = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 200, height: 100))
        let manager = AnnotationManager()
        manager.editedImage = image
        manager.annotations = [Annotation(type: .arrow, startPoint: CGPoint(x: 80, y: 30),
            endPoint: CGPoint(x: 120, y: 50))]
        manager.cropImage(CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6))
        XCTAssertEqual(manager.editedImage?.pixelSize, CGSize(width: 100, height: 60))
        XCTAssertEqual(manager.annotations[0].startPoint, CGPoint(x: 30, y: 10))
        manager.undo()
        XCTAssertEqual(manager.editedImage?.pixelSize, CGSize(width: 200, height: 100))
        XCTAssertEqual(manager.annotations[0].startPoint, CGPoint(x: 80, y: 30))
        manager.redo()
        XCTAssertEqual(manager.editedImage?.pixelSize, CGSize(width: 100, height: 60))
    }

    func testAnnotationsAreRenderedWithoutBackground() throws {
        let background = BackgroundManager.shared
        let previous = background.collections.backgroundType
        background.setBackgroundType(.none)
        defer { background.setBackgroundType(previous) }
        let image = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 200, height: 100))
        let annotated = ImageCompositeRenderer.render(image: image, backgroundManager: background,
            annotations: [Annotation(type: .rectangle, startPoint: CGPoint(x: 20, y: 20),
                endPoint: CGPoint(x: 100, y: 80), color: ColorData(color: .red), strokeWidth: 8, fillOpacity: 1)],
            padding: 0, aspectRatio: .auto, shadowIntensity: 0)
        XCTAssertNotEqual(annotated.tiffRepresentation, image.tiffRepresentation)
        XCTAssertEqual(annotated.pixelSize, image.pixelSize)
    }

    func testEditedPreviewAndExportsUseCropOrderAndTimedAnnotations() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        let ranges = [TimelineTimeRange(start: 1, end: 2), TimelineTimeRange(start: 0, end: 1)]
        let crop = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        var overlay = TimelineOverlayTrack(title: "Highlight", kind: .highlight)
        overlay.start = 0; overlay.end = 0.5; overlay.x = 0; overlay.y = 0
        overlay.width = 0.8; overlay.height = 0.8; overlay.color = ColorData(color: .green)
        let preview = try await VideoExportService.previewItem(video: video, ranges: ranges, crop: crop, overlays: [overlay])
        XCTAssertEqual(preview.videoComposition?.renderSize, CGSize(width: 80, height: 100))
        let generator = AVAssetImageGenerator(asset: preview.asset)
        generator.videoComposition = preview.videoComposition
        generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
        let early = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
        let later = try await generator.image(at: CMTime(seconds: 0.7, preferredTimescale: 100)).image
        let last = try await generator.image(at: CMTime(seconds: 1.2, preferredTimescale: 100)).image
        let earlyColor = pixel(early), laterColor = pixel(later), lastColor = pixel(last)
        XCTAssertGreaterThan(earlyColor.greenComponent, laterColor.greenComponent + 0.1)
        XCTAssertGreaterThan(laterColor.blueComponent, laterColor.redComponent)
        XCTAssertGreaterThan(lastColor.redComponent, lastColor.blueComponent)
        let exported = try await VideoExportService.exportEditedVideo(video: video, ranges: ranges,
            settings: VideoExportSettings(audioOption: .exclude), crop: crop, overlays: [overlay])
        let exportedAsset = AVURLAsset(url: exported)
        let duration = try await exportedAsset.load(.duration)
        XCTAssertEqual(duration.seconds, 2, accuracy: 0.15)
        let outputGenerator = AVAssetImageGenerator(asset: exportedAsset)
        let outputFrame = try await outputGenerator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
        XCTAssertEqual(outputFrame.width, 80)
        XCTAssertGreaterThan(pixel(outputFrame).greenComponent, 0.1)
        let gif = try await VideoExportService.exportGIF(video: video, ranges: ranges,
            settings: GIFExportSettings(), crop: crop, overlays: [overlay])
        XCTAssertTrue(FileManager.default.fileExists(atPath: gif.path))
    }

    private func pixel(_ image: CGImage) -> NSColor {
        NSBitmapImageRep(cgImage: image).colorAt(x: image.width / 2, y: image.height / 2)!.usingColorSpace(.deviceRGB)!
    }

    private func makeVideo(at url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 100])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 100])
        writer.add(input)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for index in 0..<20 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 160, 100, kCVPixelFormatType_32BGRA, nil, &buffer)
            let frame = try XCTUnwrap(buffer)
            let color = index < 10 ? CIColor(red: 1, green: 0, blue: 0) : CIColor(red: 0, green: 0, blue: 1)
            context.render(CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 160, height: 100)), to: frame)
            XCTAssertTrue(adaptor.append(frame, withPresentationTime: CMTime(value: Int64(index), timescale: 10)))
        }
        input.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
