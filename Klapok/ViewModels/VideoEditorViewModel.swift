//
//  VideoEditorViewModel.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit
import AVFoundation
import Combine

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
    var hasCustomName: Bool
    var sourceRanges: [TimelineTimeRange]

    init(id: UUID = UUID(), name: String, sourceRanges: [TimelineTimeRange], hasCustomName: Bool = false) {
        self.id = id
        self.name = name
        self.hasCustomName = hasCustomName
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
    case highlight
    case rectangle
    case circle
    case line

    var displayName: String {
        switch self {
        case .text: return "Text".localized
        case .callout: return "Arrow".localized
        case .highlight: return "Highlight".localized
        case .rectangle: return "Rectangle".localized
        case .circle: return "Circle".localized
        case .line: return "Line".localized
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .callout: return "arrow.up.right"
        case .highlight: return "highlighter"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        }
    }

    var annotationType: AnnotationType {
        switch self {
        case .text: return .text
        case .callout: return .arrow
        case .highlight: return .highlight
        case .rectangle: return .rectangle
        case .circle: return .circle
        case .line: return .line
        }
    }
}

struct TimelineOverlayTrack: Identifiable, Equatable {
    let id: UUID
    var title: String
    var kind: TimelineOverlayTrackKind
    var text = "Note"
    var start: TimeInterval = 0
    var end: TimeInterval = 5
    var x: Double = 0.15
    var y: Double = 0.15
    var width: Double = 0.35
    var height: Double = 0.18
    var color: ColorData = ColorData(color: .red)
    var fontScale: Double = 0.035
    var strokeScale: Double = 0.004
    var fillOpacity: Double = 0.3
    var fontWeight: FontWeight = .semibold
    var arrowStyle: ArrowStyle = .open

    mutating func moveEndpoint(start: Bool, to point: CGPoint) {
        let point = CGPoint(x: max(0, min(0.95, point.x)), y: max(0, min(0.95, point.y)))
        if start {
            let end = CGPoint(x: x + width, y: y + height)
            x = point.x; y = point.y
            width = end.x - x; height = end.y - y
        } else {
            width = point.x - x; height = point.y - y
        }
    }

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
    var cropRect: CGRect
    var selectedOverlayID: UUID?
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
    @Published var cropRect = QuickEditGeometry.fullFrame
    @Published var previewItem: AVPlayerItem?
    @Published var errorMessage: String?
    @Published var exportedURL: URL? { didSet { copiedExport = false } }
    @Published var copiedExport = false
    @Published var isPreparingPreview = false
    @Published var audioSamples: [Float] = []
    @Published var placingOverlayID: UUID?
    @Published var isCropping = false
    @Published var selectedOverlayID: UUID?
    @Published var hasAudioTrack = false
    @Published var activeAnnotationTool: TimelineOverlayTrackKind?
    @Published var editingOverlayID: UUID?
    @Published var annotationColor: Color = .red
    @Published var annotationFontSize: Double = 28
    @Published var annotationStrokeWidth: Double = 3
    @Published var annotationFillOpacity: Double = 0.3
    @Published var annotationFontWeight: FontWeight = .semibold
    @Published var annotationArrowStyle: ArrowStyle = .open
    @Published var isPlaying = false

    private var previewTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var pendingSeekTime: TimeInterval?
    private var isSeeking = false
    private var seekGeneration = 0
    private var thumbnailRequestID = UUID()
    private var timelineThumbnailURL: URL?
    private var timelineThumbnailTargetCount: Int?
    private var timelineThumbnailTask: Task<[TimelineThumbnail], Never>?
    private let thumbnailLoader: @MainActor (VideoRecording, CGFloat) async -> [TimelineThumbnail]
    private var undoStack: [VideoTimelineHistoryState] = []
    private var redoStack: [VideoTimelineHistoryState] = []
    private var isRestoringHistory = false

    private let minimumClipDuration: TimeInterval = 0.08
    private let maximumHistoryDepth = 80

