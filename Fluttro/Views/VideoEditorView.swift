//
//  VideoEditorView.swift
//  Fluttro
//
//  Video editor view for reviewing recorded videos
//

import SwiftUI

#if os(macOS)
import AppKit
import AVKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

struct VideoEditorView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @StateObject private var settings = AppSettings.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var exportManager = ExportManager.shared
    
    var body: some View {
        NavigationSplitView {
            VideoEditorSidebarView(
                video: viewModel.video,
                settings: settings,
                profileManager: profileManager,
                exportManager: exportManager,
                formatDuration: formatDuration,
                formatFileSize: formatFileSize,
                formatDate: formatDate
            )
            .navigationSplitViewColumnWidth(300)
        } detail: {
            VStack(spacing: 0) {
                // Video player area
                GeometryReader { geometry in
                    if let video = viewModel.video {
                        VideoPlayerView(videoURL: video.url, viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No Video Selected")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("Select a video file to preview")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                
                // Video timeline for trimming
                if viewModel.video != nil {
                    VideoTimelineView(viewModel: viewModel)
                        .frame(height: 176)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .toolbar {
            VideoEditorCommandToolbar(
                viewModel: viewModel,
                exportManager: exportManager
            )
        }
        .frame(minWidth: 1180, minHeight: 720)
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return "Unknown"
    }
    
    private func formatDate(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let date = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } catch {
            print("Error getting creation date: \(error)")
        }
        return "Unknown"
    }
}

// MARK: - Video Editor Sidebar

private struct VideoEditorSidebarView: View {
    let video: VideoRecording?
    @ObservedObject var settings: AppSettings
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var exportManager: ExportManager
    let formatDuration: (TimeInterval) -> String
    let formatFileSize: (URL) -> String
    let formatDate: (URL) -> String

    var body: some View {
        RoundedSidebarHost(cornerRadius: 18) {
            sidebarContent
        }
        .frame(width: 300)
    }

    private var sidebarContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                SidebarDisclosureSection(
                    id: "video.profiles",
                    title: "Profiles",
                    systemImage: "slider.horizontal.3",
                    subtitle: "Presets for export format, quality, size, and audio."
                ) {
                    profileControl
                }

                SidebarDisclosureSection(
                    id: "video.source",
                    title: "Video",
                    systemImage: "film",
                    subtitle: "Source file, duration, and capture details."
                ) {
                    if let video {
                        VStack(alignment: .leading, spacing: 10) {
                            VideoDetailRow(title: "File", value: video.url.lastPathComponent)
                            VideoDetailRow(title: "Duration", value: formatDuration(video.duration))
                            VideoDetailRow(title: "Size", value: formatFileSize(video.url))
                            VideoDetailRow(title: "Created", value: formatDate(video.url))
                            VideoDetailRow(title: "Frame rate", value: "\(Int(video.frameRate)) FPS")
                            VideoDetailRow(
                                title: "Resolution",
                                value: "\(Int(video.size.width)) x \(Int(video.size.height))"
                            )
                        }
                    } else {
                        VideoSidebarHint("No video selected.")
                    }
                }

                SidebarDisclosureSection(
                    id: "video.export",
                    title: "Export",
                    systemImage: "square.and.arrow.up",
                    subtitle: "Trimmed video or GIF output settings."
                ) {
                    ExportTypeSelector(exportManager: exportManager)

                    if exportManager.settings.exportType == .video {
                        VideoExportSettingsView(exportManager: exportManager)
                    } else {
                        GIFExportSettingsView(
                            exportManager: exportManager,
                            sourceSize: video?.size
                        )
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 24)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.visible)
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var profileControl: some View {
        ProfileControlView<VideoEditingProfile>(
            profileManager: profileManager,
            profiles: profileManager.videoProfiles.profiles,
            activeProfile: profileManager.getActiveVideoProfile(),
            profileTypeName: "Video",
            showsHeader: false,
            usesContainer: false,
            onProfileSelected: { profile in
                profileManager.applyVideoProfile(profile, to: settings)
            },
            onProfileAdded: { name in
                let newProfile = profileManager.createVideoProfileFromCurrentSettings(
                    name: name,
                    from: settings
                )
                profileManager.setActiveVideoProfile(newProfile)
            },
            onProfileEdited: updateProfile,
            onProfileDeleted: { profile in
                profileManager.removeVideoProfile(withId: profile.id)
            },
            onImportProfiles: {
                _ = profileManager.importVideoProfiles()
            },
            onExportProfiles: {
                _ = profileManager.exportVideoProfiles()
            },
            onResetProfiles: {
                profileManager.resetVideoProfilesToDefaults()
            }
        )
    }

    private func updateProfile(_ profile: VideoEditingProfile, newName: String) {
        if newName == profile.name {
            let updatedProfile = VideoEditingProfile(
                id: profile.id,
                name: profile.name,
                isDefault: profile.isDefault,
                createdAt: profile.createdAt,
                modifiedAt: Date(),
                resolution: settings.videoResolution,
                frameRate: settings.videoFrameRate,
                bitrate: settings.videoBitrate,
                codec: settings.videoCodec,
                format: settings.videoFormat,
                recordSystemAudio: settings.recordSystemAudio,
                recordMicrophone: settings.recordMicrophone,
                audioQuality: "High",
                showMouseCursor: settings.showMouseCursor,
                showRecordingTimer: true,
                autoStopAfterTime: false,
                maxTime: "10min",
                compressAfterRecording: true,
                deleteAfterRecording: false
            )
            profileManager.updateVideoProfile(updatedProfile)
        } else {
            var updatedProfile = profile
            updatedProfile.name = newName
            updatedProfile.modifiedAt = Date()
            profileManager.updateVideoProfile(updatedProfile)
        }
    }
}

private struct RoundedSidebarHost<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content)
        configure(hostingView)
        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
        configure(nsView)
    }

    private func configure(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.needsLayout = true
        view.needsDisplay = true
    }
}

private struct VideoDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.callout)

            Spacer()

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

