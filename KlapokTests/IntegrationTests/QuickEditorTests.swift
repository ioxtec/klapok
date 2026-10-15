import XCTest
import AppKit
import AVFoundation
import CoreImage
import SwiftUI
@testable import Klapok

@MainActor
final class QuickEditorTests: XCTestCase {
    func testLayerReorderingMatchesPreviewMP4AndGIFCompositing() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("layers.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        let vm = VideoEditorViewModel(video: video)
        for color in [NSColor.blue, NSColor.green] {
            vm.addOverlayTrack(kind: .rectangle)
            var track = try XCTUnwrap(vm.overlayTracks.last)
            track.x = 0.1; track.y = 0.1; track.width = 0.8; track.height = 0.8
            track.start = 0; track.end = 2; track.fillOpacity = 1
            track.color = ColorData(color: Color(nsColor: color))
            vm.updateOverlay(track)
        }
        let blue = vm.overlayTracks[0].id, green = vm.overlayTracks[1].id
        for blueOnTop in [false, true] {
            if blueOnTop { vm.moveOverlay(blue, relativeTo: green, above: true) }
            let preview = try await VideoExportService.previewItem(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], crop: QuickEditGeometry.fullFrame, overlays: vm.overlayTracks)
            let generator = AVAssetImageGenerator(asset: preview.asset)
            generator.videoComposition = preview.videoComposition
            let previewFrame = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
            let mp4 = try await VideoExportService.exportEditedVideo(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], settings: VideoExportSettings(audioOption: .exclude),
                crop: QuickEditGeometry.fullFrame, overlays: vm.overlayTracks)
            defer { try? FileManager.default.removeItem(at: mp4) }
            let output = AVAssetImageGenerator(asset: AVURLAsset(url: mp4))
            let mp4Frame = try await output.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
            let gif = try await VideoExportService.exportGIF(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], settings: GIFExportSettings(),
                crop: QuickEditGeometry.fullFrame, overlays: vm.overlayTracks)
            defer { try? FileManager.default.removeItem(at: gif) }
            let gifSource = try XCTUnwrap(CGImageSourceCreateWithURL(gif as CFURL, nil))
            let gifFrame = try XCTUnwrap(CGImageSourceCreateImageAtIndex(gifSource, 0, nil))
            for frame in [previewFrame, mp4Frame, gifFrame] {
                let color = pixel(frame)
                if blueOnTop { XCTAssertGreaterThan(color.blueComponent, color.greenComponent + 0.4) }
                else { XCTAssertGreaterThan(color.greenComponent, color.blueComponent + 0.4) }
            }
        }
    }

    func testArrowStylesSurviveMP4ExportWithoutScaling() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("arrows.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        var frames: [Data] = []
        for style in ArrowStyle.allCases {
            var track = TimelineOverlayTrack(title: "Arrow", kind: .callout)
            track.start = 0; track.end = 2; track.x = 0.1; track.y = 0.8
            track.width = 0.8; track.height = -0.6; track.strokeScale = 0.03
            track.color = ColorData(color: .green); track.arrowStyle = style
            let url = try await VideoExportService.exportEditedVideo(video: video,
                ranges: [TimelineTimeRange(start: 0, end: 2)], settings: VideoExportSettings(audioOption: .exclude),
                crop: QuickEditGeometry.fullFrame, overlays: [track])
            defer { try? FileManager.default.removeItem(at: url) }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            let frame = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
            XCTAssertEqual(frame.width, 160)
            XCTAssertEqual(frame.height, 100)
            frames.append(try XCTUnwrap(frame.dataProvider?.data) as Data)
        }
        XCTAssertEqual(Set(frames).count, 3)
    }

    func testCreationDateFollowsAppLanguageRatherThanSystemRegion() {
        let date = Date(timeIntervalSince1970: 1_760_486_400)
        let english = AppLanguage.english.formatCreationDate(date)
        let polish = AppLanguage.polish.formatCreationDate(date)
        XCTAssertTrue(english.contains("Oct"), english)
        XCTAssertTrue(polish.contains("paź"), polish)
        XCTAssertNotEqual(english, polish)
        XCTAssertEqual(AppLanguage.system.formattingLocale, Locale.autoupdatingCurrent)
        XCTAssertTrue(AppLanguage.english.formatFileSize(11_800_000).contains("11.8"))
        XCTAssertTrue(AppLanguage.polish.formatFileSize(11_800_000).contains("11,8"))
    }

    func testVideoAnnotationDefaultsAndStyleChangesAreUndoable() throws {
        let video = VideoRecording(url: URL(fileURLWithPath: "/tmp/style.mov"), duration: 10,
            size: CGSize(width: 200, height: 100), frameRate: 10)
        let vm = VideoEditorViewModel(video: video)
        vm.annotationFillOpacity = 0
        vm.annotationFontWeight = .bold
        vm.addOverlayTrack(kind: .rectangle)
        var track = try XCTUnwrap(vm.overlayTracks.first)
        XCTAssertEqual(track.fillOpacity, 0)
        XCTAssertEqual(track.fontWeight, .bold)
        track.fillOpacity = 0.7
        track.fontWeight = .regular
        vm.updateOverlay(track)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks.first?.fillOpacity, 0)
        XCTAssertEqual(vm.overlayTracks.first?.fontWeight, .bold)
        vm.redo()
        XCTAssertEqual(vm.overlayTracks.first?.fillOpacity, 0.7)
        XCTAssertEqual(vm.overlayTracks.first?.fontWeight, .regular)
    }

    func testShapeFillOpacityIsRenderedForRectangleAndCircle() throws {
        for kind in [TimelineOverlayTrackKind.rectangle, .circle, .highlight] {
            var track = TimelineOverlayTrack(title: "", kind: kind)
            track.x = 0.1; track.y = 0.1; track.width = 0.8; track.height = 0.8
            for opacity in [0.0, 0.3, 1.0] {
                track.fillOpacity = opacity
                let image = try XCTUnwrap(VideoFrameRenderer.previewImage(track, size: CGSize(width: 100, height: 100)))
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
                let color = try XCTUnwrap(bitmap.colorAt(x: 50, y: 50))
                XCTAssertEqual(color.alphaComponent, opacity, accuracy: 0.02, "\(kind), \(opacity)")
            }
        }
    }

    func testTextFontWeightAffectsRasterizedOutput() throws {
        var track = TimelineOverlayTrack(title: "Text", kind: .text)
        track.text = "Clear feedback"; track.fontScale = 0.2
        track.x = 0.1; track.y = 0.1; track.width = 0.8; track.height = 0.8
        track.fontWeight = .regular
        let regular = try XCTUnwrap(VideoFrameRenderer.previewImage(track, size: CGSize(width: 300, height: 100)))
        track.fontWeight = .bold
        let bold = try XCTUnwrap(VideoFrameRenderer.previewImage(track, size: CGSize(width: 300, height: 100)))
        XCTAssertNotEqual(regular.tiffRepresentation, bold.tiffRepresentation)
    }

    func testShapeFillOpacitySurvivesMP4Export() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("fill.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        for kind in [TimelineOverlayTrackKind.rectangle, .circle] {
            var greenSamples: [CGFloat] = []
            for opacity in [0.0, 0.3, 1.0] {
                var track = TimelineOverlayTrack(title: "Shape", kind: kind)
                track.start = 0; track.end = 2
                track.x = 0.1; track.y = 0.1; track.width = 0.8; track.height = 0.8
                track.color = ColorData(color: Color(nsColor: NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)))
                track.fillOpacity = opacity
                let url = try await VideoExportService.exportEditedVideo(video: video,
                    ranges: [TimelineTimeRange(start: 0, end: 2)], settings: VideoExportSettings(audioOption: .exclude),
                    crop: QuickEditGeometry.fullFrame, overlays: [track])
                defer { try? FileManager.default.removeItem(at: url) }
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                let frame = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 100)).image
                XCTAssertEqual(frame.width, 160)
                XCTAssertEqual(frame.height, 100)
                greenSamples.append(pixel(frame).greenComponent)
            }
            // Encoded YUV and Core Image color conversion are not linear in sRGB.
            // Check the ordered visual effect, not an exact RGB/alpha equivalence.
            XCTAssertLessThan(greenSamples[0], 0.25)
            XCTAssertGreaterThan(greenSamples[1], greenSamples[0] + 0.1)
            XCTAssertGreaterThan(greenSamples[2], greenSamples[1] + 0.1)
            XCTAssertGreaterThan(greenSamples[2], 0.8)
        }
    }

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

    func testEditedExportsMatchSharedCodecFormatAndScaling() async throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder); AppSettings.shared.resetToDefaults() }
        let source = folder.appendingPathComponent("codec-source.mov")
        try await makeVideo(at: source)
        let video = VideoRecording(url: source, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        for format in ["MP4", "MOV"] {
            for codec in ["H.264", "H.265"] {
                AppSettings.shared.videoFormat = format
                AppSettings.shared.videoCodec = codec
                var settings = VideoExportSettings(audioOption: .exclude)
                settings.scaling = .scale50
                let output = try await VideoExportService.exportEditedVideo(video: video,
                    ranges: [TimelineTimeRange(start: 0, end: 2)], settings: settings)
                XCTAssertEqual(output.pathExtension, format.lowercased())
                let asset = AVURLAsset(url: output)
                let tracks = try await asset.loadTracks(withMediaType: .video)
                let track = try XCTUnwrap(tracks.first)
                let dimensions = try await track.load(.naturalSize)
                XCTAssertEqual(dimensions, CGSize(width: 80, height: 50))
                let descriptions = try await track.load(.formatDescriptions)
                XCTAssertEqual(CMFormatDescriptionGetMediaSubType(try XCTUnwrap(descriptions.first)),
                    codec == "H.265" ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264)
                let fps = try await track.load(.nominalFrameRate)
                XCTAssertEqual(fps, 10, accuracy: 0.1)
                let audio = try await asset.loadTracks(withMediaType: .audio)
                XCTAssertTrue(audio.isEmpty)
            }
        }
    }

    func testImportedVideoStagesOriginalAndUsesOrientedDimensions() async throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = folder.appendingPathComponent("portrait.mov")
        try await makeVideo(at: source, transform: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 100, ty: 0))
        let before = try Data(contentsOf: source)
        let imported = try await MediaImportService.importVideo(from: source,
            into: folder.appendingPathComponent("imports"))
        XCTAssertNotEqual(imported.url, source)
        XCTAssertEqual(imported.size, CGSize(width: 100, height: 160))
        XCTAssertEqual(imported.frameRate, 10)
        XCTAssertEqual(try Data(contentsOf: imported.url), before)
        XCTAssertEqual(try Data(contentsOf: source), before)
    }

    func testInvalidVideoImportDoesNotLeavePrivateCopy() async throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let source = folder.appendingPathComponent("invalid.mov")
        try Data("not a video".utf8).write(to: source)
        let imports = folder.appendingPathComponent("imports")
        do {
            _ = try await MediaImportService.importVideo(from: source, into: imports)
            XCTFail("Invalid media must be rejected")
        } catch {
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: imports.path).isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
    }

    func testGIFFileHonorsSizeFPSAndLoopSettings() async throws {
        let folder = TestHelpers.createTempDirectory()
        defer { TestHelpers.removeDirectory(folder) }
        let url = folder.appendingPathComponent("gif-source.mov")
        try await makeVideo(at: url)
        let video = VideoRecording(url: url, duration: 2, size: CGSize(width: 160, height: 100), frameRate: 10)
        var settings = GIFExportSettings()
        settings.frameRate = 5
        settings.maxWidth = 60; settings.maxHeight = 80
        settings.maintainAspectRatio = false
        settings.loopMode = .count; settings.loopCount = 3
        let output = try await VideoExportService.exportGIF(video: video,
            ranges: [TimelineTimeRange(start: 0, end: 2)], settings: settings)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 10)
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 60); XCTAssertEqual(image.height, 80)
        let frame = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let gifFrame = try XCTUnwrap(frame[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        XCTAssertEqual(try XCTUnwrap(gifFrame[kCGImagePropertyGIFUnclampedDelayTime] as? Double), 0.2, accuracy: 0.01)
        let properties = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
        let gif = try XCTUnwrap(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
        XCTAssertEqual(gif[kCGImagePropertyGIFLoopCount] as? Int, 3)
        settings.loopMode = .once
        let onceOutput = try await VideoExportService.exportGIF(video: video,
            ranges: [TimelineTimeRange(start: 0, end: 2)], settings: settings)
        let onceSource = try XCTUnwrap(CGImageSourceCreateWithURL(onceOutput as CFURL, nil))
        let onceProperties = try XCTUnwrap(CGImageSourceCopyProperties(onceSource, nil) as? [CFString: Any])
        let once = onceProperties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        XCTAssertEqual(once?[kCGImagePropertyGIFLoopCount] as? Int ?? 1, 1)
    }

    private func makeVideo(at url: URL, width: Int = 160, height: Int = 100, initialDelay: Double = 0,
                           transform: CGAffineTransform = .identity) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        input.transform = transform
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