    init(video: VideoRecording? = nil,
         thumbnailLoader: @escaping @MainActor (VideoRecording, CGFloat) async -> [TimelineThumbnail] = {
             await TimelineThumbnailGenerator.generate(for: $0, width: $1)
         }) {
        self.thumbnailLoader = thumbnailLoader
        Publishers.CombineLatest($clips, $cropRect)
            .dropFirst().debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildPreview() }
            .store(in: &subscriptions)
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
        return clips.count != 1 || clips.first?.sourceRanges != [TimelineTimeRange(start: 0, end: video.duration)]
            || !overlayTracks.isEmpty || cropRect != QuickEditGeometry.fullFrame
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
        timelineThumbnailTask?.cancel()
        timelineThumbnailTask = nil
        thumbnailRequestID = UUID()
        let clip = makeInitialClip(for: video)
        self.video = video
        self.currentTime = 0
        self.timelineThumbnails = []
        self.isLoadingTimelineThumbnails = false
        self.timelineThumbnailURL = nil
        self.timelineThumbnailTargetCount = nil
        self.clips = [clip]
        self.selectedClipIDs = [clip.id]
        self.overlayTracks = []
        self.cropRect = QuickEditGeometry.fullFrame
        self.exportedURL = nil
        self.audioSamples = []
        self.selectedOverlayID = nil
        self.hasAudioTrack = false
        self.activeAnnotationTool = nil
        self.editingOverlayID = nil
        self.zoomScale = 1
        self.timelineSidebarWidth = 178
        self.draggedTimelineClipID = nil
        self.timelineSidebarResizeAnchor = 178
        self.undoStack.removeAll()
        self.redoStack.removeAll()
        rebuildPreview()
        Task { [weak self] in
            let audioTracks = try? await AVURLAsset(url: video.url).loadTracks(withMediaType: .audio)
            guard self?.video?.url == video.url else { return }
            self?.hasAudioTrack = !(audioTracks ?? []).isEmpty
            let samples = await VideoAudioWaveform.samples(from: video.url)
            guard self?.video?.url == video.url else { return }
            self?.audioSamples = samples
        }
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
        selectedOverlayID = nil
        editingOverlayID = nil
        activeAnnotationTool = nil

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

        let leftClip = VideoTimelineClip(name: clip.name, sourceRanges: split.left, hasCustomName: clip.hasCustomName)
        let rightClip = VideoTimelineClip(name: "", sourceRanges: split.right)

