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
    @ObservedObject var viewModel: VideoEditorViewModel

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
        if context.coordinator.player == nil {
            let player = AVPlayer()
            player.automaticallyWaitsToMinimizeStalling = true
            context.coordinator.player = player
            context.coordinator.videoURL = videoURL
        }

        guard let player = context.coordinator.player else { return }

        if let item = viewModel.previewItem, player.currentItem !== item {
            let wasPlaying = player.rate > 0
            player.replaceCurrentItem(with: item)
            player.seek(to: CMTime(seconds: viewModel.currentTime, preferredTimescale: 1000),
                        toleranceBefore: .zero, toleranceAfter: .zero)
            if wasPlaying { player.play() }
        }

        if nsView.player !== player {
            nsView.player = player
        }

        viewModel.setPlayer(player)
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        nsView.player = nil
    }
}

#endif
