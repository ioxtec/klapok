import AppKit
import SwiftUI
import XCTest
@testable import Klapok

@MainActor
final class ArrowStyleTests: XCTestCase {
    func testLegacyAnnotationWithoutStyleDecodesAsOpenArrow() throws {
        let original = Annotation(type: .arrow, startPoint: .zero, endPoint: CGPoint(x: 100, y: 20))
        let data = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "arrowStyle")
        let legacy = try JSONDecoder().decode(Annotation.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.arrowStyle ?? .open, .open)
        for style in ArrowStyle.allCases {
            var annotation = original
            annotation.arrowStyle = style
            XCTAssertEqual(try JSONDecoder().decode(Annotation.self, from: JSONEncoder().encode(annotation)), annotation)
        }
    }

    func testImageArrowStyleDefaultsAndUndo() throws {
        let manager = AnnotationManager()
        manager.defaultArrowStyle = .triangle
        manager.selectTool(.arrow)
        manager.startDrawing(at: CGPoint(x: 20, y: 20))
        manager.updateDrawing(to: CGPoint(x: 150, y: 50))
        XCTAssertEqual(manager.currentDraft?.arrowStyle, .triangle)
        manager.finishDrawing()
        let annotation = try XCTUnwrap(manager.annotations.first)
        manager.selectAnnotation(withId: annotation.id)
        manager.updateSelectedAnnotationArrowStyle(.tapered)
        XCTAssertEqual(manager.selectedAnnotation?.arrowStyle, .tapered)
        manager.undo()
        XCTAssertEqual(manager.annotations.first?.arrowStyle, .triangle)
        manager.redo()
        XCTAssertEqual(manager.annotations.first?.arrowStyle, .tapered)
    }

    func testVideoArrowStyleDefaultsAndUndo() throws {
        let video = VideoRecording(url: URL(fileURLWithPath: "/tmp/arrows.mov"), duration: 10,
            size: CGSize(width: 200, height: 100), frameRate: 30)
        let vm = VideoEditorViewModel(video: video)
        vm.annotationArrowStyle = .triangle
        vm.addOverlayTrack(kind: .callout)
        var track = try XCTUnwrap(vm.overlayTracks.first)
        XCTAssertEqual(track.arrowStyle, .triangle)
        track.arrowStyle = .tapered
        vm.updateOverlay(track)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks.first?.arrowStyle, .triangle)
        vm.redo()
        XCTAssertEqual(vm.overlayTracks.first?.arrowStyle, .tapered)
    }

    func testGeometrySupportsShortReversedAndZeroLengthArrows() {
        for style in ArrowStyle.allCases {
            for end in [CGPoint(x: 0.2, y: 0.1), CGPoint(x: -80, y: -40), CGPoint(x: 100, y: 0)] {
                let geometry = ArrowGeometry(start: .zero, end: end, style: style, headSize: 12, strokeWidth: 3)
                let bounds = geometry.stroke.isEmpty ? geometry.fill.boundingBox : geometry.stroke.boundingBox
                XCTAssertTrue(bounds.width.isFinite)
                XCTAssertTrue(bounds.height.isFinite)
            }
            let empty = ArrowGeometry(start: .zero, end: .zero, style: style, headSize: 12, strokeWidth: 3)
            XCTAssertTrue(empty.stroke.isEmpty)
            XCTAssertTrue(empty.fill.isEmpty)
        }
    }

    func testAllStylesProduceDistinctImageAndVideoRenders() throws {
        let background = BackgroundManager.shared
        let previous = background.collections.backgroundType
        background.setBackgroundType(.none)
        defer { background.setBackgroundType(previous) }
        let image = try XCTUnwrap(TestHelpers.createTestImageFromData(width: 300, height: 100))
        var imageResults: [Data] = [], videoResults: [Data] = []
        for style in ArrowStyle.allCases {
            let annotation = Annotation(type: .arrow, startPoint: CGPoint(x: 20, y: 60),
                endPoint: CGPoint(x: 260, y: 30), color: ColorData(color: .red), strokeWidth: 4,
                arrowheadSize: 24, arrowStyle: style)
            let rendered = ImageCompositeRenderer.render(image: image, backgroundManager: background,
                annotations: [annotation], padding: 0, aspectRatio: .auto, shadowIntensity: 0)
            imageResults.append(try XCTUnwrap(rendered.tiffRepresentation))
            var track = TimelineOverlayTrack(title: "Arrow", kind: .callout)
            track.x = 0.1; track.y = 0.6; track.width = 0.8; track.height = -0.3
            track.strokeScale = 0.04; track.arrowStyle = style
            let preview = try XCTUnwrap(VideoFrameRenderer.previewImage(track, size: CGSize(width: 300, height: 100)))
            videoResults.append(try XCTUnwrap(preview.tiffRepresentation))
            let attachment = XCTAttachment(image: rendered)
            attachment.name = style.rawValue
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(Set(imageResults).count, 3)
        XCTAssertEqual(Set(videoResults).count, 3)
    }
}
