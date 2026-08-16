//
//  VideoTimelineView.swift
//  Klapok
//

import SwiftUI

#if os(macOS)
import AppKit

private enum TimelineDragMode {
    case trimStart
    case trimEnd
    case playhead
    case cutSelection
}

@MainActor
private final class VideoTimelineInteractionState: ObservableObject {
    @Published var dragMode: TimelineDragMode?
}

struct VideoTimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @StateObject private var interactionState = VideoTimelineInteractionState()

    private var dragMode: TimelineDragMode? {
        get { interactionState.dragMode }
        nonmutating set { interactionState.dragMode = newValue }
    }

    var body: some View {
        VStack(spacing: 10) {
            timelineHeader

            GeometryReader { geometry in
                let sidebarWidth: CGFloat = 104
                let columnSpacing: CGFloat = 10
                let rulerHeight: CGFloat = 38
                let videoTrackHeight: CGFloat = 44
                let audioTrackHeight: CGFloat = 12
                let trackSpacing: CGFloat = 4
                let trimHandleWidth: CGFloat = 6
                let rightColumnWidth = max(1, geometry.size.width - sidebarWidth - columnSpacing)
                let trackOffsetX = trimHandleWidth
                let trackWidth = max(1, rightColumnWidth - trimHandleWidth * 2)
                let interactionOutset: CGFloat = 18
                let playheadTopOutset: CGFloat = 16
                let trackTop: CGFloat = 16
                let mediaTrackHeight = videoTrackHeight + trackSpacing + audioTrackHeight
                let canvasHeight = trackTop + mediaTrackHeight + 16
                let videoTrackCornerRadius: CGFloat = 6
                let audioTrackCornerRadius: CGFloat = 4
                let panelCornerRadius: CGFloat = 10
                let clipAccent = Color(red: 0.06, green: 0.69, blue: 0.58)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: columnSpacing) {
                        TimelineTrackSidebar(
                            sidebarWidth: sidebarWidth,
                            rulerHeight: rulerHeight,
                            videoTrackHeight: videoTrackHeight,
                            audioTrackHeight: audioTrackHeight,
                            trackTop: trackTop,
                            trackSpacing: trackSpacing
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            TimelineRuler(duration: viewModel.video?.duration ?? 0)
                                .frame(width: trackWidth, height: rulerHeight)
                                .padding(.leading, trackOffsetX)

                            ZStack(alignment: .topLeading) {
                                TimelineCanvasBackground()

                                TimelineTrackLaneBackground(cornerRadius: videoTrackCornerRadius)
                                    .frame(width: trackWidth, height: videoTrackHeight)
                                    .offset(x: trackOffsetX, y: trackTop)

                                TimelineTrackLaneBackground(cornerRadius: audioTrackCornerRadius)
                                    .frame(width: trackWidth, height: audioTrackHeight)
                                    .offset(x: trackOffsetX, y: trackTop + videoTrackHeight + trackSpacing)

                                TimelineThumbnailStrip(
                                    thumbnails: viewModel.timelineThumbnails,
                                    isLoading: viewModel.isLoadingTimelineThumbnails
                                )
                                .frame(width: trackWidth, height: videoTrackHeight)
                                .clipShape(RoundedRectangle(cornerRadius: videoTrackCornerRadius, style: .continuous))
                                .offset(x: trackOffsetX, y: trackTop)
                                .zIndex(1)

                                TimelineAudioWaveform()
                                    .frame(width: trackWidth, height: audioTrackHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: audioTrackCornerRadius, style: .continuous))
                                    .offset(x: trackOffsetX, y: trackTop + videoTrackHeight + trackSpacing)
                                    .zIndex(1)

                                TimelineClipBadge(title: "Main Clip")
                                    .offset(x: trackOffsetX + 8, y: trackTop + 4)
                                    .zIndex(5)

                                TimelineSelectionFrame(
                                    start: viewModel.trimStartPercentage,
                                    end: viewModel.trimEndPercentage,
                                    width: trackWidth,
                                    height: mediaTrackHeight,
                                    cornerRadius: videoTrackCornerRadius,
                                    strokeColor: clipAccent
                                )
                                .offset(x: trackOffsetX, y: trackTop)
                                .allowsHitTesting(false)
                                .zIndex(3)

                                TimelineDimmedRegion(
                                    start: 0,
                                    end: viewModel.trimStartPercentage,
                                    width: trackWidth,
                                    height: mediaTrackHeight,
                                    cornerRadius: videoTrackCornerRadius
                                )
                                .offset(x: trackOffsetX, y: trackTop)
                                .allowsHitTesting(false)
                                .zIndex(2)

                                TimelineDimmedRegion(
                                    start: viewModel.trimEndPercentage,
                                    end: 1,
                                    width: trackWidth,
                                    height: mediaTrackHeight,
                                    cornerRadius: videoTrackCornerRadius
                                )
                                .offset(x: trackOffsetX, y: trackTop)
                                .allowsHitTesting(false)
                                .zIndex(2)

                                ForEach(viewModel.cutSegments) { cut in
                                    TimelineSegmentOverlay(
                                        start: percentage(for: cut.startTime),
                                        end: percentage(for: cut.endTime),
                                        width: trackWidth,
                                        height: mediaTrackHeight,
                                        color: .red,
                                        opacity: 0.22,
                                        cornerRadius: videoTrackCornerRadius
                                    )
                                    .offset(x: trackOffsetX, y: trackTop)
                                    .allowsHitTesting(false)
                                    .zIndex(4)
                                }

                                if let selection = viewModel.timelineCutSelection {
                                    TimelineSegmentOverlay(
                                        start: percentage(for: selection.startTime),
                                        end: percentage(for: selection.endTime),
                                        width: trackWidth,
                                        height: mediaTrackHeight,
                                        color: .red,
                                        opacity: 0.18,
                                        cornerRadius: videoTrackCornerRadius
                                    )
                                    .offset(x: trackOffsetX, y: trackTop)
                                    .allowsHitTesting(false)
                                    .zIndex(4)

                                    TimelineCutLabel(
                                        start: percentage(for: selection.startTime),
                                        width: trackWidth
                                    )
                                    .offset(x: trackOffsetX, y: trackTop + 10)
                                    .allowsHitTesting(false)
                                    .zIndex(8)
                                }

                                TimelinePlayhead(
                                    position: viewModel.currentTimePercentage,
                                    height: canvasHeight - trackTop + 8,
                                    width: trackWidth,
                                    offsetX: trackOffsetX,
                                    topOutset: playheadTopOutset
                                )
                                .allowsHitTesting(false)
                                .zIndex(20)

                                TrimHandle(
                                    position: viewModel.trimStartPercentage,
                                    trackOffsetX: trackOffsetX,
                                    trackWidth: trackWidth,
                                    height: mediaTrackHeight,
                                    topOffset: trackTop,
                                    isStartHandle: true,
                                    handleWidth: trimHandleWidth
                                )
                                .allowsHitTesting(false)
                                .zIndex(30)

                                TrimHandle(
                                    position: viewModel.trimEndPercentage,
                                    trackOffsetX: trackOffsetX,
                                    trackWidth: trackWidth,
                                    height: mediaTrackHeight,
                                    topOffset: trackTop,
                                    isStartHandle: false,
                                    handleWidth: trimHandleWidth
                                )
                                .allowsHitTesting(false)
                                .zIndex(30)

                                TimelineInteractionLayer()
                                    .frame(
                                        width: rightColumnWidth + interactionOutset * 2,
                                        height: canvasHeight + playheadTopOutset
                                    )
                                    .offset(x: -interactionOutset, y: -playheadTopOutset)
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            updateTimelineCursor(
                                                at: location.x,
                                                trackOffsetX: trackOffsetX,
                                                trackWidth: trackWidth
                                            )
                                        case .ended:
                                            NSCursor.arrow.set()
                                        }
                                    }
                                    .gesture(
                                        interactionGesture(
                                            trackOffsetX: trackOffsetX,
                                            trackWidth: trackWidth,
                                            handleWidth: trimHandleWidth
                                        )
                                    )
                                    .zIndex(40)
                            }
                            .frame(width: rightColumnWidth, height: canvasHeight)
                            .coordinateSpace(name: "timelineTrack")
                            .task(id: timelineLoadID(width: trackWidth)) {
                                await viewModel.loadTimelineThumbnails(for: trackWidth)
                            }
                        }
                    }

                    timelineFooter
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.025))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
        }
    }

    private var timelineHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            TimelineMetricPill(
                title: "Source",
                value: formatTime(viewModel.video?.duration ?? 0),
                accent: Color(red: 0.25, green: 0.78, blue: 0.98)
            )

            TimelineMetricPill(
                title: "Selection",
                value: formatTime(viewModel.trimmedDuration),
                accent: Color(red: 0.06, green: 0.69, blue: 0.58)
            )

            TimelineMetricPill(
                title: "Output",
                value: formatTime(viewModel.editedDuration),
                accent: viewModel.cutSegments.isEmpty ? Color.secondary.opacity(0.6) : Color(red: 0.94, green: 0.36, blue: 0.39)
            )

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Range")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("\(formatTime(viewModel.trimStartTime)) - \(formatTime(viewModel.trimEndTime))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            TimelineActionButton(
                title: "Cut",
                systemImage: "scissors",
                prominent: true,
                isDisabled: viewModel.timelineCutSelection == nil
            ) {
                viewModel.commitCutSelection()
            }

            TimelineActionButton(
                title: "Reset",
                systemImage: "arrow.uturn.backward",
                prominent: false,
                isDisabled: viewModel.cutSegments.isEmpty && viewModel.timelineCutSelection == nil
            ) {
                viewModel.clearCuts()
            }
        }
    }

    private var timelineFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.cutSegments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Removed segments")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.cutSegments) { cut in
                                CutSegmentPill(cut: cut) {
                                    viewModel.removeCut(cut)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("Drag across the filmstrip to mark a cut, or trim directly from the clip edges.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func interactionGesture(
        trackOffsetX: CGFloat,
        trackWidth: CGFloat,
        handleWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("timelineTrack"))
            .onChanged { value in
                guard trackWidth > 0 else { return }

                let start = percentage(
                    fromTimelineX: value.startLocation.x,
                    trackOffsetX: trackOffsetX,
                    trackWidth: trackWidth
                )
                let current = percentage(
                    fromTimelineX: value.location.x,
                    trackOffsetX: trackOffsetX,
                    trackWidth: trackWidth
                )

                if dragMode == nil {
                    dragMode = dragModeForStartLocation(
                        value.startLocation.x,
                        trackOffsetX: trackOffsetX,
                        trackWidth: trackWidth,
                        handleWidth: handleWidth
                    )
                }

                switch dragMode {
                case .trimStart:
                    viewModel.updateTrimStart(from: current)
                case .trimEnd:
                    viewModel.updateTrimEnd(from: current)
                case .playhead:
                    viewModel.updateCurrentTime(from: current)
                case .cutSelection:
                    if abs(value.translation.width) < 3 {
                        viewModel.updateCurrentTime(from: current)
                    } else {
                        viewModel.updateCurrentTime(from: current)
                        viewModel.updateCutSelection(startPercentage: start, endPercentage: current)
                    }
                case nil:
                    break
                }
            }
            .onEnded { _ in
                dragMode = nil
            }
    }

    private func dragModeForStartLocation(
        _ x: CGFloat,
        trackOffsetX: CGFloat,
        trackWidth: CGFloat,
        handleWidth: CGFloat
    ) -> TimelineDragMode {
        let edgeHitRadius: CGFloat = max(10, handleWidth + 4)
        let playheadHitRadius: CGFloat = 8
        let startX = timelineEdgeX(
            for: viewModel.trimStartPercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )
        let endX = timelineEdgeX(
            for: viewModel.trimEndPercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )
        let playheadX = timelineEdgeX(
            for: viewModel.currentTimePercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )

        if abs(x - startX) <= edgeHitRadius {
            return .trimStart
        }

        if abs(x - endX) <= edgeHitRadius {
            return .trimEnd
        }

        if abs(x - playheadX) <= playheadHitRadius {
            return .playhead
        }

        return .cutSelection
    }

    private func percentage(fromTimelineX x: CGFloat, trackOffsetX: CGFloat, trackWidth: CGFloat) -> Double {
        guard trackWidth > 0 else { return 0 }
        return clampedPercentage(Double((x - trackOffsetX) / trackWidth))
    }

    private func percentage(for time: TimeInterval) -> Double {
        guard let duration = viewModel.video?.duration, duration > 0 else { return 0 }
        return max(0, min(1, time / duration))
    }

    private func clampedPercentage(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    private func timelineEdgeX(for percentage: Double, trackOffsetX: CGFloat, trackWidth: CGFloat) -> CGFloat {
        trackOffsetX + trackWidth * percentage
    }

    private func updateTimelineCursor(at x: CGFloat, trackOffsetX: CGFloat, trackWidth: CGFloat) {
        let startX = timelineEdgeX(
            for: viewModel.trimStartPercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )
        let endX = timelineEdgeX(
            for: viewModel.trimEndPercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )
        let playheadX = timelineEdgeX(
            for: viewModel.currentTimePercentage,
            trackOffsetX: trackOffsetX,
            trackWidth: trackWidth
        )

        if abs(x - startX) <= 10 || abs(x - endX) <= 10 {
            NSCursor.resizeLeftRight.set()
        } else if abs(x - playheadX) <= 8 {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    private func timelineLoadID(width: CGFloat) -> String {
        "\(viewModel.video?.url.path ?? "none")-\(Int(width))"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

private struct TimelineRuler: View {
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let majorTickCount = max(3, min(6, Int(geometry.size.width / 170)))
            let minorTicksPerSegment = 4

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .offset(y: 29)

                ForEach(0...majorTickCount, id: \.self) { index in
                    let progress = Double(index) / Double(majorTickCount)
                    let x = geometry.size.width * progress

                    Text(formatTime(duration * progress))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .fixedSize()
                        .offset(x: index == majorTickCount ? max(0, x - 34) : x, y: 0)

                    Rectangle()
                        .fill(Color.white.opacity(0.36))
                        .frame(width: 1, height: 14)
                        .offset(x: x, y: 22)
                }

                ForEach(0..<(majorTickCount * minorTicksPerSegment), id: \.self) { index in
                    let progress = Double(index + 1) / Double(majorTickCount * minorTicksPerSegment)
                    let x = geometry.size.width * progress

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 1, height: 7)
                        .offset(x: x, y: 29)
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct TimelineCanvasBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.015),
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            }
    }
}

private struct TimelineTrackLaneBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct TimelineThumbnailStrip: View {
    let thumbnails: [TimelineThumbnail]
    let isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            if thumbnails.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                HStack(spacing: 0) {
                    ForEach(thumbnails) { thumbnail in
                        Image(nsImage: thumbnail.image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: max(1, geometry.size.width / CGFloat(thumbnails.count)),
                                height: geometry.size.height
                            )
                            .clipped()
                    }
                }
            }
        }
    }
}

