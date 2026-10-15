import SwiftUI

/// Klapok adapter; reusable range gestures and layout live in TimelineRangeClip.
struct VideoAnnotationLane: View {
    let track: TimelineOverlayTrack
    @ObservedObject var viewModel: VideoEditorViewModel
    let pixelsPerSecond: CGFloat
    let width: CGFloat

    var body: some View {
        TimelineRangeClip(range: TimelineRange(start: track.start, end: track.end),
            duration: viewModel.editedDuration, frameRate: viewModel.video?.frameRate ?? 30,
            pixelsPerSecond: pixelsPerSecond, width: width,
            isSelected: viewModel.selectedOverlayID == track.id,
            startHelp: "Drag to change the start".localized,
            endHelp: "Drag to change the duration".localized,
            onSelect: { viewModel.selectOverlay(track.id); viewModel.updateCurrentTime(to: track.start) },
            onBeginEdit: { viewModel.beginOverlayGesture(track.id) },
            onCommit: { viewModel.setOverlayTiming(track.id, start: $0.start, end: $0.end, recordUndo: false) }) { clipWidth in
                HStack(spacing: 4) {
                    Image(systemName: track.kind.icon).font(.system(size: 11))
                    if clipWidth >= 64 { Text(track.title).font(.system(size: 11, weight: .medium)).lineLimit(1) }
                    Spacer(minLength: 0)
                }.foregroundStyle(.white)
            }
            .contextMenu {
                Button("Edit".localized) { viewModel.editOverlay(track.id) }
                Button("Delete annotation".localized, role: .destructive) { viewModel.removeOverlay(track.id) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(track.title)
            .accessibilityIdentifier("video.annotationClip.\(track.id)")
    }
}
