//
//  VideoPlayerView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit
import AVFoundation
import AVKit

struct VideoPlayerView: NSViewRepresentable {
    let videoURL: URL
    let viewModel: VideoEditorViewModel

    final class Coordinator {
        var player: AVPlayer?
        var videoURL: URL?
        var statusObservation: NSKeyValueObservation?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        playerView.controlsStyle = .floating
        playerView.showsFrameSteppingButtons = true
        playerView.showsSharingServiceButton = true
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if context.coordinator.videoURL != videoURL || context.coordinator.player == nil {
            let asset = AVURLAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = true
            context.coordinator.statusObservation = item.observe(\.status, options: [.new]) { item, _ in
                if item.status == .failed {
                    Logger.e("VideoPlayerView: Player item failed: \(item.error?.localizedDescription ?? "Unknown error")")
                }
            }
            context.coordinator.player = player
            context.coordinator.videoURL = videoURL
        }

        guard let player = context.coordinator.player else { return }

        if nsView.player !== player {
            nsView.player = player
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        viewModel.setPlayer(player)
    }
}

#endif