        clips.replaceSubrange(candidate.index...candidate.index, with: [leftClip, rightClip])
        refreshAutomaticClipNames()
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
            sourceRanges: mergedRanges,
            hasCustomName: clips[firstIndex].hasCustomName
        )

        clips.replaceSubrange(firstIndex...indices.last!, with: [mergedClip])
        refreshAutomaticClipNames()
        selectedClipIDs = [mergedClip.id]
        currentTime = timelineRange(for: mergedClip).start
    }

    func removeSelectedClips() {
        guard canRemove else { return }

        recordUndoSnapshot()

        let remaining = clips.filter { !selectedClipIDs.contains($0.id) }
        clips = remaining
        refreshAutomaticClipNames()
        overlayTracks = overlayTracks.compactMap { track in
            guard track.start < editedDuration else { return nil }
            var shortened = track; shortened.end = min(track.end, editedDuration)
            return shortened
        }
        if !overlayTracks.contains(where: { $0.id == selectedOverlayID }) { selectedOverlayID = nil }
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
        selectedOverlayID = nil
        cropRect = QuickEditGeometry.fullFrame
        selectedClipIDs = [clip.id]
        currentTime = 0
    }

    func addOverlayTrack(kind: TimelineOverlayTrackKind = .text, recordUndo: Bool = true) {
        if recordUndo { recordUndoSnapshot() }

        var track = TimelineOverlayTrack(title: kind.displayName, kind: kind)
        track.color = ColorData(color: annotationColor)
        track.fillOpacity = annotationFillOpacity
        track.fontWeight = annotationFontWeight
        track.arrowStyle = annotationArrowStyle
        track.fontScale = annotationFontSize / max(1, (video?.size.height ?? 800) * cropRect.height)
        track.strokeScale = annotationStrokeWidth / max(1, (video?.size.height ?? 800) * cropRect.height)
        track.text = "Note".localized
        track.start = min(currentTime, max(0, editedDuration - 0.1))
        let duration = min(15, max(5, editedDuration * 0.15))
        track.end = min(editedDuration, track.start + duration)
        overlayTracks.append(track)
        selectedOverlayID = track.id
        selectedClipIDs.removeAll()
        exportedURL = nil
    }

    func updateOverlay(_ track: TimelineOverlayTrack, recordUndo: Bool = true) {
        guard let index = overlayTracks.firstIndex(where: { $0.id == track.id }) else { return }
        if recordUndo { recordUndoSnapshot() }
        var normalized = track
        normalized.fillOpacity = track.fillOpacity.isFinite ? max(0, min(1, track.fillOpacity)) : 0
        normalized.start = max(0, min(track.start, max(0, editedDuration - 0.1)))
        normalized.end = max(normalized.start + 0.1, min(track.end, editedDuration))
        normalized.x = max(0, min(0.95, track.x))
        normalized.y = max(0, min(0.95, track.y))
        if track.kind != .line && track.kind != .callout {
            normalized.width = max(0.02, min(1 - normalized.x, track.width))
            normalized.height = max(0.02, min(1 - normalized.y, track.height))
        }
        normalized.title = track.kind == .text && !track.text.isEmpty ? track.text : track.kind.displayName
        overlayTracks[index] = normalized
        exportedURL = nil
    }

    func removeOverlay(_ id: UUID) {
        recordUndoSnapshot()
        overlayTracks.removeAll { $0.id == id }
        exportedURL = nil
        if selectedOverlayID == id { selectedOverlayID = nil }
        if editingOverlayID == id { editingOverlayID = nil }
    }

    func moveOverlay(_ id: UUID, relativeTo target: UUID, above: Bool) {
        let order = TimelineLayerOrder.moving(id, relativeTo: target, above: above, in: overlayTracks.map(\.id))
        guard order != overlayTracks.map(\.id) else { return }
        recordUndoSnapshot()
        let tracks = Dictionary(uniqueKeysWithValues: overlayTracks.map { ($0.id, $0) })
        overlayTracks = order.compactMap { tracks[$0] }
        exportedURL = nil
    }

    func selectOverlay(_ id: UUID) {
        if editingOverlayID != id { editingOverlayID = nil }
        selectedOverlayID = id
        selectedClipIDs.removeAll()
        activeAnnotationTool = nil
        if let track = overlayTracks.first(where: { $0.id == id }),
           currentTime < track.start || currentTime >= track.end {
            updateCurrentTime(to: track.start)
        }
    }

    func editOverlay(_ id: UUID) {
        beginOverlayGesture(id)
        pausePlayback()
        if overlayTracks.first(where: { $0.id == id })?.kind == .text { editingOverlayID = id }
    }

    func selectVideoAtPlayhead() {
        editingOverlayID = nil
        selectedOverlayID = nil
        activeAnnotationTool = nil
        var cursor: Double = 0
        for clip in clips {
            cursor += clip.duration
            if currentTime < cursor || clip.id == clips.last?.id {
                selectedClipIDs = [clip.id]
                return
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }
        editingOverlayID = nil
        if isPlaying { pausePlayback() }
        else {
            if currentTime >= editedDuration - 0.01 { updateCurrentTime(to: 0) }
            player.play()
            isPlaying = true
        }
    }

    func pausePlayback() { player?.pause(); isPlaying = false }

    func stopPlayback() { pausePlayback(); updateCurrentTime(to: 0) }

    func stepFrame(_ direction: Double) {
        pausePlayback()
        updateCurrentTime(to: currentTime + direction / max(1, video?.frameRate ?? 30))
    }

    func beginOverlayGesture(_ id: UUID) {
        selectOverlay(id)
        recordUndoSnapshot()
    }

    func setOverlayTiming(_ id: UUID, start: Double, end: Double, recordUndo: Bool = true) {
        guard var track = overlayTracks.first(where: { $0.id == id }) else { return }
        track.start = start; track.end = end
        updateOverlay(track, recordUndo: recordUndo)
    }

    func removeTimelineSelection() {
        if let selectedOverlayID { removeOverlay(selectedOverlayID) } else { removeSelectedClips() }
    }

    func applyCrop(_ rect: CGRect) {
        recordUndoSnapshot()
        cropRect = QuickEditGeometry.normalizedCrop(rect)
    }

    func rebuildPreview() {
        previewTask?.cancel()
        guard let video else { return }
        let ranges = editedSourceRanges()
        let crop = cropRect
        exportedURL = nil
        isPreparingPreview = true
        previewTask = Task { [weak self] in
            do {
                let item = try await VideoExportService.previewItem(video: video, ranges: ranges,
                    crop: crop, overlays: [])
                guard !Task.isCancelled, let self else { return }
                self.previewItem = item
                self.isPreparingPreview = false
            } catch {
                guard !Task.isCancelled else { return }
                self?.isPreparingPreview = false
                self?.errorMessage = error.localizedDescription
            }
        }
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
        refreshAutomaticClipNames()
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
        guard let video, width.isFinite, width > 0 else { return }

        let targetCount = TimelineThumbnailGenerator.targetCount(for: width)
        if !timelineThumbnails.isEmpty, timelineThumbnailURL == video.url, timelineThumbnailTargetCount == targetCount {
            return
        }
        guard !isLoadingTimelineThumbnails else { return }

        let requestID = UUID()
        thumbnailRequestID = requestID
        isLoadingTimelineThumbnails = true
        defer {
            if thumbnailRequestID == requestID {
                isLoadingTimelineThumbnails = false
            }
        }

        let loader = thumbnailLoader
        let task = Task { await loader(video, width) }
        timelineThumbnailTask = task
        let thumbnails = await task.value
        guard thumbnailRequestID == requestID else { return }
        timelineThumbnailTask = nil
        if !thumbnails.isEmpty {
            timelineThumbnails = thumbnails
            timelineThumbnailURL = video.url
            timelineThumbnailTargetCount = targetCount
        }
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

        guard !audioSamples.isEmpty, sourceDuration > 0 else { return Array(repeating: 0, count: count) }
        return (0..<count).map { index in
            let progress = Double(index) / Double(max(1, count - 1))
            let localOffset = clip.duration * progress
            let sourceTime = clip.sourceTime(forLocalOffset: localOffset) ?? localOffset
            let sampleIndex = min(audioSamples.count - 1, max(0, Int(sourceTime / sourceDuration * Double(audioSamples.count))))
            return CGFloat(audioSamples[sampleIndex])
        }
    }

    /// Keep one player per editing session, even when SwiftUI recreates its views.
    func synchronizedPreviewPlayer() -> AVPlayer {
        if player == nil {
            let player = AVPlayer()
            player.automaticallyWaitsToMinimizeStalling = true
            setPlayer(player)
        }
        let player = self.player!
        if let item = previewItem, player.currentItem !== item {
            let wasPlaying = player.rate > 0
            player.replaceCurrentItem(with: item)
            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 1000),
                        toleranceBefore: .zero, toleranceAfter: .zero)
            if wasPlaying { player.play() }
        }
        return player
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
        seekGeneration += 1
        isSeeking = false
        pendingSeekTime = nil
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
                settings: settings,
                crop: cropRect, overlays: overlayTracks
            )

            Logger.s("VideoEditorViewModel: Edited video exported to \(outputURL.path)")
            exportedURL = outputURL
        } catch {
            Logger.e("VideoEditorViewModel: Export error: \(error)")
            errorMessage = error.localizedDescription
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
                settings: settings,
                crop: cropRect, overlays: overlayTracks
            )

            Logger.s("VideoEditorViewModel: GIF exported to \(outputURL.path)")
            exportedURL = outputURL
        } catch {
            Logger.e("VideoEditorViewModel: GIF export error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func shareVideo() {
        guard let video else { return }

        let picker = NSSharingServicePicker(items: [exportedURL ?? video.url])
        if let window = NSApplication.shared.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }

    func keepBeforePlayhead() {
        trimTimeline(keep: TimelineTimeRange(start: 0, end: currentTime))
    }

    func keepAfterPlayhead() {
        trimTimeline(keep: TimelineTimeRange(start: currentTime, end: editedDuration))
    }

    private func trimTimeline(keep: TimelineTimeRange) {
        guard keep.duration >= minimumClipDuration else { return }
        recordUndoSnapshot()
        var result: [VideoTimelineClip] = []
        var cursor: Double = 0
        for clip in clips {
            var ranges: [TimelineTimeRange] = []
            for source in clip.sourceRanges {
                let start = max(cursor, keep.start), end = min(cursor + source.duration, keep.end)
                if end - start >= minimumClipDuration {
                    ranges.append(TimelineTimeRange(start: source.start + start - cursor, end: source.start + end - cursor))
                }
                cursor += source.duration
            }
            if !ranges.isEmpty { result.append(VideoTimelineClip(name: clip.name, sourceRanges: ranges, hasCustomName: clip.hasCustomName)) }
        }
        guard !result.isEmpty else { return }
        clips = result
        refreshAutomaticClipNames()
        overlayTracks = overlayTracks.compactMap { track in
            let start = max(track.start, keep.start), end = min(track.end, keep.end)
            guard end > start else { return nil }
            var updated = track; updated.start = start - keep.start; updated.end = end - keep.start
            return updated
        }
        selectedClipIDs = [result[0].id]
        currentTime = 0
    }

    func openInFinder() {
        guard let video else { return }
        NSWorkspace.shared.selectFile(
            video.url.path,
            inFileViewerRootedAtPath: video.url.deletingLastPathComponent().path
        )
    }

    @discardableResult
    func copyExportToClipboard(pasteboard: NSPasteboard = .general) -> Bool {
        guard let url = exportedURL, FileManager.default.fileExists(atPath: url.path) else { return false }
        pasteboard.clearContents()
        copiedExport = pasteboard.writeObjects([url as NSURL])
        return copiedExport
    }

    func showExportInFinder() {
        guard let url = exportedURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
        timelineThumbnailTask?.cancel()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }

    private func makeInitialClip(for video: VideoRecording) -> VideoTimelineClip {
        VideoTimelineClip(
            name: automaticClipName(at: 0),
            sourceRanges: [TimelineTimeRange(start: 0, end: video.duration)]
        )
    }

    func renameClip(_ id: UUID, to name: String) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let custom = !trimmed.isEmpty
        let updatedName = custom ? trimmed : automaticClipName(at: index)
        guard clips[index].name != updatedName || clips[index].hasCustomName != custom else { return }
        recordUndoSnapshot()
        clips[index].name = updatedName
        clips[index].hasCustomName = custom
    }

    private func automaticClipName(at index: Int) -> String {
        String(format: "Clip %ld".localized, index + 1)
    }

    private func refreshAutomaticClipNames() {
        for index in clips.indices where !clips[index].hasCustomName {
            clips[index].name = automaticClipName(at: index)
        }
    }

    private func seekToCurrentTime() {
        pendingSeekTime = currentTime
        performPendingSeek()
    }

    private func performPendingSeek() {
        guard !isSeeking, let player, let target = pendingSeekTime else { return }
        pendingSeekTime = nil
        isSeeking = true
        let generation = seekGeneration
        player.seek(to: CMTime(seconds: target, preferredTimescale: 1000),
            toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.seekGeneration == generation else { return }
                self.isSeeking = false
                self.performPendingSeek()
            }
        }
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
        if !isSeeking && pendingSeekTime == nil { currentTime = clampedEditedTime(sourceTime) }
        isPlaying = (player?.rate ?? 0) > 0
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
            currentTime: currentTime,
            cropRect: cropRect,
            selectedOverlayID: selectedOverlayID
        )
    }

    private func restore(historyState: VideoTimelineHistoryState) {
        clips = historyState.clips
        selectedClipIDs = historyState.selectedClipIDs
        overlayTracks = historyState.overlayTracks
        currentTime = historyState.currentTime
        cropRect = historyState.cropRect
        selectedOverlayID = historyState.selectedOverlayID
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
