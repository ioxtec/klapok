//
//  VideoEditorCommandToolbar.swift
//  Klapok
//

import SwiftUI

#if os(macOS)

struct VideoEditorCommandToolbar: ToolbarContent {
    @ObservedObject var viewModel: VideoEditorViewModel
    @ObservedObject var exportManager: ExportManager

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            KlapokToolbarBrandMark()
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { viewModel.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!viewModel.canUndo).keyboardShortcut("z", modifiers: .command).help("Undo".localized)
            Button { viewModel.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!viewModel.canRedo).keyboardShortcut("z", modifiers: [.command, .shift]).help("Redo".localized)
            Menu("Trim".localized) {
                Button("Keep before playhead".localized) { viewModel.keepBeforePlayhead() }
                Button("Keep after playhead".localized) { viewModel.keepAfterPlayhead() }
            }
            Button {
                Task {
                    await viewModel.exportTrimmedVideo(settings: exportManager.effectiveVideoSettings())
                    if viewModel.exportedURL != nil { viewModel.shareVideo() }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(viewModel.video == nil || viewModel.isExporting)
            .help("Share video".localized)

            Button {
                viewModel.openInFinder()
            } label: {
                Image(systemName: "folder")
            }
            .disabled(viewModel.video == nil)
            .help("Show in Finder".localized)

            Button {
                Task {
                    if exportManager.settings.exportType == .video {
                        await viewModel.exportTrimmedVideo(
                            settings: exportManager.effectiveVideoSettings()
                        )
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
            .help("Export as %@".localized(with: exportManager.settings.exportType.displayName.localized))

            Button(role: .destructive) {
                viewModel.deleteVideo()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.video == nil)
            .help("Delete video".localized)
        }
    }
}

#endif