private struct VideoSidebarHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct VideoEditorCommandToolbar: ToolbarContent {
    @ObservedObject var viewModel: VideoEditorViewModel
    @ObservedObject var exportManager: ExportManager

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                viewModel.shareVideo()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(viewModel.video == nil)
            .help("Share video")

            Button {
                viewModel.openInFinder()
            } label: {
                Image(systemName: "folder")
            }
            .disabled(viewModel.video == nil)
            .help("Show in Finder")

            Button {
                Task {
                    if exportManager.settings.exportType == .video {
                        await viewModel.exportTrimmedVideo()
                    } else {
                        await viewModel.exportAsGIF(settings: exportManager.settings.gifSettings)
                    }
                }
            } label: {
                if viewModel.isExporting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: exportManager.settings.exportType == .video ? "scissors" : "rectangle.stack.fill")
                }
            }
            .disabled(viewModel.isExporting || viewModel.video == nil)
            .help("Export as \(exportManager.settings.exportType.displayName)")

            Button(role: .destructive) {
                viewModel.deleteVideo()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.video == nil)
            .help("Delete video")
        }
    }
}

// MARK: - Video Player View

struct VideoPlayerView: NSViewRepresentable {
    let videoURL: URL
    let viewModel: VideoEditorViewModel

    final class Coordinator {
        var player: AVPlayer?
        var videoURL: URL?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> AVPlayerView {
        print("🔍 VideoPlayerView: makeNSView called for URL: \(videoURL)")
        let playerView = AVPlayerView()
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        playerView.controlsStyle = .floating
        playerView.showsFrameSteppingButtons = true
        playerView.showsSharingServiceButton = true
        
        print("🔍 VideoPlayerView: AVPlayerView created")
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        print("🔍 VideoPlayerView: updateNSView called for URL: \(videoURL)")

        if context.coordinator.videoURL != videoURL || context.coordinator.player == nil {
            let player = AVPlayer(url: videoURL)
            print("🔍 VideoPlayerView: AVPlayer created")
            context.coordinator.player = player
            context.coordinator.videoURL = videoURL
        }

        guard let player = context.coordinator.player else { return }

        if nsView.player !== player {
            nsView.player = player
            print("🔍 VideoPlayerView: Player set on AVPlayerView")
        }

        viewModel.setPlayer(player)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Video Editor ViewModel

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

private struct TimelineTimeRange: Equatable {
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
        return currentTime / video.duration
    }
    
    func updateTrimStart(from percentage: Double) {
        guard let video = video else { return }
        let newStartTime = percentage * video.duration
        // Ensure minimum 0.1 second gap between start and end
        let maxStartTime = max(0, trimEndTime - 0.1)
        if newStartTime >= 0 && newStartTime < maxStartTime {
            trimStartTime = newStartTime
            cutSegments = normalizedCutSegments(cutSegments)
            timelineCutSelection = nil
        }
    }
    
    func updateTrimEnd(from percentage: Double) {
        guard let video = video else { return }
        let newEndTime = percentage * video.duration
        // Ensure minimum 0.1 second gap between start and end
        let minEndTime = min(video.duration, trimStartTime + 0.1)
        if newEndTime > minEndTime && newEndTime <= video.duration {
            trimEndTime = newEndTime
            cutSegments = normalizedCutSegments(cutSegments)
            timelineCutSelection = nil
        }
    }
    
    func updateCurrentTime(from percentage: Double) {
        guard let video = video else { return }
        currentTime = percentage * video.duration
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

        timelineCutSelection = VideoCutSegment(
            startTime: normalizedStart,
            endTime: normalizedEnd
        )
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

        let targetCount = max(6, min(36, Int(width / 72)))
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

        let asset = AVURLAsset(url: video.url)
        let assetDuration = (try? await asset.load(.duration).seconds) ?? video.duration
        let duration = assetDuration.isFinite && assetDuration > 0 ? assetDuration : video.duration
        guard duration > 0 else { return }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 144, height: 82)

        let step = duration / Double(targetCount)
        let tolerance = CMTime(seconds: max(0.25, step), preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var thumbnails: [TimelineThumbnail] = []

        for index in 0..<targetCount {
            guard thumbnailRequestID == requestID else { return }

            let seconds = min(max(0, duration - 0.01), max(0, (Double(index) + 0.5) * step))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)

            do {
                let generated = try await generator.image(at: time)
                let image = NSImage(
                    cgImage: generated.image,
                    size: CGSize(width: generated.image.width, height: generated.image.height)
                )
                thumbnails.append(TimelineThumbnail(time: seconds, image: image))
            } catch {
                print("⚠️ Failed to generate timeline thumbnail at \(seconds)s: \(error)")
            }
        }

        if thumbnails.isEmpty {
            thumbnails = await fallbackTimelineThumbnails(
                from: generator,
                duration: duration,
                targetCount: targetCount
            )
        }

        guard thumbnailRequestID == requestID else { return }
        timelineThumbnails = thumbnails
        timelineThumbnailURL = video.url
    }

