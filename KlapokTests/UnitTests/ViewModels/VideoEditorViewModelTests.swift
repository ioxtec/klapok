import XCTest
@testable import Klapok
import AppKit

@MainActor
final class VideoEditorViewModelTests: XCTestCase {
    func testClipboardContainsExportedFileURLNotSourceOrPlainText() throws {
        let vm = model()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        XCTAssertFalse(vm.copyExportToClipboard(pasteboard: pasteboard))
        vm.exportedURL = URL(fileURLWithPath: #filePath)
        XCTAssertTrue(vm.copyExportToClipboard(pasteboard: pasteboard))
        let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(files, [vm.exportedURL!])
        XCTAssertTrue(vm.copiedExport)
        vm.exportedURL = nil
        XCTAssertFalse(vm.copiedExport)
    }
    func testDirectionalEndpointsKeepOppositeEndFixed() {
        var track = TimelineOverlayTrack(title: "Arrow", kind: .callout)
        track.x = 0.2; track.y = 0.3; track.width = 0.4; track.height = -0.2
        track.moveEndpoint(start: false, to: CGPoint(x: 0.1, y: 0.8))
        XCTAssertEqual(track.x, 0.2); XCTAssertEqual(track.y, 0.3)
        XCTAssertEqual(track.width, -0.1, accuracy: 0.001)
        track.moveEndpoint(start: true, to: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(track.x + track.width, 0.1, accuracy: 0.001)
        XCTAssertEqual(track.y + track.height, 0.8, accuracy: 0.001)
    }
    private func model() -> VideoEditorViewModel {
        VideoEditorViewModel(video: VideoRecording(url: URL(fileURLWithPath: "/tmp/test-video.mov"),
            duration: 10, size: CGSize(width: 1920, height: 1080), frameRate: 30))
    }

    func testSplitDeleteUndoRedoPreservesSourceRanges() {
        let vm = model()
        XCTAssertFalse(vm.canResetTimeline)
        vm.updateCurrentTime(to: 4); vm.splitAtPlayhead()
        XCTAssertEqual(vm.clips.count, 2)
        XCTAssertEqual(vm.clips[1].sourceRanges, [TimelineTimeRange(start: 4, end: 10)])
        vm.removeSelectedClips(); XCTAssertEqual(vm.editedDuration, 4)
        vm.undo(); XCTAssertEqual(vm.editedDuration, 10)
        vm.redo(); XCTAssertEqual(vm.editedDuration, 4)
    }

    func testReorderAndMergeKeepsEditedSourceOrder() {
        let vm = model()
        vm.updateCurrentTime(to: 4); vm.splitAtPlayhead()
        let first = vm.clips[0].id, second = vm.clips[1].id
        vm.moveClip(second, before: first)
        XCTAssertEqual(vm.clips.first?.sourceRanges.first?.start, 4)
        vm.selectClip(first, extendSelection: true); vm.mergeSelectedClips()
        XCTAssertEqual(vm.clips.count, 1)
        XCTAssertEqual(vm.clips[0].sourceRanges, [TimelineTimeRange(start: 4, end: 10), TimelineTimeRange(start: 0, end: 4)])
    }

    func testTrimMovesAnnotationsToNewTimelineAndUndoRestores() {
        let vm = model()
        vm.updateCurrentTime(to: 3); vm.addOverlayTrack()
        vm.updateCurrentTime(to: 2); vm.keepAfterPlayhead()
        XCTAssertEqual(vm.editedDuration, 8)
        XCTAssertEqual(vm.overlayTracks[0].start, 1)
        XCTAssertEqual(vm.overlayTracks[0].end, 6)
        vm.undo(); XCTAssertEqual(vm.overlayTracks[0].start, 3)
        XCTAssertEqual(vm.editedDuration, 10)
    }

    func testCropAndAnnotationHistory() {
        let vm = model()
        vm.applyCrop(CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.5)); vm.addOverlayTrack()
        var track = vm.overlayTracks[0]; track.text = "Important"; track.kind = .callout
        vm.updateOverlay(track); XCTAssertEqual(vm.overlayTracks[0].kind, .callout)
        vm.undo(); XCTAssertEqual(vm.overlayTracks[0].kind, .text)
        vm.undo(); XCTAssertTrue(vm.overlayTracks.isEmpty)
        vm.undo(); XCTAssertEqual(vm.cropRect, QuickEditGeometry.fullFrame)
    }

    func testTimeIsClampedToEditedDurationAndLastClipCannotBeRemoved() {
        let vm = model()
        vm.updateCurrentTime(to: 2); vm.keepBeforePlayhead(); vm.updateCurrentTime(to: 100)
        XCTAssertEqual(vm.currentTime, 2); XCTAssertFalse(vm.canRemove)
        vm.removeSelectedClips(); XCTAssertEqual(vm.editedDuration, 2)
    }

    func testNoAudioDoesNotInventWaveform() {
        let vm = model()
        XCTAssertEqual(vm.audioLevels(for: vm.clips[0], sampleCount: 12), Array(repeating: 0, count: 12))
    }

    func testLayerTimingGestureIsOneUndoStep() {
        let vm = model()
        vm.addOverlayTrack(kind: .rectangle)
        let id = vm.overlayTracks[0].id
        vm.beginOverlayGesture(id)
        vm.setOverlayTiming(id, start: 2, end: 7, recordUndo: false)
        vm.setOverlayTiming(id, start: 3, end: 8, recordUndo: false)
        XCTAssertEqual(vm.overlayTracks[0].start, 3)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks[0].start, 0)
        XCTAssertEqual(vm.overlayTracks[0].end, 5)
        vm.redo()
        XCTAssertEqual(vm.overlayTracks[0].end, 8)
    }

