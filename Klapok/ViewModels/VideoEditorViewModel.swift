//
//  VideoEditorViewModel.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit
import AVFoundation

struct TimelineThumbnail: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let image: NSImage
}

struct TimelineTimeRange: Equatable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval {
        max(0, end - start)
    }

    func contains(_ time: TimeInterval) -> Bool {
        time >= start && time <= end
    }
}

struct VideoTimelineClip: Identifiable, Equatable {
    let id: UUID
    var name: String
    var sourceRanges: [TimelineTimeRange]

    init(id: UUID = UUID(), name: String, sourceRanges: [TimelineTimeRange]) {
        self.id = id
        self.name = name
        self.sourceRanges = sourceRanges
    }

    var duration: TimeInterval {
        sourceRanges.reduce(0) { $0 + $1.duration }
    }

    func sourceTime(forLocalOffset offset: TimeInterval) -> TimeInterval? {
        guard !sourceRanges.isEmpty else { return nil }

        var remaining = max(0, offset)
        for range in sourceRanges {
            if remaining <= range.duration {
                return min(range.end, range.start + remaining)
            }
            remaining -= range.duration
        }

        return sourceRanges.last?.end
    }
}

enum TimelineOverlayTrackKind: String, Equatable, CaseIterable {
    case text
    case callout
}

struct TimelineOverlayTrack: Identifiable, Equatable {
    let id: UUID
    var title: String
    var kind: TimelineOverlayTrackKind

    init(id: UUID = UUID(), title: String, kind: TimelineOverlayTrackKind) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}

private struct VideoTimelineHistoryState: Equatable {
    var clips: [VideoTimelineClip]
    var selectedClipIDs: Set<UUID>
    var overlayTracks: [TimelineOverlayTrack]
    var currentTime: TimeInterval
}

@MainActor
final class VideoEditorViewModel: ObservableObject {
    @Published var video: VideoRecording?
    @Published var currentTime: TimeInterval = 0
    @Published var isExporting: Bool = false
    @Published var timelineThumbnails: [TimelineThumbnail] = []
    @Published var isLoadingTimelineThumbnails: Bool = false
    @Published var clips: [VideoTimelineClip] = []
    @Published var selectedClipIDs: Set<UUID> = []
    @Published var overlayTracks: [TimelineOverlayTrack] = []
    @Published var zoomScale: Double = 1.0
    @Published var timelineSidebarWidth: CGFloat = 178
    @Published var draggedTimelineClipID: UUID?
    @Published var timelineSidebarResizeAnchor: CGFloat = 178

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var thumbnailRequestID = UUID()
    private var timelineThumbnailURL: URL?
    private var undoStack: [VideoTimelineHistoryState] = []
    private var redoStack: [VideoTimelineHistoryState] = []
    private var isRestoringHistory = false

    private let minimumClipDuration: TimeInterval = 0.08
    private let maximumHistoryDepth = 80

    init(video: VideoRecording? = nil) {
        if let video {
            loadVideo(video)
        } else {
            self.video = nil
        }
    }

    var sourceDuration: TimeInterval {
        video?.duration ?? 0
    }

    var editedDuration: TimeInterval {
        clips.reduce(0) { $0 + $1.duration }
    }

    var currentTimePercentage: Double {
        guard editedDuration > 0 else { return 0 }
        return clampedEditedTime(currentTime) / editedDuration
    }

    var selectedClips: [VideoTimelineClip] {
        clips.filter { selectedClipIDs.contains($0.id) }
    }

