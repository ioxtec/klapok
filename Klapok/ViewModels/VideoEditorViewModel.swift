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

struct VideoCutSegment: Identifiable, Equatable {
    let id = UUID()
    var startTime: TimeInterval
    var endTime: TimeInterval

    var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}

struct TimelineTimeRange: Equatable {
    var start: TimeInterval
    var end: TimeInterval

    var duration: TimeInterval {
        max(0, end - start)
    }
}

@MainActor
class VideoEditorViewModel: ObservableObject {
    @Published var video: VideoRecording?
    @Published var trimStartTime: TimeInterval = 0
    @Published var trimEndTime: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var isExporting: Bool = false
    @Published var timelineThumbnails: [TimelineThumbnail] = []
    @Published var isLoadingTimelineThumbnails: Bool = false
    @Published var timelineCutSelection: VideoCutSegment?
    @Published var cutSegments: [VideoCutSegment] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var thumbnailRequestID = UUID()
    private var timelineThumbnailURL: URL?

    init(video: VideoRecording? = nil) {
        self.video = video
        if let video = video {
            self.trimEndTime = video.duration
        }
    }

    func loadVideo(_ video: VideoRecording) {
        self.video = video
        self.trimStartTime = 0
        self.trimEndTime = video.duration
        self.currentTime = 0
        self.timelineThumbnails = []
        self.isLoadingTimelineThumbnails = false
        self.timelineThumbnailURL = nil
        self.timelineCutSelection = nil
        self.cutSegments = []
    }

    var trimmedDuration: TimeInterval {
        return max(0, trimEndTime - trimStartTime)
    }

    var editedDuration: TimeInterval {
        editedSourceRanges().reduce(0) { $0 + $1.duration }
    }

    var trimStartPercentage: Double {
        guard let video = video, video.duration > 0 else { return 0 }
        return trimStartTime / video.duration
    }

    var trimEndPercentage: Double {
        guard let video = video, video.duration > 0 else { return 1 }
        return trimEndTime / video.duration
    }

    var currentTimePercentage: Double {
        guard let video = video, video.duration > 0 else { return 0 }
        return clampedTime(currentTime) / video.duration
    }

    func updateTrimStart(from percentage: Double) {
        guard let video = video else { return }
        let newStartTime = percentage * video.duration
        let maxStartTime = max(0, trimEndTime - 0.1)
        if newStartTime >= 0 && newStartTime < maxStartTime {
            trimStartTime = newStartTime
            cutSegments = normalizedCutSegments(cutSegments)
            timelineCutSelection = nil
            clampCurrentTimeToTrim(seek: true)
        }
    }

    func updateTrimEnd(from percentage: Double) {
        guard let video = video else { return }
        let newEndTime = percentage * video.duration
        let minEndTime = min(video.duration, trimStartTime + 0.1)
        if newEndTime > minEndTime && newEndTime <= video.duration {
            trimEndTime = newEndTime
            cutSegments = normalizedCutSegments(cutSegments)
            timelineCutSelection = nil
            clampCurrentTimeToTrim(seek: true)
        }
    }

    func updateCurrentTime(from percentage: Double) {
        guard let video = video else { return }
        currentTime = clampedTime(percentage * video.duration)
        seekToCurrentTime()
    }

    func updateCutSelection(startPercentage: Double, endPercentage: Double) {
        guard let video else { return }
        let start = max(trimStartTime, min(trimEndTime, startPercentage * video.duration))
        let end = max(trimStartTime, min(trimEndTime, endPercentage * video.duration))
        let normalizedStart = min(start, end)
        let normalizedEnd = max(start, end)

        guard normalizedEnd - normalizedStart >= 0.05 else {
            timelineCutSelection = nil
            return
        }

        let proposedSelection = VideoCutSegment(
            startTime: normalizedStart,
            endTime: normalizedEnd
        )

        guard !overlapsExistingCut(proposedSelection) else {
            timelineCutSelection = nil
            return
        }

        timelineCutSelection = proposedSelection
    }

    func commitCutSelection() {
        guard let selection = timelineCutSelection, selection.duration >= 0.05 else { return }

        let candidateSegments = normalizedCutSegments(cutSegments + [selection])
        guard !editedSourceRanges(using: candidateSegments).isEmpty else {
            timelineCutSelection = nil
            return
        }

        cutSegments = candidateSegments
        timelineCutSelection = nil
    }

