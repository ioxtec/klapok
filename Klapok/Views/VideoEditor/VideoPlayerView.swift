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

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        playerView.controlsStyle = .none
        playerView.showsFrameSteppingButtons = false
        playerView.showsSharingServiceButton = false
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let player = viewModel.synchronizedPreviewPlayer()

        if nsView.player !== player {
            nsView.player = player
        }
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        // A replacement view may already use the same model-owned player.
        // Detach only this presentation; the editor owns playback lifetime.
        nsView.player = nil
    }
}

#endif