    private func fallbackTimelineThumbnails(
        from generator: AVAssetImageGenerator,
        duration: TimeInterval,
        targetCount: Int
    ) async -> [TimelineThumbnail] {
        let fallbackTimes = [0, duration * 0.25, duration * 0.5, duration * 0.75]
        var fallbackImage: NSImage?

        for seconds in fallbackTimes {
            do {
                let generated = try await generator.image(
                    at: CMTime(seconds: max(0, min(duration, seconds)), preferredTimescale: 600)
                )
                fallbackImage = NSImage(
                    cgImage: generated.image,
                    size: CGSize(width: generated.image.width, height: generated.image.height)
                )
                break
            } catch {
                print("⚠️ Fallback timeline thumbnail failed at \(seconds)s: \(error)")
            }
        }

        if fallbackImage == nil {
            let times = fallbackTimes.map {
                CMTime(seconds: max(0, min(duration, $0)), preferredTimescale: 600)
            }

            for await result in generator.images(for: times) {
                if case .success(_, let cgImage, _) = result {
                    fallbackImage = NSImage(
                        cgImage: cgImage,
                        size: CGSize(width: cgImage.width, height: cgImage.height)
                    )
                    break
                }
            }
        }

        guard let fallbackImage else { return [] }

        return (0..<targetCount).map { index in
            TimelineThumbnail(
                time: duration * (Double(index) + 0.5) / Double(targetCount),
                image: fallbackImage
            )
        }
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
                    self.currentTime = seconds
                }
            }
        }
    }
    
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }
    
    func exportTrimmedVideo() async {
        guard let video = video else { return }
        
        isExporting = true
        defer { isExporting = false }
        
        do {
            let asset = AVURLAsset(url: video.url)
            let exportAsset = try await editedExportAsset(from: asset)
            let exportSession = AVAssetExportSession(asset: exportAsset, presetName: AVAssetExportPresetHighestQuality)
            
            // Create output URL
            let outputURL = uniqueOutputURL(
                baseName: "\(video.url.deletingPathExtension().lastPathComponent)_edited",
                fileExtension: "mp4",
                in: video.url.deletingLastPathComponent()
            )
            
            exportSession?.outputURL = outputURL
            exportSession?.outputFileType = .mp4
            
            try await exportSession?.export(to: outputURL, as: .mp4)
            
            print("✅ Edited video exported successfully to: \(outputURL.path)")
            // Open the exported video
            NSWorkspace.shared.open(outputURL)
            
        } catch {
            print("❌ Export error: \(error)")
        }
    }
    
    func exportAsGIF(settings: GIFExportSettings) async {
        guard let video = video else { return }
        
        isExporting = true
        defer { isExporting = false }
        
        let asset = AVURLAsset(url: video.url)
        
        // Generate frames
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        // Calculate max size respecting aspect ratio
        let videoSize = video.size
        let aspectRatio = videoSize.width / videoSize.height
        var targetWidth = CGFloat(settings.maxWidth)
        var targetHeight = CGFloat(settings.maxHeight)
        
        if targetWidth / targetHeight > aspectRatio {
            targetWidth = targetHeight * aspectRatio
        } else {
            targetHeight = targetWidth / aspectRatio
        }
        
        generator.maximumSize = CGSize(width: targetWidth, height: targetHeight)
        
        // Calculate frame times
        let ranges = editedSourceRanges()
        let duration = max(0.1, ranges.reduce(0) { $0 + $1.duration })
        let frameCount = max(1, Int(duration * Double(settings.frameRate)))
        let frameDuration = duration / Double(frameCount)
        
        var frameTimes: [CMTime] = []
        for i in 0..<frameCount {
            if let sourceSeconds = sourceTime(forEditedOffset: Double(i) * frameDuration, in: ranges) {
                let time = CMTime(seconds: sourceSeconds, preferredTimescale: 600)
                frameTimes.append(time)
            }
        }
        
        // Create output URL
        let outputURL = video.url.deletingLastPathComponent()
            .appendingPathComponent("\(video.url.deletingPathExtension().lastPathComponent)_animated")
            .appendingPathExtension("gif")
        
        // Create GIF file
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameTimes.count,
            nil
        ) else {
            print("❌ Failed to create GIF destination")
            return
        }
        
        // Set GIF properties
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: settings.loopMode == .infinite ? 0 : (settings.loopMode == .once ? 1 : settings.loopCount),
                kCGImagePropertyGIFHasGlobalColorMap as String: true
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        let frameDelay = 1.0 / Double(settings.frameRate)
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]
        
        // Generate and add frames
        for time in frameTimes {
            do {
                let cgImage = try await generator.image(at: time).image
                
                // Apply color depth reduction if needed
                if settings.colorDepth.colorCount < 256 {
                    // Note: Color quantization would require additional image processing
                    // For now, we'll use the full image
                    CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                } else {
                    CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                }
            } catch {
                print("⚠️ Failed to generate frame at \(time.seconds)s: \(error)")
            }
        }
        
        // Finalize GIF
        guard CGImageDestinationFinalize(destination) else {
            print("❌ Failed to finalize GIF")
            return
        }
        
        print("✅ GIF exported successfully to: \(outputURL.path)")
        print("📊 GIF stats: \(frameTimes.count) frames, \(settings.frameRate) fps, \(Int(targetWidth))x\(Int(targetHeight))px")
        
        // Open the exported GIF
        NSWorkspace.shared.open(outputURL)
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

    private func editedExportAsset(from asset: AVURLAsset) async throws -> AVAsset {
        let ranges = editedSourceRanges()

        guard !ranges.isEmpty else { return asset }

        let composition = AVMutableComposition()

        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              )
        else {
            return asset
        }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        let compositionAudioTrack = audioTracks.first.flatMap { _ in
            composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        var insertionTime = CMTime.zero

        for range in ranges {
            let sourceRange = CMTimeRange(
                start: CMTime(seconds: range.start, preferredTimescale: 1000),
                duration: CMTime(seconds: range.duration, preferredTimescale: 1000)
            )

            try compositionVideoTrack.insertTimeRange(
                sourceRange,
                of: sourceVideoTrack,
                at: insertionTime
            )

            if let sourceAudioTrack = audioTracks.first,
               let compositionAudioTrack {
                try compositionAudioTrack.insertTimeRange(
                    sourceRange,
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }

            insertionTime = CMTimeAdd(insertionTime, sourceRange.duration)
        }

        let transform = try await sourceVideoTrack.load(.preferredTransform)
        compositionVideoTrack.preferredTransform = transform

        return composition
    }

    private func sourceTime(
        forEditedOffset offset: TimeInterval,
        in ranges: [TimelineTimeRange]
    ) -> TimeInterval? {
        var remaining = offset

        for range in ranges {
            if remaining <= range.duration {
                return range.start + remaining
            }
            remaining -= range.duration
        }

        return ranges.last?.end
    }

    private func uniqueOutputURL(
        baseName: String,
        fileExtension: String,
        in directory: URL
    ) -> URL {
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName)_\(index)")
                .appendingPathExtension(fileExtension)
            index += 1
        }

        return candidate
    }
    
    func shareVideo() {
        guard let video = video else { return }
        
        let picker = NSSharingServicePicker(items: [video.url])
        if let window = NSApplication.shared.keyWindow {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    func openInFinder() {
        guard let video = video else { return }
        NSWorkspace.shared.selectFile(video.url.path, inFileViewerRootedAtPath: video.url.deletingLastPathComponent().path)
    }
    
    func deleteVideo() {
        guard let video = video else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Video"
        alert.informativeText = "Are you sure you want to delete this video? This action cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.removeItem(at: video.url)
                self.video = nil
            } catch {
                print("Error deleting video: \(error)")
            }
        }
    }
}