    var selectedDuration: TimeInterval {
        selectedClips.reduce(0) { $0 + $1.duration }
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var canSplit: Bool {
        splitCandidate != nil
    }

    var canMerge: Bool {
        contiguousSelectionIndices != nil
    }

    var canRemove: Bool {
        !selectedClipIDs.isEmpty && clips.count > selectedClipIDs.count
    }

    var canResetTimeline: Bool {
        guard let video else { return false }
        return clips != [makeInitialClip(for: video)] || !overlayTracks.isEmpty
    }

    var canZoomIn: Bool {
        zoomScale < 3.5
    }

    var canZoomOut: Bool {
        zoomScale > 0.55
    }

    var activeTimelineRange: TimelineTimeRange? {
        let indices = clips.indices.filter { selectedClipIDs.contains(clips[$0].id) }
        if !indices.isEmpty {
            guard
                let firstIndex = indices.min(),
                let lastIndex = indices.max()
            else {
                return nil
            }

            let start = timelineRange(for: clips[firstIndex]).start
            let end = timelineRange(for: clips[lastIndex]).end
            return TimelineTimeRange(start: start, end: end)
        }

        return clip(atEditedTime: currentTime).map { timelineRange(for: $0) }
    }

    func loadVideo(_ video: VideoRecording) {
        let clip = makeInitialClip(for: video)
        self.video = video
        self.currentTime = 0
        self.timelineThumbnails = []
        self.isLoadingTimelineThumbnails = false
        self.timelineThumbnailURL = nil
        self.clips = [clip]
        self.selectedClipIDs = [clip.id]
        self.overlayTracks = []
        self.zoomScale = 1
        self.timelineSidebarWidth = 178
        self.draggedTimelineClipID = nil
        self.timelineSidebarResizeAnchor = 178
        self.undoStack.removeAll()
        self.redoStack.removeAll()
    }

    func updateCurrentTime(from percentage: Double) {
        updateCurrentTime(to: editedDuration * max(0, min(1, percentage)))
    }

    func updateCurrentTime(to editedTime: TimeInterval, seek: Bool = true) {
        currentTime = clampedEditedTime(editedTime)
        if seek {
            seekToCurrentTime()
        }
    }

    func selectClip(_ clipID: UUID, extendSelection: Bool) {
        guard clips.contains(where: { $0.id == clipID }) else { return }

        if extendSelection {
            if selectedClipIDs.contains(clipID) {
                selectedClipIDs.remove(clipID)
            } else {
                selectedClipIDs.insert(clipID)
            }
        } else {
            selectedClipIDs = [clipID]
        }
    }

    func splitAtPlayhead() {
        guard let candidate = splitCandidate else { return }

        let clip = clips[candidate.index]
        let split = splitSourceRanges(clip.sourceRanges, at: candidate.localOffset)
        guard !split.left.isEmpty, !split.right.isEmpty else { return }

        recordUndoSnapshot()

        let leftClip = VideoTimelineClip(name: clip.name, sourceRanges: split.left)
        let rightClip = VideoTimelineClip(name: clip.name, sourceRanges: split.right)

        clips.replaceSubrange(candidate.index...candidate.index, with: [leftClip, rightClip])
        selectedClipIDs = [rightClip.id]
        currentTime = timelineRange(for: rightClip).start
    }

    func mergeSelectedClips() {
        guard let indices = contiguousSelectionIndices else { return }
        let mergedRanges = indices.flatMap { clips[$0].sourceRanges }
        guard let firstIndex = indices.first else { return }

        recordUndoSnapshot()

        let mergedClip = VideoTimelineClip(
            name: clips[firstIndex].name,
            sourceRanges: mergedRanges
        )

        clips.replaceSubrange(firstIndex...indices.last!, with: [mergedClip])
        selectedClipIDs = [mergedClip.id]
        currentTime = timelineRange(for: mergedClip).start
    }

    func removeSelectedClips() {
        guard canRemove else { return }

        recordUndoSnapshot()

        let remaining = clips.filter { !selectedClipIDs.contains($0.id) }
        clips = remaining
        if let replacement = clip(atEditedTime: currentTime) ?? remaining.first {
            selectedClipIDs = [replacement.id]
            currentTime = min(currentTime, timelineRange(for: replacement).end)
        } else {
            selectedClipIDs.removeAll()
            currentTime = 0
        }
        clampCurrentTimeToEditedDuration(seek: true)
    }

    func resetTimeline() {
        guard let video else { return }
        guard canResetTimeline else { return }

        recordUndoSnapshot()

        let clip = makeInitialClip(for: video)
        clips = [clip]
        overlayTracks = []
        selectedClipIDs = [clip.id]
        currentTime = 0
    }

    func addOverlayTrack() {
        recordUndoSnapshot()

        let title = "Layer \(overlayTracks.count + 1)"
        overlayTracks.append(
            TimelineOverlayTrack(
                title: title,
                kind: overlayTracks.isEmpty ? .text : .callout
            )
        )
    }

    func moveClip(_ clipID: UUID, before destinationID: UUID?) {
        guard clips.contains(where: { $0.id == clipID }) else { return }

        if selectedClipIDs.contains(clipID), selectedClipIDs.count > 1 {
            moveSelectedClips(before: destinationID)
            return
        }

        selectedClipIDs = [clipID]
        moveSelectedClips(before: destinationID)
    }

    func moveSelectedClips(before destinationID: UUID?) {
        let movingIDs = clips.map(\.id).filter { selectedClipIDs.contains($0) }
        guard !movingIDs.isEmpty else { return }

        if let destinationID, movingIDs.contains(destinationID) {
            return
        }

        let movingClips = clips.filter { movingIDs.contains($0.id) }
        var remainingClips = clips.filter { !movingIDs.contains($0.id) }
        let insertionIndex: Int
        if let destinationID, let index = remainingClips.firstIndex(where: { $0.id == destinationID }) {
            insertionIndex = index
        } else {
            insertionIndex = remainingClips.count
        }

        remainingClips.insert(contentsOf: movingClips, at: insertionIndex)
        guard remainingClips != clips else { return }

        recordUndoSnapshot()
        clips = remainingClips
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }

        let currentState = historyState
        isRestoringHistory = true
        redoStack.append(currentState)
        restore(historyState: previousState)
        isRestoringHistory = false
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }

