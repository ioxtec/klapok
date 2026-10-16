import AppKit
import AVFoundation
import AVKit
import SwiftUI
import XCTest
@testable import Klapok

@MainActor
final class TimelinePresentationTests: XCTestCase {
    func testLanguageDrivenSwiftUIViewRecreationPreservesPreviewAndEditingState() async {
        let vm = VideoEditorViewModel()
        let item = AVPlayerItem(asset: AVMutableComposition())
        vm.previewItem = item
        vm.addOverlayTrack(kind: .text)
        let overlays = vm.overlayTracks.map(\.id)
        let url = URL(fileURLWithPath: "/tmp/language-preview.mov")
        let player = vm.synchronizedPreviewPlayer()
        let host = NSHostingView(rootView: VideoPlayerView(videoURL: url, viewModel: vm)
            .id("pl").environment(\.locale, Locale(identifier: "pl")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.contentView = nil }
        for language in ["en", "pl", "en", "pl", "en"] {
            host.rootView = VideoPlayerView(videoURL: url, viewModel: vm)
                .id(language).environment(\.locale, Locale(identifier: language))
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(for: .milliseconds(30))
            XCTAssertTrue(vm.synchronizedPreviewPlayer() === player)
            XCTAssertTrue(player.currentItem === item)
            XCTAssertEqual(vm.overlayTracks.map(\.id), overlays)
        }
    }

    func testRecreatedPreviewViewsReusePlayerAndLateDismantleDoesNotDetachItem() {
        let vm = VideoEditorViewModel()
        let item = AVPlayerItem(asset: AVMutableComposition())
        vm.previewItem = item
        let firstView = AVPlayerView()
        firstView.player = vm.synchronizedPreviewPlayer()
        let player = firstView.player
        vm.currentTime = 3
        let replacement = AVPlayerView()
        replacement.player = vm.synchronizedPreviewPlayer()
        XCTAssertTrue(replacement.player === player)
        XCTAssertTrue(player?.currentItem === item)
        VideoPlayerView.dismantleNSView(firstView, coordinator: ())
        XCTAssertNil(firstView.player)
        XCTAssertTrue(replacement.player?.currentItem === item)
        XCTAssertEqual(vm.currentTime, 3)
        replacement.player = nil
    }

    func testPreviewItemReplacementStaysOnSamePlayer() {
        let vm = VideoEditorViewModel()
        vm.previewItem = AVPlayerItem(asset: AVMutableComposition())
        let player = vm.synchronizedPreviewPlayer()
        let replacement = AVPlayerItem(asset: AVMutableComposition())
        vm.previewItem = replacement
        XCTAssertTrue(vm.synchronizedPreviewPlayer() === player)
        XCTAssertTrue(player.currentItem === replacement)
    }

    private func recording(_ name: String = "timeline.mov") -> VideoRecording {
        VideoRecording(url: FileManager.default.temporaryDirectory.appendingPathComponent(name),
                       duration: 12, size: CGSize(width: 160, height: 100), frameRate: 15)
    }

    private func defaultName(_ number: Int) -> String {
        String(format: "Clip %ld".localized, number)
    }

    func testSplitClipsHaveSequentialNames() {
        let vm = VideoEditorViewModel(video: recording())
        vm.updateCurrentTime(to: 4)
        vm.splitAtPlayhead()
        vm.updateCurrentTime(to: 8)
        vm.splitAtPlayhead()
        XCTAssertEqual(vm.clips.map(\.name), (1...3).map(defaultName))
    }

    func testNewAnnotationsUseLongerDurationOnLongRecordings() throws {
        for (duration, expected) in [(12.0, 5.0), (60, 9), (108, 15), (600, 15)] {
            let video = VideoRecording(url: URL(fileURLWithPath: "/tmp/timeline.mov"), duration: duration,
                size: CGSize(width: 160, height: 100), frameRate: 30)
            let vm = VideoEditorViewModel(video: video)
            vm.updateCurrentTime(to: 3)
            vm.addOverlayTrack(kind: .rectangle)
            let track = try XCTUnwrap(vm.overlayTracks.first)
            XCTAssertEqual(track.start, 3, accuracy: 0.01)
            XCTAssertEqual(track.end - track.start, expected, accuracy: 0.01)
        }
    }

    func testAnnotationNearEndDoesNotExtendPastRecording() throws {
        let vm = VideoEditorViewModel(video: recording())
        vm.updateCurrentTime(to: 11.5)
        vm.addOverlayTrack()
        let track = try XCTUnwrap(vm.overlayTracks.first)
        XCTAssertEqual(track.start, 11.5, accuracy: 0.01)
        XCTAssertEqual(track.end, 12, accuracy: 0.01)
    }

    func testRenameIsUndoableAndEmptyNameRestoresAutomaticName() {
        let vm = VideoEditorViewModel(video: recording())
        let id = vm.clips[0].id
        vm.renameClip(id, to: "  Opening  ")
        XCTAssertEqual(vm.clips[0].name, "Opening")
        vm.undo()
        XCTAssertEqual(vm.clips[0].name, defaultName(1))
        vm.redo()
        XCTAssertEqual(vm.clips[0].name, "Opening")
        vm.renameClip(id, to: " \n ")
        XCTAssertEqual(vm.clips[0].name, defaultName(1))
        XCTAssertFalse(vm.clips[0].hasCustomName)
    }

    func testSplitPreservesCustomLeftNameButNamesNewRightClip() {
        let vm = VideoEditorViewModel(video: recording())
        vm.renameClip(vm.clips[0].id, to: "Opening")
        vm.updateCurrentTime(to: 6)
        vm.splitAtPlayhead()
        XCTAssertEqual(vm.clips.map(\.name), ["Opening", defaultName(2)])
        let customID = vm.clips[0].id
        vm.moveClip(customID, before: nil)
        XCTAssertEqual(vm.clips.map(\.name), [defaultName(1), "Opening"])
    }

    func testCancelledViewTaskDoesNotDropThumbnailResult() async {
        var started = false
        let frame = TimelineThumbnail(time: 1, image: NSImage(size: NSSize(width: 20, height: 20)))
        let vm = VideoEditorViewModel(video: recording(), thumbnailLoader: { _, _ in
            started = true
            try? await Task.sleep(for: .milliseconds(30))
            return [frame]
        })
        let task = Task { await vm.loadTimelineThumbnails(for: 600) }
        while !started { await Task.yield() }
        task.cancel()
        await task.value
        XCTAssertEqual(vm.timelineThumbnails, [frame])
        XCTAssertFalse(vm.isLoadingTimelineThumbnails)
    }

    func testFailedGenerationCanBeRetriedAtSameWidth() async {
        var calls = 0
        let frame = TimelineThumbnail(time: 1, image: NSImage(size: NSSize(width: 20, height: 20)))
        let vm = VideoEditorViewModel(video: recording(), thumbnailLoader: { _, _ in
            calls += 1
            return calls == 1 ? [] : [frame]
        })
        await vm.loadTimelineThumbnails(for: 600)
        await vm.loadTimelineThumbnails(for: 600)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(vm.timelineThumbnails, [frame])
    }
}