private struct TimelineAudioWaveform: View {
    private let sampleCount = 110

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(0..<sampleCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.06, green: 0.89, blue: 0.78).opacity(0.94))
                        .frame(
                            width: max(1, (geometry.size.width / CGFloat(sampleCount)) - 1.5),
                            height: barHeight(for: index, maxHeight: geometry.size.height - 6)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 3)
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let phase = Double(index)
        let value = abs(sin(phase * 0.31) + 0.42 * cos(phase * 0.17) + 0.25 * sin(phase * 0.93))
        let normalized = 0.18 + min(1, value / 1.55) * 0.82
        return max(4, CGFloat(normalized) * maxHeight)
    }
}

private struct TimelineDimmedRegion: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        TimelineSegmentOverlay(
            start: start,
            end: end,
            width: width,
            height: height,
            color: .black,
            opacity: 0.58,
            cornerRadius: cornerRadius
        )
    }
}

private struct TimelineSegmentOverlay: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let opacity: Double
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color.opacity(opacity))
            .frame(width: max(0, width * max(0, end - start)), height: height)
            .offset(x: width * start)
    }
}

private struct TimelineSelectionFrame: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let strokeColor: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(strokeColor.opacity(0.95), lineWidth: 2)
            .frame(width: max(0, width * max(0, end - start)), height: height)
            .offset(x: width * start)
            .shadow(color: strokeColor.opacity(0.14), radius: 4, x: 0, y: 0)
    }
}

