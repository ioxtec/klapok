//
//  ScreenshotReviewOverlay.swift
//  Fluttro
//
//  Quick post-capture review thumbnail
//

import SwiftUI

#if os(macOS)
    import AppKit
    import AVFoundation

    @MainActor
    final class ScreenshotReviewPresenter {
        static let shared = ScreenshotReviewPresenter()

        private var window: ScreenshotReviewPanel?
        private var didFinish = false

        private init() {}

        func present(
            image: NSImage,
            sourceRect: NSRect?,
            onEdit: @escaping (NSImage) -> Void
        ) {
            finishCurrentReview()

            let screen = screen(for: sourceRect) ?? NSScreen.main
            guard let screen else {
                onEdit(image)
                return
            }

            didFinish = false

            let panel = ScreenshotReviewPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
            panel.level = NSWindow.Level(
                rawValue: WindowDepthManager.shared.level(for: .pinnedFloatingPanel).rawValue + 20
            )

            let contentView = ScreenshotReviewOverlayView(
                image: image,
                sourceRect: sourceRect ?? screen.frame,
                screenFrame: screen.frame,
                position: AppSettings.shared.screenshotReviewPosition,
                onCopy: { [weak self] in
                    self?.finish {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.writeObjects([image])
                    }
                },
                onEdit: { [weak self] in
                    self?.finish {
                        onEdit(image)
                    }
                },
                onSave: { [weak self] in
                    self?.finish {
                        _ = AppSettings.shared.saveScreenshot(image)
                    }
                },
                onCancel: { [weak self] in
                    self?.finish {}
                }
            )

            panel.contentView = NSHostingView(rootView: contentView)
            panel.orderFrontRegardless()
            window = panel
        }

        private func finishCurrentReview() {
            guard let window else { return }
            window.close()
            self.window = nil
        }

        private func finish(_ action: () -> Void) {
            guard !didFinish else { return }
            didFinish = true
            finishCurrentReview()
            action()
        }

        private func screen(for rect: NSRect?) -> NSScreen? {
            guard let rect, !rect.isEmpty else { return NSScreen.main }

            return NSScreen.screens.first { screen in
                screen.frame.intersects(rect)
            } ?? NSScreen.main
        }
    }

    private final class ScreenshotReviewPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    @MainActor
    private final class ScreenshotReviewOverlayState: ObservableObject {
        @Published var isMinimized = false
        @Published var showActions = false
        @Published var autoSaveTask: Task<Void, Never>?
    }

    private struct ScreenshotReviewOverlayView: View {
        let image: NSImage
        let sourceRect: NSRect
        let screenFrame: NSRect
        let position: ScreenshotReviewPosition
        let onCopy: () -> Void
        let onEdit: () -> Void
        let onSave: () -> Void
        let onCancel: () -> Void

        @StateObject private var viewState = ScreenshotReviewOverlayState()

        private var isMinimized: Bool {
            get { viewState.isMinimized }
            nonmutating set { viewState.isMinimized = newValue }
        }

        private var showActions: Bool {
            get { viewState.showActions }
            nonmutating set { viewState.showActions = newValue }
        }

        private var autoSaveTask: Task<Void, Never>? {
            get { viewState.autoSaveTask }
            nonmutating set { viewState.autoSaveTask = newValue }
        }

        var body: some View {
            GeometryReader { geometry in
                let targetRect = thumbnailRect(in: geometry.size)
                let currentRect = isMinimized ? targetRect : sourceRectInView

                ZStack {
                    Color.clear

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: currentRect.width, height: currentRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: isMinimized ? 8 : 0))
                        .shadow(color: .black.opacity(isMinimized ? 0.35 : 0), radius: 18, y: 8)
                        .position(x: currentRect.midX, y: currentRect.midY)

                    HStack(spacing: 6) {
                        ScreenshotReviewActionButton(
                            systemImage: "doc.on.doc",
                            help: "Copy to clipboard",
                            action: onCopy
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "pencil",
                            help: "Edit",
                            action: onEdit
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "square.and.arrow.down",
                            help: "Save",
                            action: onSave
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "xmark",
                            help: "Cancel",
                            action: onCancel
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .opacity(showActions ? 1 : 0)
                    .position(actionsPosition(for: targetRect))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    isMinimized = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showActions = true
                    }
                }

                autoSaveTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { return }
                    onSave()
                }
            }
            .onDisappear {
                autoSaveTask?.cancel()
                autoSaveTask = nil
            }
        }

        private var sourceRectInView: CGRect {
            let converted = CGRect(
                x: sourceRect.minX - screenFrame.minX,
                y: screenFrame.maxY - sourceRect.maxY,
                width: max(sourceRect.width, 1),
                height: max(sourceRect.height, 1)
            )
            let bounds = CGRect(origin: .zero, size: screenFrame.size)
            let clipped = converted.intersection(bounds)

            if clipped.isNull || clipped.isEmpty {
                return bounds
            }

            return clipped
        }

        private func thumbnailRect(in size: CGSize) -> CGRect {
            let thumbnailSize = fittedThumbnailSize
            let margin: CGFloat = 28
            let actionClearance: CGFloat = 58

            switch position {
            case .bottomRight:
                return CGRect(
                    x: size.width - thumbnailSize.width - margin,
                    y: size.height - thumbnailSize.height - margin,
                    width: thumbnailSize.width,
                    height: thumbnailSize.height
                )
            case .bottomLeft:
                return CGRect(
                    x: margin,
                    y: size.height - thumbnailSize.height - margin,
                    width: thumbnailSize.width,
                    height: thumbnailSize.height
                )
            case .topRight:
                return CGRect(
                    x: size.width - thumbnailSize.width - margin,
                    y: margin + actionClearance,
                    width: thumbnailSize.width,
                    height: thumbnailSize.height
                )
            case .topLeft:
                return CGRect(
                    x: margin,
                    y: margin + actionClearance,
                    width: thumbnailSize.width,
                    height: thumbnailSize.height
                )
            case .bottomCenter:
                return CGRect(
                    x: (size.width - thumbnailSize.width) / 2,
                    y: size.height - thumbnailSize.height - margin,
                    width: thumbnailSize.width,
                    height: thumbnailSize.height
                )
            }
        }

        private var fittedThumbnailSize: CGSize {
            let maxSize = CGSize(width: 240, height: 150)
            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else {
                return maxSize
            }

            let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height)
            return CGSize(
                width: max(96, imageSize.width * scale),
                height: max(54, imageSize.height * scale)
            )
        }

        private func actionsPosition(for targetRect: CGRect) -> CGPoint {
            let isNearTop = targetRect.minY < 70
            let y = isNearTop ? targetRect.maxY + 24 : targetRect.minY - 24
            return CGPoint(x: targetRect.midX, y: y)
        }
    }

    private struct ScreenshotReviewActionButton: View {
        let systemImage: String
        let help: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
            .help(help)
        }
    }

    @MainActor
    final class VideoReviewPresenter {
        static let shared = VideoReviewPresenter()

        private var window: ScreenshotReviewPanel?
        private var didFinish = false

        private init() {}

        func present(
            recording: VideoRecording,
            sourceRect: NSRect?,
            onCopy: @escaping (VideoRecording) -> Void,
            onEdit: @escaping (VideoRecording) -> Void,
            onSave: @escaping (VideoRecording) -> Void,
            onCancel: @escaping (VideoRecording) -> Void
        ) {
            Task { @MainActor [weak self] in
                await self?.presentAsync(
                    recording: recording,
                    sourceRect: sourceRect,
                    onCopy: onCopy,
                    onEdit: onEdit,
                    onSave: onSave,
                    onCancel: onCancel
                )
            }
        }

        private func presentAsync(
            recording: VideoRecording,
            sourceRect: NSRect?,
            onCopy: @escaping (VideoRecording) -> Void,
            onEdit: @escaping (VideoRecording) -> Void,
            onSave: @escaping (VideoRecording) -> Void,
            onCancel: @escaping (VideoRecording) -> Void
        ) async {
            finishCurrentReview()

            let screen = screen(for: sourceRect) ?? NSScreen.main
            guard let screen else {
                onEdit(recording)
                return
            }

            didFinish = false

            let panel = ScreenshotReviewPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
            panel.level = NSWindow.Level(
                rawValue: WindowDepthManager.shared.level(for: .pinnedFloatingPanel).rawValue + 20
            )

            let previewImage = (try? await thumbnail(for: recording)) ?? genericVideoPreview()
            let contentView = VideoReviewOverlayView(
                image: previewImage,
                sourceRect: sourceRect ?? screen.frame,
                screenFrame: screen.frame,
                position: AppSettings.shared.screenshotReviewPosition,
                onCopy: { [weak self] in
                    self?.finish { onCopy(recording) }
                },
                onEdit: { [weak self] in
                    self?.finish { onEdit(recording) }
                },
                onSave: { [weak self] in
                    self?.finish { onSave(recording) }
                },
                onCancel: { [weak self] in
                    self?.finish { onCancel(recording) }
                }
            )

            panel.contentView = NSHostingView(rootView: contentView)
            panel.orderFrontRegardless()
            window = panel
        }

        private func finishCurrentReview() {
            guard let window else { return }
            window.close()
            self.window = nil
        }

        private func finish(_ action: () -> Void) {
            guard !didFinish else { return }
            didFinish = true
            finishCurrentReview()
            action()
        }

        private func screen(for rect: NSRect?) -> NSScreen? {
            guard let rect, !rect.isEmpty else { return NSScreen.main }

            return NSScreen.screens.first { screen in
                screen.frame.intersects(rect)
            } ?? NSScreen.main
        }

        private func thumbnail(for recording: VideoRecording) async throws -> NSImage {
            let asset = AVURLAsset(url: recording.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let requestedTime = CMTime(seconds: min(0.1, max(recording.duration * 0.05, 0.0)), preferredTimescale: 600)
            let cgImage = try await generator.image(at: requestedTime).image
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }

        private func genericVideoPreview() -> NSImage {
            let size = NSSize(width: 320, height: 180)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.windowBackgroundColor.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size.width, height: size.height), xRadius: 18, yRadius: 18).fill()

            let iconConfig = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            let icon = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)?.withSymbolConfiguration(iconConfig)
            icon?.draw(
                in: NSRect(x: (size.width - 52) / 2, y: (size.height - 40) / 2, width: 52, height: 40)
            )
            image.unlockFocus()
            return image
        }
    }

    private struct VideoReviewOverlayView: View {
        let image: NSImage
        let sourceRect: NSRect
        let screenFrame: NSRect
        let position: ScreenshotReviewPosition
        let onCopy: () -> Void
        let onEdit: () -> Void
        let onSave: () -> Void
        let onCancel: () -> Void

        @StateObject private var viewState = ScreenshotReviewOverlayState()

        private var isMinimized: Bool {
            get { viewState.isMinimized }
            nonmutating set { viewState.isMinimized = newValue }
        }

        private var showActions: Bool {
            get { viewState.showActions }
            nonmutating set { viewState.showActions = newValue }
        }

        private var autoSaveTask: Task<Void, Never>? {
            get { viewState.autoSaveTask }
            nonmutating set { viewState.autoSaveTask = newValue }
        }

        var body: some View {
            GeometryReader { geometry in
                let targetRect = thumbnailRect(in: geometry.size)
                let currentRect = isMinimized ? targetRect : sourceRectInView

                ZStack {
                    Color.clear

                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: currentRect.width, height: currentRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: isMinimized ? 10 : 0))
                        .shadow(color: .black.opacity(isMinimized ? 0.35 : 0), radius: 18, y: 8)
                        .position(x: currentRect.midX, y: currentRect.midY)

                    HStack(spacing: 6) {
                        ScreenshotReviewActionButton(
                            systemImage: "doc.on.doc",
                            help: "Copy video file",
                            action: onCopy
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "pencil",
                            help: "Open in editor",
                            action: onEdit
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "square.and.arrow.down",
                            help: "Save video",
                            action: onSave
                        )

                        ScreenshotReviewActionButton(
                            systemImage: "xmark",
                            help: "Discard",
                            action: onCancel
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .opacity(showActions ? 1 : 0)
                    .position(actionsPosition(for: targetRect))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    isMinimized = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showActions = true
                    }
                }

                autoSaveTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    guard !Task.isCancelled else { return }
                    onSave()
                }
            }
            .onDisappear {
                autoSaveTask?.cancel()
                autoSaveTask = nil
            }
        }

        private var sourceRectInView: CGRect {
            let converted = CGRect(
                x: sourceRect.minX - screenFrame.minX,
                y: screenFrame.maxY - sourceRect.maxY,
                width: max(sourceRect.width, 1),
                height: max(sourceRect.height, 1)
            )
            let bounds = CGRect(origin: .zero, size: screenFrame.size)
            let clipped = converted.intersection(bounds)

            if clipped.isNull || clipped.isEmpty {
                return bounds
            }

            return clipped
        }

        private func thumbnailRect(in size: CGSize) -> CGRect {
            let thumbnailSize = fittedThumbnailSize
            let margin: CGFloat = 28
            let actionClearance: CGFloat = 58

            switch position {
            case .bottomRight:
                return CGRect(x: size.width - thumbnailSize.width - margin, y: size.height - thumbnailSize.height - margin, width: thumbnailSize.width, height: thumbnailSize.height)
            case .bottomLeft:
                return CGRect(x: margin, y: size.height - thumbnailSize.height - margin, width: thumbnailSize.width, height: thumbnailSize.height)
            case .topRight:
                return CGRect(x: size.width - thumbnailSize.width - margin, y: margin + actionClearance, width: thumbnailSize.width, height: thumbnailSize.height)
            case .topLeft:
                return CGRect(x: margin, y: margin + actionClearance, width: thumbnailSize.width, height: thumbnailSize.height)
            case .bottomCenter:
                return CGRect(x: (size.width - thumbnailSize.width) / 2, y: size.height - thumbnailSize.height - margin, width: thumbnailSize.width, height: thumbnailSize.height)
            }
        }

        private var fittedThumbnailSize: CGSize {
            let maxSize = CGSize(width: 240, height: 150)
            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else {
                return maxSize
            }

            let scale = min(maxSize.width / imageSize.width, maxSize.height / imageSize.height)
            return CGSize(
                width: max(120, imageSize.width * scale),
                height: max(68, imageSize.height * scale)
            )
        }

        private func actionsPosition(for targetRect: CGRect) -> CGPoint {
            let isNearTop = targetRect.minY < 70
            let y = isNearTop ? targetRect.maxY + 24 : targetRect.minY - 24
            return CGPoint(x: targetRect.midX, y: y)
        }
    }

#endif
