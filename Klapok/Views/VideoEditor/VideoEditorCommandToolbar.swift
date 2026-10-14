//
//  VideoEditorCommandToolbar.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit

struct VideoEditorCommandToolbar: ToolbarContent {
    @ObservedObject var viewModel: VideoEditorViewModel
    @ObservedObject var exportManager: ExportManager

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
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
                Label("Share".localized, systemImage: "square.and.arrow.up")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(viewModel.video == nil || viewModel.isExporting)
            .help("Share video".localized)

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
                Label("Export".localized, systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
                    .opacity(viewModel.isExporting ? 0 : 1)
                    .overlay { if viewModel.isExporting { ProgressView().controlSize(.small) } }
            }
            .disabled(viewModel.isExporting || viewModel.video == nil)
            .accessibilityIdentifier("video.export")
            .help("Export as %@".localized(with: exportManager.settings.exportType.displayName.localized))
            .contextMenu {
                if let url = viewModel.exportedURL {
                    Button("Show in Finder".localized) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
            }
            Button { viewModel.copyExportToClipboard() } label: {
                Label("Copy file".localized, systemImage: "doc.on.doc").labelStyle(.titleAndIcon)
            }
            .disabled(viewModel.exportedURL == nil || viewModel.isExporting)
            .accessibilityIdentifier("video.copyExport")
            .accessibilityValue(viewModel.copiedExport ? "copied" : "ready")
            Button { viewModel.showExportInFinder() } label: {
                Label("Show in Finder".localized, systemImage: "folder").labelStyle(.titleAndIcon)
            }
            .disabled(viewModel.exportedURL == nil || viewModel.isExporting)
            .accessibilityIdentifier("video.showExport")
        }
    }
}

#endif