private struct TimelineInteractionLayer: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
    }
}

private struct TimelinePlayhead: View {
    let position: Double
    let height: CGFloat
    let width: CGFloat
    let offsetX: CGFloat
    let topOutset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            TimelinePlayheadMarker()

            Rectangle()
                .fill(Color(red: 1.0, green: 0.33, blue: 0.38))
                .frame(width: 2, height: height + 8)
        }
        .shadow(color: Color.red.opacity(0.18), radius: 3, x: 0, y: 1)
        .frame(width: 14, height: height + topOutset + 8, alignment: .top)
        .position(
            x: offsetX + width * position,
            y: ((height + topOutset + 8) / 2) - topOutset + 2
        )
        .contentShape(Rectangle())
    }
}

private struct TimelineCutLabel: View {
    let start: Double
    let width: CGFloat

    var body: some View {
        Text("cut")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 1.0, green: 0.33, blue: 0.38))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .offset(x: labelX, y: 6)
    }

    private var labelX: CGFloat {
        let preferredX = width * start + 8
        return min(max(8, preferredX), max(8, width - 30))
    }
}

struct TrimHandle: View {
    let position: Double
    let trackOffsetX: CGFloat
    let trackWidth: CGFloat
    let height: CGFloat
    let topOffset: CGFloat
    let isStartHandle: Bool
    let handleWidth: CGFloat

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: handleWidth, height: max(18, height - 10))
            .overlay {
                VStack(spacing: 2) {
                    Capsule()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 3, height: 1)
                    Capsule()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: 3, height: 1)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
            .position(x: handleCenterX, y: topOffset + height / 2)
            .contentShape(Rectangle())
    }

    private var handleCenterX: CGFloat {
        let edgeX = trackOffsetX + trackWidth * position
        let minimumX = trackOffsetX
        let maximumX = trackOffsetX + trackWidth
        return max(minimumX, min(maximumX, edgeX))
    }
}