        let currentState = historyState
        isRestoringHistory = true
        undoStack.append(currentState)
        restore(historyState: nextState)
        isRestoringHistory = false
    }

    func zoomIn() {
        zoomScale = min(3.5, zoomScale * 1.18)
    }

    func zoomOut() {
        zoomScale = max(0.55, zoomScale / 1.18)
    }

    func updateZoomScale(_ value: Double) {
        zoomScale = max(0.55, min(3.5, value))
    }

    func loadTimelineThumbnails(for width: CGFloat) async {
        guard let video, width > 0 else { return }

        let targetCount = TimelineThumbnailGenerator.targetCount(for: width)
        if timelineThumbnailURL == video.url, timelineThumbnails.count == targetCount {
            return
        }

        let requestID = UUID()
        thumbnailRequestID = requestID
        isLoadingTimelineThumbnails = true
        defer {
            if thumbnailRequestID == requestID {
                isLoadingTimelineThumbnails = false
            }
        }

        let thumbnails = await TimelineThumbnailGenerator.generate(for: video, width: width)
        guard thumbnailRequestID == requestID else { return }

        timelineThumbnails = thumbnails
        timelineThumbnailURL = video.url
    }

    func timelineRange(for clip: VideoTimelineClip) -> TimelineTimeRange {
        var cursor: TimeInterval = 0
        for existingClip in clips {
            let end = cursor + existingClip.duration
            if existingClip.id == clip.id {
                return TimelineTimeRange(start: cursor, end: end)
            }
            cursor = end
        }

        return TimelineTimeRange(start: 0, end: 0)
    }

    func clipThumbnails(for clip: VideoTimelineClip, targetCount: Int) -> [NSImage] {
        guard !timelineThumbnails.isEmpty else { return [] }
        let count = max(1, targetCount)

        return (0..<count).compactMap { index in
            let progress = count == 1 ? 0.5 : Double(index) / Double(count - 1)
            let localOffset = clip.duration * progress
            guard let sourceTime = clip.sourceTime(forLocalOffset: localOffset) else { return nil }
            return nearestThumbnailImage(to: sourceTime)
        }
    }

    func audioLevels(for clip: VideoTimelineClip, sampleCount: Int) -> [CGFloat] {
        let count = max(12, sampleCount)
        guard clip.duration > 0 else { return Array(repeating: 0.2, count: count) }

        return (0..<count).map { index in
            let progress = Double(index) / Double(max(1, count - 1))
            let localOffset = clip.duration * progress
            let sourceTime = clip.sourceTime(forLocalOffset: localOffset) ?? localOffset
            let primary = abs(sin(sourceTime * 4.1))
            let secondary = abs(cos(sourceTime * 1.7 + Double(index) * 0.11))
            let envelope = 0.18 + primary * 0.45 + secondary * 0.24
            return CGFloat(min(1, envelope))
        }
    }

    func setPlayer(_ player: AVPlayer) {
        if self.player === player {
            return
        }

        if let timeObserver {
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        self.player = player
        setupTimeObserver()
    }

    func exportTrimmedVideo(settings: VideoExportSettings) async {
        guard let video else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let outputURL = try await VideoExportService.exportEditedVideo(
                video: video,
                ranges: editedSourceRanges(),
                settings: settings
            )

            Logger.s("VideoEditorViewModel: Edited video exported to \(outputURL.path)")
            NSWorkspace.shared.open(outputURL)
        } catch {
            Logger.e("VideoEditorViewModel: Export error: \(error)")
        }
    }

    func exportAsGIF(settings: GIFExportSettings) async {
        guard let video else { return }

        isExporting = true
        defer { isExporting = false }

        do {
            let outputURL = try await VideoExportService.exportGIF(
                video: video,
                ranges: editedSourceRanges(),
                settings: settings
            )

            Logger.s("VideoEditorViewModel: GIF exported to \(outputURL.path)")
            NSWorkspace.shared.open(outputURL)
        } catch {
            Logger.e("VideoEditorViewModel: GIF export error: \(error)")
        }
    }

    func shareVideo() {
        guard let video else { return }

        let picker = NSSharingServicePicker(items: [video.url])
        if let window = NSApplication.shared.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    func openInFinder() {
        guard let video else { return }
        NSWorkspace.shared.selectFile(
            video.url.path,
            inFileViewerRootedAtPath: video.url.deletingLastPathComponent().path
        )
    }

    func deleteVideo() {
        guard let video else { return }

        let alert = NSAlert()
        alert.messageText = "Delete Video".localized
        alert.informativeText = "Are you sure you want to delete this video? This action cannot be undone.".localized
        alert.addButton(withTitle: "Delete".localized)
        alert.addButton(withTitle: "Cancel".localized)
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.removeItem(at: video.url)
                self.video = nil
                self.clips = []
                self.selectedClipIDs.removeAll()
                self.overlayTracks = []
                self.currentTime = 0
                self.draggedTimelineClipID = nil
            } catch {
                Logger.e("VideoEditorViewModel: Error deleting video: \(error)")
            }
        }
    }

    deinit {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }

    private func makeInitialClip(for video: VideoRecording) -> VideoTimelineClip {
        VideoTimelineClip(
            name: "Main Clip".localized,
            sourceRanges: [TimelineTimeRange(start: 0, end: video.duration)]
        )
    }

    private func seekToCurrentTime() {
        guard let player, let sourceTime = sourceTime(forEditedTime: currentTime) else { return }

        let time = CMTime(seconds: sourceTime, preferredTimescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setupTimeObserver() {
        guard let player else { return }

        let interval = CMTime(seconds: 0.1, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            Task { @MainActor in
                self.syncCurrentTimeFromPlayer(seconds)
            }
        }
    }

    private func syncCurrentTimeFromPlayer(_ sourceTime: TimeInterval) {
        currentTime = clampedEditedTime(editedTime(forSourceTime: sourceTime))
    }

    private func sourceTime(forEditedTime editedTime: TimeInterval) -> TimeInterval? {
        let clamped = clampedEditedTime(editedTime)
        var cursor: TimeInterval = 0

        for clip in clips {
            let nextCursor = cursor + clip.duration
            if clamped <= nextCursor || clip.id == clips.last?.id {
                let localOffset = max(0, min(clip.duration, clamped - cursor))
                return clip.sourceTime(forLocalOffset: localOffset)
            }
            cursor = nextCursor
        }

        return clips.last?.sourceRanges.last?.end
    }

    private func editedTime(forSourceTime sourceTime: TimeInterval) -> TimeInterval {
        var cursor: TimeInterval = 0

        for clip in clips {
            for range in clip.sourceRanges {
                if sourceTime < range.start {
                    return cursor
                }
                if range.contains(sourceTime) {
                    return cursor + max(0, min(range.duration, sourceTime - range.start))
                }
                cursor += range.duration
            }
        }

        return min(sourceTime, editedDuration)
    }

    private func editedSourceRanges() -> [TimelineTimeRange] {
        clips
            .flatMap(\.sourceRanges)
            .filter { $0.duration >= minimumClipDuration }
    }

    private var splitCandidate: (index: Int, localOffset: TimeInterval)? {
        guard !clips.isEmpty else { return nil }

        let targetClip = selectedClips.first(where: { timelineRange(for: $0).contains(currentTime) })
            ?? clip(atEditedTime: currentTime)

        guard
            let targetClip,
            let index = clips.firstIndex(where: { $0.id == targetClip.id })
        else {
            return nil
        }

        let range = timelineRange(for: targetClip)
        let localOffset = currentTime - range.start
        guard
            localOffset > minimumClipDuration,
            targetClip.duration - localOffset > minimumClipDuration
        else {
            return nil
        }

        return (index, localOffset)
    }

    private var contiguousSelectionIndices: [Int]? {
        let indices = clips.indices.filter { selectedClipIDs.contains(clips[$0].id) }.sorted()
        guard indices.count >= 2 else { return nil }

        for pair in zip(indices, indices.dropFirst()) {
            if pair.1 != pair.0 + 1 {
                return nil
            }
        }

        return indices
    }

    private func clip(atEditedTime editedTime: TimeInterval) -> VideoTimelineClip? {
        var cursor: TimeInterval = 0

        for clip in clips {
            let nextCursor = cursor + clip.duration
            if editedTime <= nextCursor || clip.id == clips.last?.id {
                return clip
            }
            cursor = nextCursor
        }

        return clips.last
    }

    private func splitSourceRanges(
        _ ranges: [TimelineTimeRange],
        at offset: TimeInterval
    ) -> (left: [TimelineTimeRange], right: [TimelineTimeRange]) {
        var remaining = max(0, offset)
        var left: [TimelineTimeRange] = []
        var right: [TimelineTimeRange] = []

        for range in ranges {
            if remaining <= 0 {
                right.append(range)
                continue
            }

            if remaining >= range.duration {
                left.append(range)
                remaining -= range.duration
                continue
            }

            let splitPoint = range.start + remaining
            let leftRange = TimelineTimeRange(start: range.start, end: splitPoint)
            let rightRange = TimelineTimeRange(start: splitPoint, end: range.end)

            if leftRange.duration >= minimumClipDuration {
                left.append(leftRange)
            }
            if rightRange.duration >= minimumClipDuration {
                right.append(rightRange)
            }

            remaining = 0
        }

        return (left, right)
    }

    private func nearestThumbnailImage(to time: TimeInterval) -> NSImage? {
        timelineThumbnails.min(by: { abs($0.time - time) < abs($1.time - time) })?.image
    }

    private func clampedEditedTime(_ time: TimeInterval) -> TimeInterval {
        max(0, min(editedDuration, time))
    }

    private func clampCurrentTimeToEditedDuration(seek: Bool) {
        let clamped = clampedEditedTime(currentTime)
        guard clamped != currentTime else { return }
        currentTime = clamped
        if seek {
            seekToCurrentTime()
        }
    }

    private var historyState: VideoTimelineHistoryState {
        VideoTimelineHistoryState(
            clips: clips,
            selectedClipIDs: selectedClipIDs,
            overlayTracks: overlayTracks,
            currentTime: currentTime
        )
    }

    private func restore(historyState: VideoTimelineHistoryState) {
        clips = historyState.clips
        selectedClipIDs = historyState.selectedClipIDs
        overlayTracks = historyState.overlayTracks
        currentTime = historyState.currentTime
        clampCurrentTimeToEditedDuration(seek: true)
    }

    private func recordUndoSnapshot() {
        guard !isRestoringHistory else { return }

        let state = historyState
        guard undoStack.last != state else { return }

        undoStack.append(state)
        if undoStack.count > maximumHistoryDepth {
            undoStack.removeFirst(undoStack.count - maximumHistoryDepth)
        }
        redoStack.removeAll()
    }
}

#endif
