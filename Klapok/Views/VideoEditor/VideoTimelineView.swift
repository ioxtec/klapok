//
//  VideoTimelineView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

struct VideoTimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel

    private let headerHeight: CGFloat = 28
    private let trackSpacing: CGFloat = 6
    private let overlayTrackHeight: CGFloat = 34
    private let videoTrackHeight: CGFloat = 66
    private let audioTrackHeight: CGFloat = 34
    private let compactToolbarBreakpoint: CGFloat = 1240
    private let minimumSidebarWidth: CGFloat = 132
    private let maximumSidebarWidth: CGFloat = 220
    private let timelineHorizontalInset: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width)

            VStack(spacing: 10) {
                timelineToolbar(availableWidth: availableWidth)

                GeometryReader { contentGeometry in
                    let contentWidth = max(0, contentGeometry.size.width)
                    let sidebarWidth = min(
                        max(viewModel.timelineSidebarWidth, minimumSidebarWidth),
                        min(maximumSidebarWidth, max(minimumSidebarWidth, contentWidth * 0.22))
                    )
                    let dividerWidth: CGFloat = 8
                    let rightColumnWidth = max(1, contentWidth - sidebarWidth - dividerWidth)
                    let pixelsPerSecond = CGFloat(72 * viewModel.zoomScale)
                    let visibleTimelineWidth = max(1, rightColumnWidth - (timelineHorizontalInset * 2))
                    let timelineContentWidth = max(
                        visibleTimelineWidth,
                        CGFloat(max(viewModel.editedDuration, 1)) * pixelsPerSecond
                    )
                    let rowKinds = timelineRowKinds

                    HStack(spacing: 0) {
                        timelineSidebar(
                            width: sidebarWidth,
                            rowKinds: rowKinds
                        )

                        TimelineSidebarResizer(viewModel: viewModel)

                        timelineCanvas(
                            visibleWidth: rightColumnWidth,
                            contentWidth: timelineContentWidth,
                            showsIndicators: timelineContentWidth > visibleTimelineWidth + 1,
                            pixelsPerSecond: pixelsPerSecond,
                            rowKinds: rowKinds
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.012))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.045), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .task(id: timelineLoadID(width: timelineContentWidth)) {
                        await viewModel.loadTimelineThumbnails(for: timelineContentWidth)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.018))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            }
        }
    }

    private func timelineToolbar(availableWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            timelineToolbarExpanded

            timelineToolbarCompact(forceStacked: availableWidth < compactToolbarBreakpoint)
        }
    }

    private func timelineSidebar(
        width: CGFloat,
        rowKinds: [TimelineRowKind]
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracks")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Layers and clip order")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.addOverlayTrack()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
                .help("Add a new annotation layer")
            }
            .frame(height: headerHeight, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 10)

            VStack(spacing: trackSpacing) {
                ForEach(rowKinds) { row in
                    TimelineSidebarRow(
                        row: row,
                        height: row.height
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(width: width, alignment: .topLeading)
        .background(Color.white.opacity(0.018))
        .overlay {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func timelineCanvas(
        visibleWidth: CGFloat,
        contentWidth: CGFloat,
        showsIndicators: Bool,
        pixelsPerSecond: CGFloat,
        rowKinds: [TimelineRowKind]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: trackSpacing) {
                    TimelineRulerBar(
                        duration: viewModel.editedDuration,
                        width: contentWidth,
                        pixelsPerSecond: pixelsPerSecond,
                        onScrub: { x in
                            viewModel.updateCurrentTime(
                                to: editedTime(for: x, pixelsPerSecond: pixelsPerSecond)
                            )
                        }
                    )
                    .frame(width: contentWidth, height: headerHeight)

                    ForEach(rowKinds) { row in
                        timelineRowView(
                            for: row,
                            contentWidth: contentWidth,
                            pixelsPerSecond: pixelsPerSecond
                        )
                    }
                }

                TimelinePlayheadOverlay(
                    x: viewModel.currentTime * pixelsPerSecond,
                    height: totalTimelineHeight(for: rowKinds),
                    topInset: 6
                )
            }
            .frame(width: contentWidth, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, timelineHorizontalInset)
        }
        .frame(width: visibleWidth)
        .background(Color.white.opacity(0.006))
    }

    @ViewBuilder
    private func timelineRowView(
        for row: TimelineRowKind,
        contentWidth: CGFloat,
        pixelsPerSecond: CGFloat
    ) -> some View {
        switch row.kind {
        case .overlay:
            TimelineOverlayLane(
                title: row.title,
                width: contentWidth,
                height: row.height,
                start: row.overlay?.start ?? 0,
                end: row.overlay?.end ?? 0,
                pixelsPerSecond: pixelsPerSecond
            )
        case .video:
            TimelineClipLane(
                clips: viewModel.clips,
                selectedClipIDs: viewModel.selectedClipIDs,
                width: contentWidth,
                trackHeight: row.height,
                pixelsPerSecond: pixelsPerSecond,
                clipThumbnails: { clip, count in
                    viewModel.clipThumbnails(for: clip, targetCount: count)
                },
                selectClip: { clipID in
                    let extend = NSApp.currentEvent?.modifierFlags.contains(.command) == true
                    viewModel.selectClip(clipID, extendSelection: extend)
                },
                moveClip: { clipID, beforeID in
                    viewModel.moveClip(clipID, before: beforeID)
                },
                draggedClipID: Binding(
                    get: { viewModel.draggedTimelineClipID },
                    set: { viewModel.draggedTimelineClipID = $0 }
                )
            )
        case .audio:
            TimelineAudioLane(
                clips: viewModel.clips,
                width: contentWidth,
                trackHeight: row.height,
                pixelsPerSecond: pixelsPerSecond,
                levels: { clip, count in
                    viewModel.audioLevels(for: clip, sampleCount: count)
                }
            )
        }
    }

    private var timelineRowKinds: [TimelineRowKind] {
        var rows = viewModel.overlayTracks.map {
            TimelineRowKind(
                title: $0.title,
                subtitle: $0.kind == .text ? "Text / arrows" : "Callouts",
                kind: .overlay,
                height: overlayTrackHeight,
                overlay: $0
            )
        }

        rows.append(
            TimelineRowKind(
                title: "Video 1",
                subtitle: "Clips",
                kind: .video,
                height: videoTrackHeight
            )
        )
        rows.append(
            TimelineRowKind(
                title: "Audio 1",
                subtitle: "Waveform",
                kind: .audio,
                height: audioTrackHeight
            )
        )
        return rows
    }

    private func totalTimelineHeight(for rows: [TimelineRowKind]) -> CGFloat {
        headerHeight + rows.map(\.height).reduce(0, +) + CGFloat(rows.count) * trackSpacing + 10
    }

    private var timelineToolbarExpanded: some View {
        HStack(spacing: 10) {
            timelineActionGroup

            Spacer(minLength: 12)

            timelineMetricsGroup

            Spacer(minLength: 12)

            timelineRangeAndZoomGroup
        }
    }

    private func timelineToolbarCompact(forceStacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if forceStacked {
                timelineActionGroup
                timelineRangeAndZoomGroup
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        timelineActionGroup
                        Spacer(minLength: 12)
                        timelineRangeAndZoomGroup
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        timelineActionGroup
                        timelineRangeAndZoomGroup
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    timelineMetricsGroup
                    Spacer(minLength: 12)
                    timelineActiveRangeView
                }

                VStack(alignment: .leading, spacing: 8) {
                    timelineMetricsGroup
                    timelineActiveRangeView
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var timelineActionGroup: some View {
        HStack(spacing: 6) {
            TimelineToolButton(
                title: "Undo",
                systemImage: "arrow.uturn.backward",
                isDisabled: !viewModel.canUndo
            ) {
                viewModel.undo()
            }

            TimelineToolButton(
                title: "Redo",
                systemImage: "arrow.uturn.forward",
                isDisabled: !viewModel.canRedo
            ) {
                viewModel.redo()
            }

            Divider()
                .frame(height: 16)
                .overlay(Color.white.opacity(0.06))

            TimelineToolButton(
                title: "Split",
                systemImage: "scissors",
                isDisabled: !viewModel.canSplit,
                prominent: true
            ) {
                viewModel.splitAtPlayhead()
            }

            TimelineToolButton(
                title: "Merge",
                systemImage: "link",
                isDisabled: !viewModel.canMerge
            ) {
                viewModel.mergeSelectedClips()
            }

            TimelineToolButton(
                title: "Remove",
                systemImage: "trash",
                isDisabled: !viewModel.canRemove
            ) {
                viewModel.removeSelectedClips()
            }

            TimelineToolButton(
                title: "Reset",
                systemImage: "arrow.counterclockwise",
                isDisabled: !viewModel.canResetTimeline
            ) {
                viewModel.resetTimeline()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var timelineMetricsGroup: some View {
        HStack(spacing: 8) {
            TimelineMetricTile(
                title: "Source",
                value: formatTime(viewModel.sourceDuration),
                accent: Color(red: 0.23, green: 0.67, blue: 0.98)
            )

            TimelineMetricTile(
                title: "Selection",
                value: formatTime(max(viewModel.selectedDuration, 0)),
                accent: Color(red: 0.06, green: 0.72, blue: 0.59)
            )

            TimelineMetricTile(
                title: "Output",
                value: formatTime(viewModel.editedDuration),
                accent: Color(red: 0.96, green: 0.55, blue: 0.16)
            )
        }
    }

    private var timelineRangeAndZoomGroup: some View {
        HStack(spacing: 8) {
            timelineActiveRangeView

            TimelineToolButton(
                title: "Zoom out",
                systemImage: "minus.magnifyingglass",
                isDisabled: !viewModel.canZoomOut
            ) {
                viewModel.zoomOut()
            }

            Slider(
                value: Binding(
                    get: { viewModel.zoomScale },
                    set: { viewModel.updateZoomScale($0) }
                ),
                in: 0.55...3.5
            )
            .frame(minWidth: 84, idealWidth: 112, maxWidth: 132)
            .controlSize(.small)
            .tint(Color(red: 0.06, green: 0.82, blue: 0.72))

            TimelineToolButton(
                title: "Zoom in",
                systemImage: "plus.magnifyingglass",
                isDisabled: !viewModel.canZoomIn
            ) {
                viewModel.zoomIn()
            }
        }
    }

    private var timelineActiveRangeView: some View {
        Group {
            if let range = viewModel.activeTimelineRange {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active range")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("\(formatTime(range.start)) - \(formatTime(range.end))")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func editedTime(for x: CGFloat, pixelsPerSecond: CGFloat) -> TimeInterval {
        guard pixelsPerSecond > 0 else { return 0 }
        return min(viewModel.editedDuration, max(0, Double(x / pixelsPerSecond)))
    }

    private func timelineLoadID(width: CGFloat) -> String {
        "\(viewModel.video?.url.path ?? "none")-\(Int(width))-\(viewModel.clips.count)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let clamped = max(0, time)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        let tenths = Int((clamped - floor(clamped)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private struct TimelineRowKind: Identifiable {
    enum Kind {
        case overlay
        case video
        case audio
    }

    let id = UUID()
    let title: String
    let subtitle: String
    let kind: Kind
    let height: CGFloat
    var overlay: TimelineOverlayTrack? = nil
}

private struct TimelineSidebarRow: View {
    let row: TimelineRowKind
    let height: CGFloat

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                Text(row.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(height: height)
    }

    private var iconName: String {
        switch row.kind {
        case .overlay:
            return "character.cursor.ibeam"
        case .video:
            return "film.stack"
        case .audio:
            return "waveform"
        }
    }
}

private struct TimelineSidebarResizer: View {
    @ObservedObject var viewModel: VideoEditorViewModel

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.05))
                .frame(width: 1)

            Rectangle()
                .fill(.clear)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    viewModel.timelineSidebarWidth = min(
                        max(132, viewModel.timelineSidebarResizeAnchor + value.translation.width),
                        220
                    )
                }
                .onEnded { _ in
                    viewModel.timelineSidebarResizeAnchor = viewModel.timelineSidebarWidth
                }
        )
        .onHover { hovering in
            if hovering {
                viewModel.timelineSidebarResizeAnchor = viewModel.timelineSidebarWidth
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

private struct TimelineToolButton: View {
    let title: String
    let systemImage: String
    let isDisabled: Bool
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, prominent ? 10 : 8)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.55) : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    prominent
                        ? Color(red: 0.98, green: 0.56, blue: 0.17).opacity(isDisabled ? 0.12 : 0.88)
                        : Color.white.opacity(isDisabled ? 0.018 : 0.035)
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(prominent ? 0.06 : 0.05), lineWidth: 1)
        }
        .disabled(isDisabled)
        .help(title)
    }
}

private struct TimelineMetricTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 9, height: 9)

                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
    }
}

