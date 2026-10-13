import XCTest
@testable import Klapok
import AppKit

@MainActor
final class VideoEditorViewModelTests: XCTestCase {
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
}
