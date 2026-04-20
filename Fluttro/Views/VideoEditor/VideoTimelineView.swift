//
//  VideoTimelineView.swift
//  Fluttro
//

import SwiftUI

#if os(macOS)
import AppKit

struct VideoTimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var dragMode: TimelineDragMode?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Source \(formatTime(viewModel.video?.duration ?? 0))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Selection \(formatTime(viewModel.trimmedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !viewModel.cutSegments.isEmpty {
                    Text("Output \(formatTime(viewModel.editedDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(formatTime(viewModel.trimStartTime)) - \(formatTime(viewModel.trimEndTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Cut selection") {
                    viewModel.commitCutSelection()
                }
                .controlSize(.small)
                .disabled(viewModel.timelineCutSelection == nil)

                Button("Clear cuts") {
                    viewModel.clearCuts()
                }
                .controlSize(.small)
                .disabled(viewModel.cutSegments.isEmpty && viewModel.timelineCutSelection == nil)
            }

            GeometryReader { geometry in
                let trackHeight: CGFloat = 64
                let trimHandleWidth: CGFloat = 14
                let trackOffsetX = trimHandleWidth
                let trackWidth = max(1, geometry.size.width - trimHandleWidth * 2)
                let interactionOutset: CGFloat = 24
                let playheadTopOutset: CGFloat = 14

                VStack(spacing: 6) {
                    TimelineRuler(duration: viewModel.video?.duration ?? 0)
                        .frame(height: 18)

                    ZStack(alignment: .leading) {
                        TimelineThumbnailStrip(
                            thumbnails: viewModel.timelineThumbnails,
                            isLoading: viewModel.isLoadingTimelineThumbnails
                        )
                            .frame(width: trackWidth, height: trackHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                            .offset(x: trackOffsetX)
                            .zIndex(0)

                        TimelineDimmedRegion(
                            start: 0,
                            end: viewModel.trimStartPercentage,
                            width: trackWidth,
                            height: trackHeight
                        )
                        .offset(x: trackOffsetX)
                        .allowsHitTesting(false)
                        .zIndex(2)

                        TimelineDimmedRegion(
                            start: viewModel.trimEndPercentage,
                            end: 1,
                            width: trackWidth,
                            height: trackHeight
                        )
                        .offset(x: trackOffsetX)
                        .allowsHitTesting(false)
                        .zIndex(2)

                        ForEach(viewModel.cutSegments) { cut in
                            TimelineSegmentOverlay(
                                start: percentage(for: cut.startTime),
                                end: percentage(for: cut.endTime),
                                width: trackWidth,
                                height: trackHeight,
                                color: .red,
                                opacity: 0.45
                            )
                            .offset(x: trackOffsetX)
                            .allowsHitTesting(false)
                            .zIndex(3)
                        }

                        if let selection = viewModel.timelineCutSelection {
                            TimelineSegmentOverlay(
                                start: percentage(for: selection.startTime),
                                end: percentage(for: selection.endTime),
                                width: trackWidth,
                                height: trackHeight,
                                color: .orange,
                                opacity: 0.42
                            )
                            .offset(x: trackOffsetX)
                            .allowsHitTesting(false)
                            .zIndex(4)

                            TimelineCutLabel(
                                start: percentage(for: selection.startTime),
                                width: trackWidth
                            )
                            .offset(x: trackOffsetX)
                            .allowsHitTesting(false)
                            .zIndex(8)
                        }

                        TimelinePlayhead(
                            position: viewModel.currentTimePercentage,
                            height: trackHeight + 20,
                            width: trackWidth,
                            offsetX: trackOffsetX
                        )
                        .allowsHitTesting(false)
                        .zIndex(20)

                        TrimHandle(
                            position: viewModel.trimStartPercentage,
                            trackOffsetX: trackOffsetX,
                            trackWidth: trackWidth,
                            height: trackHeight,
                            isStartHandle: true,
                            handleWidth: trimHandleWidth
                        )
                        .allowsHitTesting(false)
                        .zIndex(30)

                        TrimHandle(
                            position: viewModel.trimEndPercentage,
                            trackOffsetX: trackOffsetX,
                            trackWidth: trackWidth,
                            height: trackHeight,
                            isStartHandle: false,
                            handleWidth: trimHandleWidth
                        )
                        .allowsHitTesting(false)
                        .zIndex(30)

                        TimelineInteractionLayer()
                            .frame(
                                width: geometry.size.width + interactionOutset * 2,
                                height: trackHeight + playheadTopOutset
                            )
                            .offset(x: -interactionOutset, y: -playheadTopOutset)
                            .gesture(
                                interactionGesture(
                                    trackOffsetX: trackOffsetX,
                                    trackWidth: trackWidth,
                                    handleWidth: trimHandleWidth
                                )
                            )
                            .zIndex(40)
                    }
                    .frame(height: trackHeight)
                    .coordinateSpace(name: "timelineTrack")
                    .task(id: timelineLoadID(width: trackWidth)) {
                        await viewModel.loadTimelineThumbnails(for: trackWidth)
                    }

                    if !viewModel.cutSegments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(viewModel.cutSegments) { cut in
                                    CutSegmentPill(cut: cut) {
                                        viewModel.removeCut(cut)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        HStack {
                            Text("Drag across the frame strip to mark a part to cut.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
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
        let hitRadius: CGFloat = 28
        let startX = trackOffsetX + trackWidth * viewModel.trimStartPercentage - handleWidth / 2
        let endX = trackOffsetX + trackWidth * viewModel.trimEndPercentage + handleWidth / 2
        let playheadX = trackOffsetX + trackWidth * viewModel.currentTimePercentage

        if abs(x - playheadX) <= hitRadius {
            return .playhead
        }

        if abs(x - startX) <= hitRadius {
            return .trimStart
        }

        if abs(x - endX) <= hitRadius {
            return .trimEnd
        }

        return .cutSelection
    }

    private func percentage(fromTimelineX x: CGFloat, trackOffsetX: CGFloat, trackWidth: CGFloat) -> Double {
        guard trackWidth > 0 else { return 0 }
        return clampedPercentage((x - trackOffsetX) / trackWidth)
    }

    private func percentage(for time: TimeInterval) -> Double {
        guard let duration = viewModel.video?.duration, duration > 0 else { return 0 }
        return max(0, min(1, time / duration))
    }

    private func clampedPercentage(_ value: Double) -> Double {
        max(0, min(1, value))
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

private enum TimelineDragMode {
    case trimStart
    case trimEnd
    case playhead
    case cutSelection
}

private struct TimelineRuler: View {
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let tickCount = max(2, min(12, Int(geometry.size.width / 96)))

            ZStack(alignment: .leading) {
                ForEach(0...tickCount, id: \.self) { index in
                    let progress = Double(index) / Double(tickCount)
                    let x = geometry.size.width * progress

                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 1, height: index % 2 == 0 ? 8 : 5)

                        if index % 2 == 0 {
                            Text(formatTime(duration * progress))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .offset(x: index == tickCount ? -28 : 0)
                        }
                    }
                    .offset(x: x)
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

private struct TimelineThumbnailStrip: View {
    let thumbnails: [TimelineThumbnail]
    let isLoading: Bool

    var body: some View {
        GeometryReader { geometry in
            if thumbnails.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
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

private struct TimelineDimmedRegion: View {
    let start: Double
    let end: Double
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        TimelineSegmentOverlay(
            start: start,
            end: end,
            width: width,
            height: height,
            color: .black,
            opacity: 0.58
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

    var body: some View {
        Rectangle()
            .fill(color.opacity(opacity))
            .frame(width: max(0, width * max(0, end - start)), height: height)
            .offset(x: width * start)
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
    private let topOutset: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: height - 8)
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .frame(width: 18, height: height)
        .position(x: offsetX + width * position, y: height / 2 - topOutset)
        .contentShape(Rectangle())
    }
}

private struct TimelineCutLabel: View {
    let start: Double
    let width: CGFloat

    var body: some View {
        Text("cut")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(x: labelX, y: 6)
    }

    private var labelX: CGFloat {
        let preferredX = width * start + 6
        return min(max(6, preferredX), max(6, width - 34))
    }
}

struct TrimHandle: View {
    let position: Double
    let trackOffsetX: CGFloat
    let trackWidth: CGFloat
    let height: CGFloat
    let isStartHandle: Bool
    let handleWidth: CGFloat
    private let verticalVisualAdjustment: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.accentColor)
            .frame(width: handleWidth, height: height)
            .overlay {
                Image(systemName: isStartHandle ? "chevron.left" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        .frame(width: 18, height: height)
        .position(x: handleCenterX, y: height / 2 + verticalVisualAdjustment)
        .contentShape(Rectangle())
    }

    private var handleCenterX: CGFloat {
        let edgeX = trackOffsetX + trackWidth * position
        let centerX = isStartHandle
            ? edgeX - handleWidth / 2
            : edgeX + handleWidth / 2
        let minimumX = handleWidth / 2
        let maximumX = trackOffsetX + trackWidth + handleWidth / 2
        return max(minimumX, min(maximumX, centerX))
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
