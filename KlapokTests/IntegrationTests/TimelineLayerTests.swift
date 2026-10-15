import AppKit
import XCTest
@testable import Klapok

@MainActor
final class TimelineLayerTests: XCTestCase {
    func testVerticalHandleDragResolvesVisualDestinationAndClampsEdges() throws {
        let order = ["front", "middle", "back"]
        XCTAssertNil(TimelineLayerOrder.destination(for: "middle", translation: 5, rowStride: 40, in: order))
        let up = try XCTUnwrap(TimelineLayerOrder.destination(for: "back", translation: -40, rowStride: 40, in: order))
        XCTAssertEqual(up.target, "middle")
        XCTAssertTrue(up.above)
        let down = try XCTUnwrap(TimelineLayerOrder.destination(for: "front", translation: 80, rowStride: 40, in: order))
        XCTAssertEqual(down.target, "back")
        XCTAssertFalse(down.above)
        let clamped = try XCTUnwrap(TimelineLayerOrder.destination(for: "back", translation: -1000, rowStride: 40, in: order))
        XCTAssertEqual(clamped.target, "front")
        XCTAssertNil(TimelineLayerOrder.destination(for: "missing", translation: 40, rowStride: 40, in: order))
    }
    func testVisualAboveMeansLaterInCompositingOrder() {
        XCTAssertEqual(TimelineLayerOrder.moving(1, relativeTo: 3, above: true, in: [1, 2, 3]), [2, 3, 1])
        XCTAssertEqual(TimelineLayerOrder.moving(3, relativeTo: 1, above: false, in: [1, 2, 3]), [3, 1, 2])
        XCTAssertEqual(TimelineLayerOrder.moving(1, relativeTo: 2, above: false, in: [1, 2, 3]), [1, 2, 3])
        XCTAssertEqual(TimelineLayerOrder.moving(2, relativeTo: 2, above: true, in: [1, 2, 3]), [1, 2, 3])
        XCTAssertEqual(TimelineLayerOrder.moving(9, relativeTo: 2, above: true, in: [1, 2, 3]), [1, 2, 3])
        XCTAssertEqual(TimelineLayerOrder.moving(1, relativeTo: 9, above: true, in: [1, 2, 3]), [1, 2, 3])
    }

    func testEveryMovePreservesAllLayersWithoutDuplicates() {
        for source in 0..<5 {
            for target in 0..<5 where source != target {
                for above in [false, true] {
                    let result = TimelineLayerOrder.moving(source, relativeTo: target, above: above, in: Array(0..<5))
                    XCTAssertEqual(Set(result), Set(0..<5))
                    XCTAssertEqual(result.count, 5)
                    XCTAssertEqual(result.firstIndex(of: source)!, result.firstIndex(of: target)! + (above ? 1 : -1))
                }
            }
        }
    }

    func testReorderingPreservesStylesTimingSelectionAndIsUndoable() throws {
        let video = VideoRecording(url: URL(fileURLWithPath: "/tmp/layers.mov"), duration: 20,
            size: CGSize(width: 160, height: 100), frameRate: 30)
        let vm = VideoEditorViewModel(video: video)
        vm.addOverlayTrack(kind: .text)
        let text = try XCTUnwrap(vm.overlayTracks.first)
        vm.addOverlayTrack(kind: .rectangle)
        let rectangle = try XCTUnwrap(vm.overlayTracks.last)
        vm.selectedOverlayID = text.id
        vm.exportedURL = URL(fileURLWithPath: "/tmp/layers-export.mp4")
        vm.moveOverlay(text.id, relativeTo: rectangle.id, above: true)
        XCTAssertEqual(vm.overlayTracks, [rectangle, text])
        XCTAssertEqual(vm.selectedOverlayID, text.id)
        XCTAssertNil(vm.exportedURL)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks, [text, rectangle])
        vm.redo()
        XCTAssertEqual(vm.overlayTracks, [rectangle, text])
        vm.moveOverlay(text.id, relativeTo: rectangle.id, above: false)
        XCTAssertEqual(vm.overlayTracks, [text, rectangle])
    }
}