private struct TimelineRulerBar: View {
    let duration: TimeInterval
    let width: CGFloat
    let pixelsPerSecond: CGFloat
    let onScrub: (CGFloat) -> Void

    var body: some View {
        GeometryReader { _ in
            let majorStep = majorTickStep
            let minorStep = majorStep / 5

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.012))

                ForEach(Array(stride(from: 0.0, through: max(duration, 0), by: minorStep)), id: \.self) { tick in
                    let x = CGFloat(tick) * pixelsPerSecond
                    let isMajor = tick.truncatingRemainder(dividingBy: majorStep) == 0

                    Rectangle()
                        .fill(Color.white.opacity(isMajor ? 0.3 : 0.12))
                        .frame(width: 1, height: isMajor ? 12 : 6)
                        .offset(x: x, y: isMajor ? 14 : 18)
                }

                ForEach(Array(stride(from: 0.0, through: max(duration, 0), by: majorStep)), id: \.self) { tick in
                    Text(formatTime(tick))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .offset(x: CGFloat(tick) * pixelsPerSecond + 4, y: -1)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onScrub(max(0, min(width, value.location.x)))
                }
        )
    }

    private var majorTickStep: TimeInterval {
        switch pixelsPerSecond {
        case ..<40:
            return 10
        case ..<80:
            return 5
        case ..<160:
            return 2
        default:
            return 1
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = Int(time.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct TimelineOverlayLane: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let start: Double
    let end: Double
    let pixelsPerSecond: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.012))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.white.opacity(0.05))
            }
            .overlay(alignment: .leading) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip")
                    Text(title).lineLimit(1)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(width: max(24, CGFloat(max(0, end - start)) * pixelsPerSecond), height: height)
                .background(Color.accentColor.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                .offset(x: CGFloat(start) * pixelsPerSecond)
            }
    }
}

