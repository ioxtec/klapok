import SwiftUI

struct VideoAnnotationInspector: View {
    @ObservedObject var viewModel: VideoEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Crop".localized, systemImage: "crop") { viewModel.isCropping = true }
                if viewModel.cropRect != QuickEditGeometry.fullFrame {
                    Button("Reset".localized) { viewModel.applyCrop(QuickEditGeometry.fullFrame) }
                }
                Spacer(minLength: 0)
            }
            AnnotationLayerMenu(viewModel: viewModel)
            if let track = viewModel.overlayTracks.first(where: { $0.id == viewModel.selectedOverlayID }) {
                Divider()
                HStack {
                    Picker("Type".localized, selection: binding(track, \.kind)) {
                        ForEach(TimelineOverlayTrackKind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.icon).tag(kind)
                        }
                    }
                    Button(role: .destructive) { viewModel.removeOverlay(track.id) } label: { Image(systemName: "trash") }
                        .help("Delete annotation".localized)
                }
                if track.kind == .text {
                    TextField("Annotation text".localized, text: binding(track, \.text), axis: .vertical)
                        .lineLimit(2...4).textFieldStyle(.roundedBorder)
                }
                HStack(spacing: 8) {
                    timeField("Start".localized, binding(track, \.start))
                    timeField("Duration".localized, Binding(get: { track.end - track.start }, set: { duration in
                        guard var current = current(track.id) else { return }
                        current.end = current.start + max(0.1, duration); viewModel.updateOverlay(current)
                    }))
                }
                ColorPicker("Color".localized, selection: Binding(get: { track.color.toColor() }, set: { color in
                    guard var current = current(track.id) else { return }
                    current.color = ColorData(color: color); viewModel.updateOverlay(current)
                }))
                Button("Place on preview".localized, systemImage: "cursorarrow.and.square.on.square.dashed") {
                    viewModel.placingOverlayID = track.id
                    viewModel.updateCurrentTime(to: track.start)
                }
                DisclosureGroup("Position and size".localized) {
                    VStack(spacing: 4) {
                        slider("Horizontal".localized, track, \.x, 0...0.95)
                        slider("Vertical".localized, track, \.y, 0...0.95)
                        slider("Width".localized, track, \.width, directional(track) ? -1...1 : 0.02...1)
                        slider("Height".localized, track, \.height, directional(track) ? -1...1 : 0.02...1)
                    }
                }
            } else {
                Text("Select an annotation on the timeline to edit it.".localized)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 12)).controlSize(.small)
        .disabled(viewModel.video == nil)
        .help("Drag annotation edges on the timeline to change when it appears.".localized)
    }

    private func current(_ id: UUID) -> TimelineOverlayTrack? { viewModel.overlayTracks.first(where: { $0.id == id }) }
    private func directional(_ track: TimelineOverlayTrack) -> Bool { track.kind == .callout || track.kind == .line }

    private func timeField(_ title: String, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 3) { TextField("", value: value, format: .number.precision(.fractionLength(2))); Text("s").foregroundStyle(.secondary) }
                .textFieldStyle(.roundedBorder)
        }
    }

    private func binding<T>(_ track: TimelineOverlayTrack, _ keyPath: WritableKeyPath<TimelineOverlayTrack, T>) -> Binding<T> {
        Binding(get: { current(track.id)?[keyPath: keyPath] ?? track[keyPath: keyPath] }, set: { value in
            guard var current = current(track.id) else { return }
            current[keyPath: keyPath] = value; viewModel.updateOverlay(current)
        })
    }

    private func slider(_ title: String, _ track: TimelineOverlayTrack, _ keyPath: WritableKeyPath<TimelineOverlayTrack, Double>, _ range: ClosedRange<Double>) -> some View {
        HStack { Text(title).font(.caption).frame(width: 65, alignment: .leading); Slider(value: binding(track, keyPath), in: range) }
    }
}
