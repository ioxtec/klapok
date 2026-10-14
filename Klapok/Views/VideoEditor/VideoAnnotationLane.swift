import SwiftUI

/// Drag the body to move a layer; drag either grip to trim its time range.
struct VideoAnnotationLane: View {
    let track: TimelineOverlayTrack
    @ObservedObject var viewModel: VideoEditorViewModel
    let pixelsPerSecond: CGFloat
    let width: CGFloat
    @State private var original: TimelineOverlayTrack?
    @State private var proposed: TimelineOverlayTrack?

    var body: some View {
        let visible = proposed ?? track
        ZStack(alignment: .leading) {
            Color.primary.opacity(0.025)
            HStack(spacing: 4) {
                grip(start: true)
                Image(systemName: track.kind.icon).font(.system(size: 11))
                Text(track.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                grip(start: false)
            }
            .foregroundStyle(.white)
            .frame(width: max(4, CGFloat(visible.end - visible.start) * pixelsPerSecond), height: 28)
            .background(Color.purple.opacity(viewModel.selectedOverlayID == track.id ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(viewModel.selectedOverlayID == track.id ? .white.opacity(0.8) : .clear, lineWidth: 1) }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectOverlay(track.id); viewModel.updateCurrentTime(to: track.start) }
            .gesture(drag(.move))
            .offset(x: CGFloat(visible.start) * pixelsPerSecond)
            .contextMenu {
                Button("Edit".localized) { viewModel.editOverlay(track.id) }
                Button("Delete annotation".localized, role: .destructive) { viewModel.removeOverlay(track.id) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(track.title)
            .accessibilityValue(String(format: "%.3f,%.3f", visible.start, visible.end))
            .accessibilityIdentifier("video.annotationClip.\(track.id)")
        }.frame(width: width)
    }

    private enum Edit { case move, start, end }

    private func grip(start: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.8)).frame(width: 2, height: 14)
            .frame(width: 10, height: 28).contentShape(Rectangle())
            .highPriorityGesture(drag(start ? .start : .end))
            .help(start ? "Drag to change the start".localized : "Drag to change the duration".localized)
    }

    private func drag(_ edit: Edit) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global).onChanged { value in
            if original == nil { original = track; viewModel.beginOverlayGesture(track.id) }
            guard let original else { return }
            let frame = 1 / max(1, viewModel.video?.frameRate ?? 30)
            let delta = (Double(value.translation.width / pixelsPerSecond) / frame).rounded() * frame
            let duration = original.end - original.start
            let start: Double, end: Double
            switch edit {
            case .move:
                start = max(0, min(max(0, viewModel.editedDuration - duration), original.start + delta))
                end = start + duration
            case .start:
                start = max(0, min(original.end - 0.1, original.start + delta)); end = original.end
            case .end:
                start = original.start; end = max(start + 0.1, min(viewModel.editedDuration, original.end + delta))
            }
            var draft = original; draft.start = start; draft.end = end; proposed = draft
        }.onEnded { _ in
            if let proposed { viewModel.setOverlayTiming(track.id, start: proposed.start, end: proposed.end, recordUndo: false) }
            original = nil; proposed = nil
        }
    }
}