private struct TimelineClipLane: View {
    let clips: [VideoTimelineClip]
    let selectedClipIDs: Set<UUID>
    let width: CGFloat
    let trackHeight: CGFloat
    let pixelsPerSecond: CGFloat
    let clipThumbnails: (VideoTimelineClip, Int) -> [NSImage]
    let selectClip: (UUID) -> Void
    let moveClip: (UUID, UUID?) -> Void
    @Binding var draggedClipID: UUID?

    var body: some View {
        HStack(spacing: 1) {
            ForEach(clips) { clip in
                TimelineVideoClipCell(
                    clip: clip,
                    width: max(48, CGFloat(clip.duration) * pixelsPerSecond),
                    height: trackHeight,
                    thumbnails: clipThumbnails(clip, max(3, Int(CGFloat(clip.duration) * pixelsPerSecond / 64))),
                    isSelected: selectedClipIDs.contains(clip.id),
                    onSelect: {
                        selectClip(clip.id)
                    }
                )
                .onDrag {
                    draggedClipID = clip.id
                    return NSItemProvider(object: clip.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: TimelineClipDropDelegate(
                        destinationID: clip.id,
                        draggedClipID: $draggedClipID,
                        moveClip: moveClip
                    )
                )
            }

            Rectangle()
                .fill(Color.clear)
                .frame(width: max(20, width - clipWidthsSum))
                .onDrop(
                    of: [UTType.text],
                    delegate: TimelineClipDropDelegate(
                        destinationID: nil,
                        draggedClipID: $draggedClipID,
                        moveClip: moveClip
                    )
                )
        }
        .frame(width: width, height: trackHeight, alignment: .leading)
        .padding(1)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.012))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
    }

    private var clipWidthsSum: CGFloat {
        clips.reduce(0) { $0 + max(48, CGFloat($1.duration) * pixelsPerSecond) + 1 } - (clips.isEmpty ? 0 : 1)
    }
}