    func removeCut(_ cut: VideoCutSegment) {
        cutSegments.removeAll { $0.id == cut.id }
    }

    func clearCuts() {
        cutSegments = []
        timelineCutSelection = nil
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

    private func seekToCurrentTime() {
        guard let player = player else { return }
        let time = CMTime(seconds: currentTime, preferredTimescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setPlayer(_ player: AVPlayer) {
        if self.player === player {
            return
        }

        if let timeObserver = timeObserver {
            self.player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        self.player = player
        setupTimeObserver()
    }

    private func setupTimeObserver() {
        guard let player = player else { return }

        let timeScale = CMTimeScale(1000)
        let time = CMTime(seconds: 0.1, preferredTimescale: timeScale)

        timeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                Task { @MainActor in
                    self.syncCurrentTimeFromPlayer(seconds)
                }
            }
        }
    }

    private func syncCurrentTimeFromPlayer(_ seconds: TimeInterval) {
        let clamped = clampedTime(seconds)
        currentTime = clamped

        guard abs(clamped - seconds) > 0.05 else { return }
        player?.pause()
        seekToCurrentTime()
    }

    private func clampCurrentTimeToTrim(seek: Bool) {
        let clamped = clampedTime(currentTime)
        guard clamped != currentTime else { return }
        currentTime = clamped
        if seek {
            seekToCurrentTime()
        }
    }

    private func clampedTime(_ time: TimeInterval) -> TimeInterval {
        guard let video, video.duration > 0 else { return time }
        let lowerBound = max(0, min(video.duration, trimStartTime))
        let upperBound = max(lowerBound, min(video.duration, trimEndTime))
        return max(lowerBound, min(upperBound, time))
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
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

    private func editedSourceRanges() -> [TimelineTimeRange] {
        editedSourceRanges(using: cutSegments)
    }

    private func editedSourceRanges(using segments: [VideoCutSegment]) -> [TimelineTimeRange] {
        guard trimEndTime > trimStartTime else { return [] }

        let cuts = normalizedCutSegments(segments)
        var ranges: [TimelineTimeRange] = []
        var cursor = trimStartTime

        for cut in cuts {
            if cut.startTime > cursor {
                ranges.append(TimelineTimeRange(start: cursor, end: cut.startTime))
            }
            cursor = max(cursor, cut.endTime)
        }

        if cursor < trimEndTime {
            ranges.append(TimelineTimeRange(start: cursor, end: trimEndTime))
        }

        return ranges.filter { $0.duration >= 0.05 }
    }

    private func normalizedCutSegments(_ segments: [VideoCutSegment]) -> [VideoCutSegment] {
        let clipped = segments
            .map { segment in
                VideoCutSegment(
                    startTime: max(trimStartTime, min(trimEndTime, segment.startTime)),
                    endTime: max(trimStartTime, min(trimEndTime, segment.endTime))
                )
            }
            .filter { $0.duration >= 0.05 }
            .sorted { $0.startTime < $1.startTime }

        var merged: [VideoCutSegment] = []

        for segment in clipped {
            guard let last = merged.last else {
                merged.append(segment)
                continue
            }

            if segment.startTime <= last.endTime {
                merged[merged.count - 1] = VideoCutSegment(
                    startTime: last.startTime,
                    endTime: max(last.endTime, segment.endTime)
                )
            } else {
                merged.append(segment)
            }
        }

        return merged
    }

    private func overlapsExistingCut(_ selection: VideoCutSegment) -> Bool {
        cutSegments.contains { existing in
            max(existing.startTime, selection.startTime) < min(existing.endTime, selection.endTime)
        }
    }

    func shareVideo() {
        guard let video else { return }

        let picker = NSSharingServicePicker(items: [video.url])
        if let window = NSApplication.shared.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }

    func openInFinder() {
        guard let video else { return }
        NSWorkspace.shared.selectFile(video.url.path, inFileViewerRootedAtPath: video.url.deletingLastPathComponent().path)
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
            } catch {
                Logger.e("VideoEditorViewModel: Error deleting video: \(error)")
            }
        }
    }
}

#endif
