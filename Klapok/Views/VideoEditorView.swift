//
//  VideoEditorView.swift
//  Klapok
//
//  Video editor view for reviewing recorded videos
//

import SwiftUI

#if os(macOS)
import AppKit

struct VideoEditorView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @StateObject private var settings = AppSettings.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var exportManager = ExportManager.shared
    @StateObject private var languageManager = LanguageManager.shared

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
                GeometryReader { _ in
                    if let video = viewModel.video {
                        VideoPlayerView(videoURL: video.url, viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                    } else {
                        VideoEmptyStateView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))

                if viewModel.video != nil {
                    VideoTimelineView(viewModel: viewModel)
                        .frame(height: 258)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
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
        .id(languageManager.selectedLanguage.rawValue)
    }

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
            Logger.w("VideoEditorView: Could not read file size: \(error)")
        }
        return "Unknown".localized
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
            Logger.w("VideoEditorView: Could not read creation date: \(error)")
        }
        return "Unknown".localized
    }
}

private struct VideoEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Video Selected".localized)
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a video file to preview".localized)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#endif