private struct TimelineVideoClipCell: View {
    let clip: VideoTimelineClip
    let width: CGFloat
    let height: CGFloat
    let thumbnails: [NSImage]
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                clipFill

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 10))
                    Text(clip.name)
                        .lineLimit(1)
                }
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(4)
            }
            .frame(height: max(36, height - 16))

        }
        .frame(width: width, height: height)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.4, blue: 0.36),
                    Color(red: 0.03, green: 0.48, blue: 0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(
                    isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.04),
                    lineWidth: isSelected ? 1.6 : 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var clipFill: some View {
        if thumbnails.isEmpty {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width / CGFloat(max(1, thumbnails.count)))
                        .clipped()
                }
            }
        }
    }

}

private struct TimelineAudioLane: View {
    let clips: [VideoTimelineClip]
    let width: CGFloat
    let trackHeight: CGFloat
    let pixelsPerSecond: CGFloat
    let levels: (VideoTimelineClip, Int) -> [CGFloat]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(clips) { clip in
                TimelineAudioClipCell(
                    width: max(48, CGFloat(clip.duration) * pixelsPerSecond),
                    height: max(16, trackHeight - 10),
                    levels: levels(clip, max(14, Int(CGFloat(clip.duration) * pixelsPerSecond / 9)))
                )
            }

