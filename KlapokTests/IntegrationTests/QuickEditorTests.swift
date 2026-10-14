import XCTest
import AppKit
import AVFoundation
import CoreImage
@testable import Klapok

@MainActor
final class QuickEditorTests: XCTestCase {
    func testInvalidFrameExtentsAreRejectedBeforeFiltering() {
        XCTAssertFalse(VideoFrameRenderer.isUsableFrameExtent(.zero))
        XCTAssertFalse(VideoFrameRenderer.isUsableFrameExtent(.null))
        XCTAssertFalse(VideoFrameRenderer.isUsableFrameExtent(.infinite))
        XCTAssertFalse(VideoFrameRenderer.isUsableFrameExtent(CGRect(x: 0, y: 0, width: Double.nan, height: 100)))
        XCTAssertTrue(VideoFrameRenderer.isUsableFrameExtent(CGRect(x: 0, y: 0, width: 160, height: 100)))
    }

    func testRapidSeekingWithAndWithoutCropRemainsPlayable() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("seek.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        for crop in [QuickEditGeometry.fullFrame, CGRect(x: 0.25, y: 0, width: 0.5, height: 1)] {
            let item = try await VideoExportService.previewItem(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], crop: crop, overlays: [])
            if crop == QuickEditGeometry.fullFrame { XCTAssertNil(item.videoComposition) }
            let player = AVPlayer(playerItem: item)
            let vm = VideoEditorViewModel(video: video)
            vm.setPlayer(player)
            for index in 0..<100 { vm.updateCurrentTime(to: Double((index * 7) % 19) / 10) }
            vm.updateCurrentTime(to: 0.7)
            try await Task.sleep(for: .seconds(1))
            XCTAssertNil(player.error)
            XCTAssertNil(item.error)
            XCTAssertEqual(player.currentTime().seconds, 0.7, accuracy: 0.12)
            player.pause()
        }
    }
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

    func testEveryAnnotationKindIsRenderedInVideoPreview() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("shapes.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        for kind in TimelineOverlayTrackKind.allCases {
            var overlay = TimelineOverlayTrack(title: kind.displayName, kind: kind)
            overlay.text = "OK"; overlay.start = 0; overlay.end = 1
            overlay.x = 0.1; overlay.y = 0.1; overlay.width = 0.6; overlay.height = 0.6
            overlay.color = ColorData(color: .green)
            let item = try await VideoExportService.previewItem(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], crop: QuickEditGeometry.fullFrame, overlays: [overlay])
            let generator = AVAssetImageGenerator(asset: item.asset)
            generator.videoComposition = item.videoComposition
            let image = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
            let bitmap = NSBitmapImageRep(cgImage: image)
            var maximumGreen: CGFloat = 0
            for y in stride(from: 0, to: image.height, by: 2) {
                for x in stride(from: 0, to: image.width, by: 2) {
                    maximumGreen = max(maximumGreen, bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)?.greenComponent ?? 0)
                }
            }
            XCTAssertGreaterThan(maximumGreen, 0.2, "Missing rendered annotation: \(kind)")
        }
    }

    func testScaledExportWithTextAndArrow() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("annotations.mov")
        try await makeVideo(at: source, width: 714, height: 492, initialDelay: 0.4)
        let video = VideoRecording(url: source, duration: 2.4, size: CGSize(width: 714, height: 492), frameRate: 10)
        var text = TimelineOverlayTrack(title: "Text", kind: .text)
        text.text = "Jakis tekst"; text.start = 0.8; text.end = 2
        text.color = ColorData(color: .green)
        var arrow = TimelineOverlayTrack(title: "Arrow", kind: .callout)
        arrow.start = 0.3; arrow.end = 1.8
        arrow.color = ColorData(color: .white)
        let exported = try await VideoExportService.exportEditedVideo(video: video,
            ranges: [TimelineTimeRange(start: 0, end: 2.4)],
            settings: VideoExportSettings(scaling: .custom, customScaleFactor: 1.25, audioOption: .exclude),
            overlays: [arrow, text])
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: exported))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let frame = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 100)).image
        XCTAssertEqual(frame.width, 894)
        XCTAssertEqual(frame.height, 616)
        let bitmap = NSBitmapImageRep(cgImage: frame)
        var maximumGreen: CGFloat = 0, maximumBlue: CGFloat = 0
        for y in stride(from: 0, to: frame.height, by: 4) {
            for x in stride(from: 0, to: frame.width, by: 4) {
                let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                maximumGreen = max(maximumGreen, color.greenComponent)
                maximumBlue = max(maximumBlue, color.blueComponent)
            }
        }
        XCTAssertGreaterThan(maximumGreen, 0.5, "Missing green text in exported frame")
        XCTAssertGreaterThan(maximumBlue, 0.5, "Missing white arrow in exported frame")
    }

    func testDefaultExportKeeps1000By500WithTwoArrows() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("original-size.mov")
        try await makeVideo(at: source, width: 1000, height: 500)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 1000, height: 500), frameRate: 10)
        let manager = ExportManager(forPreview: true)
        manager.settings.videoSettings.scaling = .custom
        manager.settings.videoSettings.customScaleFactor = 1.25
        manager.resetVideoScalingForNewEditor()
        var arrow = TimelineOverlayTrack(title: "Arrow", kind: .callout)
        arrow.start = 0; arrow.end = 2
        var second = TimelineOverlayTrack(title: "Arrow 2", kind: .callout)
        second.start = 0; second.end = 2; second.y = 0.5
        let exported = try await VideoExportService.exportEditedVideo(video: video,
            ranges: [TimelineTimeRange(start: 0, end: 2)], settings: manager.effectiveVideoSettings(), overlays: [arrow, second])
        let tracks = try await AVURLAsset(url: exported).loadTracks(withMediaType: .video)
        let size = try await XCTUnwrap(tracks.first).load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 1000, height: 500))
    }

    private func makeVideo(at url: URL, width: Int = 160, height: Int = 100, initialDelay: Double = 0) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
        writer.add(input)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        let context = CIContext()
        for index in 0..<20 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
            let frame = try XCTUnwrap(buffer)
            let color = index < 10 ? CIColor(red: 1, green: 0, blue: 0) : CIColor(red: 0, green: 0, blue: 1)
            context.render(CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: width, height: height)), to: frame)
            XCTAssertTrue(adaptor.append(frame, withPresentationTime: CMTime(seconds: Double(index) / 10 + initialDelay, preferredTimescale: 1000)))
        }
        input.markAsFinished(); await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
