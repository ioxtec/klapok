import SwiftUI

struct VideoAnnotationInspector: View {
    @ObservedObject var viewModel: VideoEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Crop".localized, systemImage: "crop") {
                    viewModel.isCropping = true
                }
                if viewModel.cropRect != QuickEditGeometry.fullFrame {
                    Button("Reset".localized) { viewModel.applyCrop(QuickEditGeometry.fullFrame) }
                }
            }
            Button("Add annotation".localized, systemImage: "plus") { viewModel.addOverlayTrack() }
            Text("Annotations use the edited timeline. Position is relative to the cropped frame.".localized)
                .font(.caption).foregroundStyle(.secondary)
            ForEach(viewModel.overlayTracks) { track in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Type".localized, selection: binding(track, \.kind)) {
                            Text("Text".localized).tag(TimelineOverlayTrackKind.text)
                            Text("Arrow".localized).tag(TimelineOverlayTrackKind.callout)
                            Text("Highlight".localized).tag(TimelineOverlayTrackKind.highlight)
                        }
                        Button(role: .destructive) { viewModel.removeOverlay(track.id) } label: {
                            Image(systemName: "trash")
                        }.help("Delete annotation".localized)
                    }
                    if track.kind == .text {
                        TextField("Annotation text".localized, text: binding(track, \.text), axis: .vertical)
                    }
                    ColorPicker("Color".localized, selection: Binding(
                        get: { track.color.toColor() }, set: { color in
                            var updated = track; updated.color = ColorData(color: color)
                            viewModel.updateOverlay(updated)
                        }))
                    Button("Place on preview".localized, systemImage: "cursorarrow.and.square.on.square.dashed") {
                        viewModel.placingOverlayID = track.id
                        viewModel.updateCurrentTime(to: track.start)
                    }
                    HStack {
                        Text("Start".localized)
                        TextField("", value: binding(track, \.start), format: .number.precision(.fractionLength(1)))
                        Text("End".localized)
                        TextField("", value: binding(track, \.end), format: .number.precision(.fractionLength(1)))
                        Text("s")
                    }.textFieldStyle(.roundedBorder)
                    positionSlider("Horizontal".localized, track, \.x, 0...0.95)
                    positionSlider("Vertical".localized, track, \.y, 0...0.95)
                    if track.kind != .text {
                        positionSlider("Width".localized, track, \.width, track.kind == .callout ? -1...1 : 0.02...1)
                        positionSlider("Height".localized, track, \.height, track.kind == .callout ? -1...1 : 0.02...1)
                    }
                }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .disabled(viewModel.video == nil)
    }

    private func binding<T>(_ track: TimelineOverlayTrack, _ keyPath: WritableKeyPath<TimelineOverlayTrack, T>) -> Binding<T> {
        Binding(get: { viewModel.overlayTracks.first(where: { $0.id == track.id })?[keyPath: keyPath] ?? track[keyPath: keyPath] },
            set: { value in
                guard var current = viewModel.overlayTracks.first(where: { $0.id == track.id }) else { return }
                current[keyPath: keyPath] = value; viewModel.updateOverlay(current)
            })
    }

    private func positionSlider(_ title: String, _ track: TimelineOverlayTrack,
                                _ keyPath: WritableKeyPath<TimelineOverlayTrack, Double>, _ range: ClosedRange<Double>) -> some View {
        HStack { Text(title).font(.caption).frame(width: 76, alignment: .leading)
            Slider(value: binding(track, keyPath), in: range)
        }
    }
}
