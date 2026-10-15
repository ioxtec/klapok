import SwiftUI

struct TimelineLayerInsertion: Equatable {
    let source: String
    let target: String
    let above: Bool
}

/// Local vertical reordering does not depend on pasteboard/drop negotiation.
struct TimelineLayerReorderHandle: View {
    let id: String
    let visualOrder: [String]
    let rowStride: CGFloat
    let help: String
    @Binding var insertion: TimelineLayerInsertion?
    let onBegin: () -> Void
    let onMove: (String, String, Bool) -> Void
    @GestureState private var isDragging = false
    @State private var hasBegun = false

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 10))
            .foregroundStyle(isDragging ? Color.accentColor : .secondary)
            .frame(width: 20, height: 32).contentShape(Rectangle())
            .help(help)
            .accessibilityLabel(help)
            .accessibilityIdentifier("timeline.reorder.\(id)")
            .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in
                    if value.translation == .zero { return }
                    if !hasBegun { hasBegun = true; onBegin() }
                    insertion = proposal(for: value.translation.height)
                }
                .onEnded { value in
                    if let proposal = proposal(for: value.translation.height) {
                        onMove(proposal.source, proposal.target, proposal.above)
                    }
                    insertion = nil
                    hasBegun = false
                })
            .onChange(of: isDragging) { _, dragging in
                if !dragging { insertion = nil; hasBegun = false }
            }
    }

    private func proposal(for translation: CGFloat) -> TimelineLayerInsertion? {
        guard let destination = TimelineLayerOrder.destination(for: id, translation: translation,
            rowStride: rowStride, in: visualOrder) else { return nil }
        return TimelineLayerInsertion(source: id, target: destination.target, above: destination.above)
    }
}

struct TimelineLayerInsertionMarker: ViewModifier {
    let id: String
    let insertion: TimelineLayerInsertion?

    func body(content: Content) -> some View {
        content.overlay(alignment: insertion?.above == false ? .bottom : .top) {
            if insertion?.target == id {
                Rectangle().fill(Color.accentColor).frame(height: 2).allowsHitTesting(false)
            }
        }
    }
}
