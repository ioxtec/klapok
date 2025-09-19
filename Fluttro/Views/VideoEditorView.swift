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
                        VideoPlayerView(videoURL: video.url)
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
    
    init(video: VideoRecording? = nil) {
        self.video = video
    }
    
    func loadVideo(_ video: VideoRecording) {
        self.video = video
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

#Preview {
    VideoEditorView(viewModel: VideoEditorViewModel())
        .frame(width: 800, height: 600)
}

#endif