    func testAllAnnotationKindsCanBeAddedSelectedAndRemoved() {
        let vm = model()
        for kind in TimelineOverlayTrackKind.allCases { vm.addOverlayTrack(kind: kind) }
        XCTAssertEqual(vm.overlayTracks.count, 6)
        XCTAssertEqual(vm.overlayTracks.map(\.kind), TimelineOverlayTrackKind.allCases)
        vm.removeTimelineSelection()
        XCTAssertEqual(vm.overlayTracks.count, 5)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks.count, 6)
        XCTAssertEqual(vm.selectedOverlayID, vm.overlayTracks.last?.id)
    }

    func testRemovingVideoClipsClampsLayerEndAndUndoRestoresIt() {
        let vm = model()
        vm.addOverlayTrack()
        let layerID = vm.overlayTracks[0].id
        vm.setOverlayTiming(layerID, start: 0, end: 9)
        vm.updateCurrentTime(to: 4); vm.splitAtPlayhead(); vm.removeSelectedClips()
        XCTAssertEqual(vm.editedDuration, 4)
        XCTAssertEqual(vm.overlayTracks[0].end, 4)
        vm.undo()
        XCTAssertEqual(vm.overlayTracks[0].end, 9)
    }

    func testPreviewBackgroundSelectsVideoAndEndsTextEditing() {
        let vm = model()
        vm.addOverlayTrack()
        let id = vm.overlayTracks[0].id
        vm.editOverlay(id)
        XCTAssertEqual(vm.editingOverlayID, id)
        vm.selectVideoAtPlayhead()
        XCTAssertNil(vm.editingOverlayID)
        XCTAssertNil(vm.selectedOverlayID)
        XCTAssertEqual(vm.selectedClipIDs, [vm.clips[0].id])
    }

    func testSelectingHiddenAnnotationSeeksToItsRange() {
        let vm = model()
        vm.updateCurrentTime(to: 4)
        vm.addOverlayTrack(kind: .callout)
        let id = vm.overlayTracks[0].id
        vm.updateCurrentTime(to: 0)
        vm.selectOverlay(id)
        XCTAssertEqual(vm.currentTime, 4)
        XCTAssertEqual(vm.selectedOverlayID, id)
        XCTAssertTrue(vm.selectedClipIDs.isEmpty)
    }
}