            Rectangle()
                .fill(Color.clear)
                .frame(width: max(20, width - clipWidthsSum))
        }
        .frame(width: width, height: trackHeight, alignment: .leading)
        .padding(1)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.01))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
    }

    private var clipWidthsSum: CGFloat {
        clips.reduce(0) { $0 + max(48, CGFloat($1.duration) * pixelsPerSecond) + 1 } - (clips.isEmpty ? 0 : 1)
    }
}

private struct TimelineAudioClipCell: View {
    let width: CGFloat
    let height: CGFloat
    let levels: [CGFloat]

    var body: some View {
        TimelineMiniWaveform(levels: levels)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.018))
            )
    }
}

private struct TimelineMiniWaveform: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1.2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Color(red: 0.28, green: 0.88, blue: 0.84).opacity(0.9))
                        .frame(
                            width: max(1.2, geometry.size.width / CGFloat(max(1, levels.count)) - 1.2),
                            height: max(2, geometry.size.height * min(1, level))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct TimelinePlayheadOverlay: View {
    let x: CGFloat
    let height: CGFloat
    let topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 1.0, green: 0.34, blue: 0.4))
                .frame(width: 14, height: 10)

            Rectangle()
                .fill(Color(red: 1.0, green: 0.34, blue: 0.4))
                .frame(width: 1.5, height: max(0, height - 10))
        }
        .offset(x: max(0, x - 7), y: topInset)
        .allowsHitTesting(false)
    }
}

private struct TimelineClipDropDelegate: DropDelegate {
    let destinationID: UUID?
    @Binding var draggedClipID: UUID?
    let moveClip: (UUID, UUID?) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedClipID else { return }
        moveClip(draggedClipID, destinationID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedClipID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#endif
