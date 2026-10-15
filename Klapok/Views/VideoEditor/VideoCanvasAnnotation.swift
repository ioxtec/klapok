import SwiftUI

struct VideoCanvasAnnotation: View {
    let track: TimelineOverlayTrack
    @ObservedObject var viewModel: VideoEditorViewModel
    let canvasSize: CGSize
    @State private var rendered: NSImage?
    @State private var original: TimelineOverlayTrack?
    @State private var adjustingEndpoint = false
    @FocusState private var textFocused: Bool

    private var selected: Bool { viewModel.selectedOverlayID == track.id }
    private var directional: Bool { track.kind == .line || track.kind == .callout }
    private var editing: Bool { viewModel.editingOverlayID == track.id && track.kind == .text }
    private var bounds: CGRect {
        CGRect(x: track.x * canvasSize.width, y: track.y * canvasSize.height,
            width: track.width * canvasSize.width, height: track.height * canvasSize.height).standardized
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !editing, let rendered {
                Image(nsImage: rendered).resizable().frame(width: canvasSize.width, height: canvasSize.height)
                    .allowsHitTesting(false)
            }
            if editing {
                TextField("Annotation text".localized, text: Binding(get: {
                    viewModel.overlayTracks.first(where: { $0.id == track.id })?.text ?? track.text
                }, set: { text in
                    guard var current = viewModel.overlayTracks.first(where: { $0.id == track.id }) else { return }
                    current.text = text; viewModel.updateOverlay(current, recordUndo: false)
                }), axis: .vertical)
                .font(.system(size: max(6, canvasSize.height * track.fontScale), weight: track.fontWeight.swiftUIWeight))
                .foregroundStyle(track.color.toColor()).textFieldStyle(.plain)
                .focused($textFocused)
                .frame(width: max(40, bounds.width), height: max(24, bounds.height), alignment: .topLeading)
                .background(Color.black.opacity(0.18))
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { textFocused = true })
                .offset(x: bounds.minX, y: bounds.minY)
                .task {
                    await Task.yield()
                    textFocused = true
                }
                .onSubmit { viewModel.editingOverlayID = nil }
                .onExitCommand { viewModel.editingOverlayID = nil }
                .accessibilityIdentifier("video.inlineText")
            } else {
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .frame(width: max(20, bounds.width), height: max(20, bounds.height))
                    .offset(x: bounds.minX, y: bounds.minY)
                    .onTapGesture(count: 2) {
                        viewModel.editOverlay(track.id)
                    }
                    .onTapGesture { viewModel.selectOverlay(track.id) }
                    .gesture(drag(.move))
                    .contextMenu {
                        Button("Edit".localized) { viewModel.editOverlay(track.id) }
                        Button("Delete annotation".localized, role: .destructive) { viewModel.removeOverlay(track.id) }
                    }
                    .accessibilityIdentifier("video.annotationHit.\(track.id)")
                    .accessibilityValue(selected ? "selected" : "unselected")
            }
            if selected {
                Rectangle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: max(20, bounds.width), height: max(20, bounds.height))
                    .offset(x: bounds.minX, y: bounds.minY).allowsHitTesting(false)
                    .opacity(adjustingEndpoint ? 0 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Selected annotation".localized)
                    .accessibilityIdentifier("video.annotationSelection.\(track.id)")
                Circle().fill(.white).overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                    .frame(width: 9, height: 9)
                    .position(x: (track.x + track.width) * canvasSize.width, y: (track.y + track.height) * canvasSize.height)
                    .opacity(adjustingEndpoint ? 0 : 1)
                    .gesture(drag(directional ? .end : .resize))
                    .accessibilityIdentifier("video.annotationEnd.\(track.id)")
                if directional {
                    Circle().fill(.white).overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                        .frame(width: 9, height: 9)
                        .position(x: track.x * canvasSize.width, y: track.y * canvasSize.height)
                        .opacity(adjustingEndpoint ? 0 : 1)
                        .gesture(drag(.start))
                        .accessibilityIdentifier("video.annotationStart.\(track.id)")
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .onChange(of: track, initial: true) { _, value in rendered = VideoFrameRenderer.previewImage(value, size: canvasSize) }
        .onChange(of: canvasSize) { _, size in rendered = VideoFrameRenderer.previewImage(track, size: size) }
    }

    private enum Edit { case move, start, end, resize }

    private func drag(_ edit: Edit) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global).onChanged { value in
            if original == nil { original = track; viewModel.beginOverlayGesture(track.id) }
            guard var updated = original else { return }
            let dx = value.translation.width / max(1, canvasSize.width)
            let dy = value.translation.height / max(1, canvasSize.height)
            switch edit {
            case .move: updated.x += dx; updated.y += dy
            case .resize: updated.width += dx; updated.height += dy
            case .start:
                adjustingEndpoint = true
                updated.moveEndpoint(start: true, to: CGPoint(x: updated.x + dx, y: updated.y + dy))
            case .end:
                adjustingEndpoint = true
                updated.moveEndpoint(start: false, to: CGPoint(x: updated.x + updated.width + dx, y: updated.y + updated.height + dy))
            }
            viewModel.updateOverlay(updated, recordUndo: false)
        }.onEnded { _ in original = nil; adjustingEndpoint = false }
    }
}
