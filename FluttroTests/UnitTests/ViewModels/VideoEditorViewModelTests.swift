//
//  VideoEditorViewModelTests.swift
//  FluttroTests
//

import XCTest
@testable import Fluttro

#if os(macOS)
import AppKit

@MainActor
final class VideoEditorViewModelTests: XCTestCase {
    private func makeRecording(duration: TimeInterval = 100) -> VideoRecording {
        VideoRecording(
            url: URL(fileURLWithPath: "/tmp/test-video.mov"),
            duration: duration,
            size: CGSize(width: 1920, height: 1080),
            frameRate: 30
        )
    }

    func testInitializationWithVideoSetsTrimEnd() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 42))

        XCTAssertEqual(viewModel.trimStartTime, 0)
        XCTAssertEqual(viewModel.trimEndTime, 42)
        XCTAssertEqual(viewModel.trimmedDuration, 42)
        XCTAssertEqual(viewModel.editedDuration, 42)
    }

    func testLoadVideoResetsEditingState() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))
        viewModel.updateTrimStart(from: 0.25)
        viewModel.updateCutSelection(startPercentage: 0.4, endPercentage: 0.5)
        viewModel.commitCutSelection()

        viewModel.loadVideo(makeRecording(duration: 12))

        XCTAssertEqual(viewModel.trimStartTime, 0)
        XCTAssertEqual(viewModel.trimEndTime, 12)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertTrue(viewModel.cutSegments.isEmpty)
        XCTAssertNil(viewModel.timelineCutSelection)
        XCTAssertTrue(viewModel.timelineThumbnails.isEmpty)
    }

    func testTrimPercentagesAndDuration() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateTrimStart(from: 0.2)
        viewModel.updateTrimEnd(from: 0.8)

        XCTAssertEqual(viewModel.trimStartTime, 20, accuracy: 0.001)
        XCTAssertEqual(viewModel.trimEndTime, 80, accuracy: 0.001)
        XCTAssertEqual(viewModel.trimmedDuration, 60, accuracy: 0.001)
        XCTAssertEqual(viewModel.trimStartPercentage, 0.2, accuracy: 0.001)
        XCTAssertEqual(viewModel.trimEndPercentage, 0.8, accuracy: 0.001)
    }

    func testInvalidTrimUpdatesAreIgnored() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateTrimEnd(from: 0.001)
        viewModel.updateTrimStart(from: 1.0)

        XCTAssertEqual(viewModel.trimStartTime, 0)
        XCTAssertEqual(viewModel.trimEndTime, 100)
    }

    func testCurrentTimeIsClampedToTrimRange() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))
        viewModel.updateTrimStart(from: 0.2)
        viewModel.updateTrimEnd(from: 0.8)

        viewModel.updateCurrentTime(from: 0.1)
        XCTAssertEqual(viewModel.currentTime, 20, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentTimePercentage, 0.2, accuracy: 0.001)

        viewModel.updateCurrentTime(from: 0.9)
        XCTAssertEqual(viewModel.currentTime, 80, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentTimePercentage, 0.8, accuracy: 0.001)
    }

    func testCutSelectionNormalizesDirectionAndCommits() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateCutSelection(startPercentage: 0.4, endPercentage: 0.2)
        viewModel.commitCutSelection()

        XCTAssertEqual(viewModel.cutSegments.count, 1)
        XCTAssertEqual(viewModel.cutSegments[0].startTime, 20, accuracy: 0.001)
        XCTAssertEqual(viewModel.cutSegments[0].endTime, 40, accuracy: 0.001)
        XCTAssertEqual(viewModel.editedDuration, 80, accuracy: 0.001)
        XCTAssertNil(viewModel.timelineCutSelection)
    }

    func testTinyCutSelectionIsDiscarded() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateCutSelection(startPercentage: 0.2, endPercentage: 0.2001)

        XCTAssertNil(viewModel.timelineCutSelection)
        XCTAssertTrue(viewModel.cutSegments.isEmpty)
    }

    func testOverlappingCutSelectionsAreMerged() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateCutSelection(startPercentage: 0.2, endPercentage: 0.4)
        viewModel.commitCutSelection()
        viewModel.updateCutSelection(startPercentage: 0.35, endPercentage: 0.5)
        viewModel.commitCutSelection()

        XCTAssertEqual(viewModel.cutSegments.count, 1)
        XCTAssertEqual(viewModel.cutSegments[0].startTime, 20, accuracy: 0.001)
        XCTAssertEqual(viewModel.cutSegments[0].endTime, 50, accuracy: 0.001)
        XCTAssertEqual(viewModel.editedDuration, 70, accuracy: 0.001)
    }

    func testCutCoveringEntireTrimRangeIsRejected() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))

        viewModel.updateCutSelection(startPercentage: 0, endPercentage: 1)
        viewModel.commitCutSelection()

        XCTAssertTrue(viewModel.cutSegments.isEmpty)
        XCTAssertNil(viewModel.timelineCutSelection)
        XCTAssertEqual(viewModel.editedDuration, 100, accuracy: 0.001)
    }

    func testClearCutsRemovesSelectionAndCommittedCuts() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))
        viewModel.updateCutSelection(startPercentage: 0.2, endPercentage: 0.3)
        viewModel.commitCutSelection()
        viewModel.updateCutSelection(startPercentage: 0.4, endPercentage: 0.5)

        viewModel.clearCuts()

        XCTAssertTrue(viewModel.cutSegments.isEmpty)
        XCTAssertNil(viewModel.timelineCutSelection)
        XCTAssertEqual(viewModel.editedDuration, 100, accuracy: 0.001)
    }

    func testRemoveCutRestoresEditedDuration() {
        let viewModel = VideoEditorViewModel(video: makeRecording(duration: 100))
        viewModel.updateCutSelection(startPercentage: 0.2, endPercentage: 0.3)
        viewModel.commitCutSelection()
        let cut = try! XCTUnwrap(viewModel.cutSegments.first)

        viewModel.removeCut(cut)

        XCTAssertTrue(viewModel.cutSegments.isEmpty)
        XCTAssertEqual(viewModel.editedDuration, 100, accuracy: 0.001)
    }
}

#endif