private struct TimelinePlayheadMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 1.0, green: 0.33, blue: 0.38))
                .frame(width: 12, height: 8)

            Triangle()
                .fill(Color(red: 1.0, green: 0.33, blue: 0.38))
                .frame(width: 8, height: 5)
                .offset(y: -1)
        }
    }
}

private struct TimelineTrackSidebar: View {
    let sidebarWidth: CGFloat
    let rulerHeight: CGFloat
    let videoTrackHeight: CGFloat
    let audioTrackHeight: CGFloat
    let trackTop: CGFloat
    let trackSpacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "timeline.selection")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))

                Text("Tracks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .frame(height: rulerHeight, alignment: .center)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.03))

                VStack(alignment: .leading, spacing: trackSpacing) {
                    Spacer()
                        .frame(height: trackTop)

                    TimelineTrackLabelRow(
                        title: "Video 1",
                        subtitle: "Main clip",
                        systemImage: "film"
                    )
                    .frame(height: videoTrackHeight)

                    TimelineTrackLabelRow(
                        title: "Audio 1",
                        subtitle: "Waveform",
                        systemImage: "waveform"
                    )
                    .frame(height: audioTrackHeight + 18)
                }
                .padding(.horizontal, 10)
            }
        }
        .frame(width: sidebarWidth)
    }
}

private struct TimelineTrackLabelRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))

                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TimelineClipBadge: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 7, weight: .bold))

            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct TimelineMetricPill: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct TimelineActionButton: View {
    let title: String
    let systemImage: String
    let prominent: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 84)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(prominent ? Color.orange : Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(prominent ? 0.0 : 0.08), lineWidth: 1)
        }
        .opacity(isDisabled ? 0.45 : 1)
        .disabled(isDisabled)
    }
}

private struct CutSegmentPill: View {
    let cut: VideoCutSegment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "scissors")
                .font(.system(size: 10, weight: .semibold))

            Text("\(formatTime(cut.startTime)) - \(formatTime(cut.endTime))")
                .font(.system(size: 11, design: .monospaced))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time - floor(time)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

#endif
