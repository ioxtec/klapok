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

struct VideoEditorView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Left area with video player and controls
            VStack(spacing: 0) {
                // Top toolbar
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.shareVideo()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.bordered)
                    .help("Share video")
                    
                    Button(action: {
                        viewModel.openInFinder()
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.bordered)
                    .help("Show in Finder")
                    
                    Button(action: {
                        Task {
                            await viewModel.exportTrimmedVideo()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isExporting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "scissors")
                                    .font(.system(size: 16))
                            }
                            Text("Export Trimmed")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Export trimmed video")
                    .disabled(viewModel.isExporting || viewModel.video == nil)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.deleteVideo()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                    .help("Delete video")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

                // Video player area
                GeometryReader { geometry in
                    if let video = viewModel.video {
                        VideoPlayerView(videoURL: video.url, viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                
                // Video timeline for trimming
                if viewModel.video != nil {
                    VideoTimelineView(viewModel: viewModel)
                        .frame(height: 80)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .frame(minWidth: 400)

            // Right sidebar with video details
            VStack(alignment: .leading, spacing: 16) {
                Text("Video Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                if let video = viewModel.video {
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "File:", value: video.url.lastPathComponent)
                        DetailRow(label: "Duration:", value: formatDuration(video.duration))
                        DetailRow(label: "Size:", value: formatFileSize(video.url))
                        DetailRow(label: "Created:", value: formatDate(video.url))
                        DetailRow(label: "Frame Rate:", value: "\(Int(video.frameRate)) FPS")
                        DetailRow(label: "Resolution:", value: "\(Int(video.size.width)) × \(Int(video.size.height))")
                    }
                    .padding(.horizontal, 16)
                } else {
                    Text("No video selected")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .frame(width: 300)
            .background(Color(NSColor.controlBackgroundColor))
        }
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

// MARK: - Video Player View

struct VideoPlayerView: NSViewRepresentable {
    let videoURL: URL
    let viewModel: VideoEditorViewModel
    
    func makeNSView(context: Context) -> AVPlayerView {
        print("🔍 VideoPlayerView: makeNSView called for URL: \(videoURL)")
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.showsFrameSteppingButtons = true
        playerView.showsSharingServiceButton = true
        
        print("🔍 VideoPlayerView: AVPlayerView created")
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        print("🔍 VideoPlayerView: updateNSView called for URL: \(videoURL)")
        // Create new player each time to avoid zombie issues
        let player = AVPlayer(url: videoURL)
        print("🔍 VideoPlayerView: AVPlayer created")
        nsView.player = player
        print("🔍 VideoPlayerView: Player set on AVPlayerView")
        
        // Pass player to view model for time tracking
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

@MainActor
class VideoEditorViewModel: ObservableObject {
    @Published var video: VideoRecording?
    @Published var trimStartTime: TimeInterval = 0
    @Published var trimEndTime: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var isExporting: Bool = false
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
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
    }
    
    var trimmedDuration: TimeInterval {
        return trimEndTime - trimStartTime
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
        }
    }
    
    func updateTrimEnd(from percentage: Double) {
        guard let video = video else { return }
        let newEndTime = percentage * video.duration
        // Ensure minimum 0.1 second gap between start and end
        let minEndTime = min(video.duration, trimStartTime + 0.1)
        if newEndTime > minEndTime && newEndTime <= video.duration {
            trimEndTime = newEndTime
        }
    }
    
    func updateCurrentTime(from percentage: Double) {
        guard let video = video else { return }
        currentTime = percentage * video.duration
        seekToCurrentTime()
    }
    
    private func seekToCurrentTime() {
        guard let player = player else { return }
        let time = CMTime(seconds: currentTime, preferredTimescale: 1000)
        player.seek(to: time)
    }
    
    func setPlayer(_ player: AVPlayer) {
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
            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
            
            // Create time range for trimming
            let startTime = CMTime(seconds: trimStartTime, preferredTimescale: 1000)
            let endTime = CMTime(seconds: trimEndTime, preferredTimescale: 1000)
            let timeRange = CMTimeRange(start: startTime, end: endTime)
            
            exportSession?.timeRange = timeRange
            
            // Create output URL
            let outputURL = video.url.deletingLastPathComponent()
                .appendingPathComponent("\(video.url.deletingPathExtension().lastPathComponent)_trimmed")
                .appendingPathExtension(video.url.pathExtension)
            
            exportSession?.outputURL = outputURL
            exportSession?.outputFileType = .mp4
            
            try await exportSession?.export(to: outputURL, as: .mp4)
            
            print("✅ Trimmed video exported successfully to: \(outputURL.path)")
            // Open the exported video
            NSWorkspace.shared.open(outputURL)
            
        } catch {
            print("❌ Export error: \(error)")
        }
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
    
    var body: some View {
        VStack(spacing: 8) {
            // Timeline info
            HStack {
                Text("Duration: \(formatDuration(viewModel.trimmedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Start: \(formatTime(viewModel.trimStartTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("End: \(formatTime(viewModel.trimEndTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Timeline track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    // Trimmed section
                    Rectangle()
                        .fill(Color.blue)
                        .frame(
                            width: geometry.size.width * (viewModel.trimEndPercentage - viewModel.trimStartPercentage),
                            height: 6
                        )
                        .offset(x: geometry.size.width * viewModel.trimStartPercentage)
                        .cornerRadius(3)
                    
                    // Current time indicator
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 2, height: 20)
                        .offset(x: geometry.size.width * viewModel.currentTimePercentage - 1)
                    
                    // Start trim handle
                    TrimHandle(
                        position: viewModel.trimStartPercentage,
                        geometry: geometry,
                        isStartHandle: true
                    ) { percentage in
                        viewModel.updateTrimStart(from: percentage)
                    }
                    
                    // End trim handle
                    TrimHandle(
                        position: viewModel.trimEndPercentage,
                        geometry: geometry,
                        isStartHandle: false
                    ) { percentage in
                        viewModel.updateTrimEnd(from: percentage)
                    }
                }
                .onTapGesture { location in
                    let percentage = location.x / geometry.size.width
                    viewModel.updateCurrentTime(from: max(0, min(1, percentage)))
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Trim Handle

struct TrimHandle: View {
    let position: Double
    let geometry: GeometryProxy
    let isStartHandle: Bool
    let onDrag: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragStartPosition: Double = 0
    
    var body: some View {
        VStack(spacing: 2) {
            // Handle icon
            Image(systemName: isStartHandle ? "chevron.left" : "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 12, height: 12)
                .background(Color.blue)
                .cornerRadius(6)
            
            // Handle line
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2, height: 16)
        }
        .offset(x: geometry.size.width * position - 6)
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragStartPosition = position
                    }
                    
                    // Calculate new position based on drag distance
                    let dragDistance = value.translation.width
                    let dragPercentage = dragDistance / geometry.size.width
                    let newPosition = dragStartPosition + dragPercentage
                    
                    // Clamp to valid range
                    let clampedPosition = max(0, min(1, newPosition))
                    onDrag(clampedPosition)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

#Preview {
    VideoEditorView(viewModel: VideoEditorViewModel())
        .frame(width: 800, height: 600)
}

#endif
