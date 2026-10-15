import SwiftUI

struct TimelineRange: Equatable {
    var start: Double
    var end: Double
}

/// Reusable range editing with local drag state and a single commit on release.
struct TimelineRangeClip<Label: View>: View {
    let range: TimelineRange
    let duration: Double
    let frameRate: Double
    let pixelsPerSecond: CGFloat
    let width: CGFloat
    let isSelected: Bool
    var tint: Color = .purple
    let startHelp: String
    let endHelp: String
    let onSelect: () -> Void
    let onBeginEdit: () -> Void
    let onCommit: (TimelineRange) -> Void
    @ViewBuilder let label: (CGFloat) -> Label
    @State private var original: TimelineRange?
    @State private var proposed: TimelineRange?

    var body: some View {
        let visible = proposed ?? range
        let clipWidth = max(4, CGFloat(visible.end - visible.start) * pixelsPerSecond)
        let gripOffset: CGFloat = clipWidth < 48 ? 24 : 8
        ZStack(alignment: .leading) {
            Color.primary.opacity(0.025)
            label(clipWidth)
                .padding(.horizontal, clipWidth < 48 ? 2 : 16)
                .frame(width: clipWidth, height: 28).clipped()
                .background(tint.opacity(isSelected ? 0.9 : 0.55), in: RoundedRectangle(cornerRadius: 4))
                .overlay { RoundedRectangle(cornerRadius: 4).stroke(isSelected ? .white.opacity(0.8) : .clear, lineWidth: 1) }
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)
                .gesture(drag(.move))
                .overlay(alignment: .leading) { grip(start: true).offset(x: -gripOffset) }
                .overlay(alignment: .trailing) { grip(start: false).offset(x: gripOffset) }
                .offset(x: CGFloat(visible.start) * pixelsPerSecond)
        }
        .frame(width: width)
        .accessibilityValue(String(format: "%.3f,%.3f", visible.start, visible.end))
    }

    private enum Edit { case move, start, end }

    private func grip(start: Bool) -> some View {
        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.8)).frame(width: 2, height: 14)
            .frame(width: 24, height: 32).contentShape(Rectangle())
            .highPriorityGesture(drag(start ? .start : .end))
            .help(start ? startHelp : endHelp)
    }

    private func drag(_ edit: Edit) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global).onChanged { value in
            if original == nil { original = range; onBeginEdit() }
            guard let original else { return }
            let frame = 1 / max(1, frameRate)
            let delta = (Double(value.translation.width / max(0.001, pixelsPerSecond)) / frame).rounded() * frame
            let length = original.end - original.start
            switch edit {
            case .move:
                let start = max(0, min(max(0, duration - length), original.start + delta))
                proposed = TimelineRange(start: start, end: start + length)
            case .start:
                proposed = TimelineRange(start: max(0, min(original.end - 0.1, original.start + delta)), end: original.end)
            case .end:
                proposed = TimelineRange(start: original.start, end: max(original.start + 0.1, min(duration, original.end + delta)))
            }
        }.onEnded { _ in
            if let proposed { onCommit(proposed) }
            original = nil; proposed = nil
        }
    }
}