// MARK: - Video Timeline View

struct VideoTimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var dragMode: TimelineDragMode?
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Source \(formatTime(viewModel.video?.duration ?? 0))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Selection \(formatTime(viewModel.trimmedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !viewModel.cutSegments.isEmpty {
                    Text("Output \(formatTime(viewModel.editedDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(formatTime(viewModel.trimStartTime)) - \(formatTime(viewModel.trimEndTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Cut selection") {
                    viewModel.commitCutSelection()
                }
                .controlSize(.small)
                .disabled(viewModel.timelineCutSelection == nil)

                Button("Clear cuts") {
                    viewModel.clearCuts()
                }
                .controlSize(.small)
                .disabled(viewModel.cutSegments.isEmpty && viewModel.timelineCutSelection == nil)
            }

            GeometryReader { geometry in
                let trackHeight: CGFloat = 64
                let interactionOutset: CGFloat = 24
                let playheadTopOutset: CGFloat = 14

                VStack(spacing: 6) {
                    TimelineRuler(duration: viewModel.video?.duration ?? 0)
                        .frame(height: 18)

                    ZStack(alignment: .leading) {
                        TimelineThumbnailStrip(
                            thumbnails: viewModel.timelineThumbnails,
                            isLoading: viewModel.isLoadingTimelineThumbnails
                        )
                            .frame(height: trackHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                            .zIndex(0)

                        TimelineDimmedRegion(
                            start: 0,
                            end: viewModel.trimStartPercentage,
                            width: geometry.size.width,
                            height: trackHeight
                        )
                        .allowsHitTesting(false)
                        .zIndex(2)

                        TimelineDimmedRegion(
                            start: viewModel.trimEndPercentage,
                            end: 1,
                            width: geometry.size.width,
                            height: trackHeight
                        )
                        .allowsHitTesting(false)
                        .zIndex(2)

                        ForEach(viewModel.cutSegments) { cut in
                            TimelineSegmentOverlay(
                                start: percentage(for: cut.startTime),
                                end: percentage(for: cut.endTime),
                                width: geometry.size.width,
                                height: trackHeight,
                                color: .red,
                                opacity: 0.45
                            )
                            .allowsHitTesting(false)
                            .zIndex(3)
                        }

                        if let selection = viewModel.timelineCutSelection {
                            TimelineSegmentOverlay(
                                start: percentage(for: selection.startTime),
                                end: percentage(for: selection.endTime),
                                width: geometry.size.width,
                                height: trackHeight,
                                color: .orange,
                                opacity: 0.42
                            )
                            .allowsHitTesting(false)
                            .zIndex(4)

                            TimelineCutLabel(
                                start: percentage(for: selection.startTime),
                                width: geometry.size.width
                            )
                            .allowsHitTesting(false)
                            .zIndex(8)
                        }

                        TimelinePlayhead(
                            position: viewModel.currentTimePercentage,
                            height: trackHeight + 20,
                            width: geometry.size.width
                        )
                        .allowsHitTesting(false)
                        .zIndex(20)

                        TrimHandle(
                            position: viewModel.trimStartPercentage,
                            width: geometry.size.width,
                            height: trackHeight,
                            isStartHandle: true
                        )
                        .allowsHitTesting(false)
                        .zIndex(30)

                        TrimHandle(
                            position: viewModel.trimEndPercentage,
                            width: geometry.size.width,
                            height: trackHeight,
                            isStartHandle: false
                        )
                        .allowsHitTesting(false)
                        .zIndex(30)

                        TimelineInteractionLayer()
                            .frame(
                                width: geometry.size.width + interactionOutset * 2,
                                height: trackHeight + playheadTopOutset
                            )
                            .offset(x: -interactionOutset, y: -playheadTopOutset)
                            .gesture(interactionGesture(width: geometry.size.width))
                            .zIndex(40)
                    }
                    .frame(height: trackHeight)
                    .coordinateSpace(name: "timelineTrack")
                    .task(id: timelineLoadID(width: geometry.size.width)) {
                        await viewModel.loadTimelineThumbnails(for: geometry.size.width)
                    }

                    if !viewModel.cutSegments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(viewModel.cutSegments) { cut in
                                    CutSegmentPill(cut: cut) {
                                        viewModel.removeCut(cut)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        HStack {
                            Text("Drag across the frame strip to mark a part to cut.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func interactionGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("timelineTrack"))
            .onChanged { value in
                guard width > 0 else { return }

                let start = percentage(fromTimelineX: value.startLocation.x, width: width)
                let current = percentage(fromTimelineX: value.location.x, width: width)

                if dragMode == nil {
                    dragMode = dragModeForStartLocation(value.startLocation.x, width: width)
                }

                switch dragMode {
                case .trimStart:
                    viewModel.updateTrimStart(from: current)
                case .trimEnd:
                    viewModel.updateTrimEnd(from: current)
                case .playhead:
                    viewModel.updateCurrentTime(from: current)
                case .cutSelection:
                    if abs(value.translation.width) < 3 {
                        viewModel.updateCurrentTime(from: current)
                    } else {
                        viewModel.updateCurrentTime(from: current)
                        viewModel.updateCutSelection(startPercentage: start, endPercentage: current)
                    }
                case nil:
                    break
                }
            }
            .onEnded { _ in
                dragMode = nil
            }
    }

    private func dragModeForStartLocation(_ x: CGFloat, width: CGFloat) -> TimelineDragMode {
        let hitRadius: CGFloat = 28
        let startX = width * viewModel.trimStartPercentage
        let endX = width * viewModel.trimEndPercentage
        let playheadX = width * viewModel.currentTimePercentage

        if abs(x - playheadX) <= hitRadius {
            return .playhead
        }

        if abs(x - startX) <= hitRadius {
            return .trimStart
        }

        if abs(x - endX) <= hitRadius {
            return .trimEnd
        }

        return .cutSelection
    }

    private func percentage(fromTimelineX x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return clampedPercentage(x / width)
    }

    private func percentage(for time: TimeInterval) -> Double {
        guard let duration = viewModel.video?.duration, duration > 0 else { return 0 }
        return max(0, min(1, time / duration))
    }

    private func clampedPercentage(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private func timelineLoadID(width: CGFloat) -> String {
        "\(viewModel.video?.url.path ?? "none")-\(Int(width))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private enum TimelineDragMode {
    case trimStart
    case trimEnd
    case playhead
    case cutSelection
}

private struct TimelineRuler: View {
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let tickCount = max(2, min(12, Int(geometry.size.width / 96)))

            ZStack(alignment: .leading) {
                ForEach(0...tickCount, id: \.self) { index in
                    let progress = Double(index) / Double(tickCount)
                    let x = geometry.size.width * progress

                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 1, height: index % 2 == 0 ? 8 : 5)

                        if index % 2 == 0 {
                            Text(formatTime(duration * progress))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .offset(x: index == tickCount ? -28 : 0)
                        }
                    }
                    .offset(x: x)
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TimelineThumbnailStrip: View {
    let thumbnails: [TimelineThumbnail]
    let isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            if thumbnails.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                HStack(spacing: 1) {
                    ForEach(thumbnails) { thumbnail in
                        Image(nsImage: thumbnail.image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: max(1, geometry.size.width / CGFloat(thumbnails.count)),
                                height: geometry.size.height
                            )
                            .clipped()
                    }
                }
            }
        }
    }
}

private struct TimelineDimmedRegion: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        TimelineSegmentOverlay(
            start: start,
            end: end,
            width: width,
            height: height,
            color: .black,
            opacity: 0.58
        )
    }
}

private struct TimelineSegmentOverlay: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let opacity: Double

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(width: max(0, width * max(0, end - start)), height: height)
            .offset(x: width * start)
    }
}

private struct TimelineInteractionLayer: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
    }
}

private struct TimelinePlayhead: View {
    let position: Double
    let height: CGFloat
    let width: CGFloat
    private let topOutset: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: height - 8)
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .frame(width: 18, height: height)
        .position(x: width * position, y: height / 2 - topOutset)
        .contentShape(Rectangle())
    }
}

private struct TimelineCutLabel: View {
    let start: Double
    let width: CGFloat

    var body: some View {
        Text("cut")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(x: labelX, y: 6)
    }

    private var labelX: CGFloat {
        let preferredX = width * start + 6
        return min(max(6, preferredX), max(6, width - 34))
    }
}

struct TrimHandle: View {
    let position: Double
    let width: CGFloat
    let height: CGFloat
    let isStartHandle: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor)
                .frame(width: 14, height: height)
                .overlay {
                    Image(systemName: isStartHandle ? "chevron.left" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
        }
        .frame(width: 18, height: height)
        .position(x: width * position, y: (height / 2) + 5)
        .contentShape(Rectangle())
    }
}

private struct CutSegmentPill: View {
    let cut: VideoCutSegment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))

            Text("\(formatTime(cut.startTime)) - \(formatTime(cut.endTime))")
                .font(.system(size: 11, design: .monospaced))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    VideoEditorView(viewModel: VideoEditorViewModel())
        .frame(width: 800, height: 600)
}

#endif
