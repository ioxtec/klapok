import SwiftUI

struct VideoAnnotationToolbar: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    private var selected: TimelineOverlayTrack? { viewModel.overlayTracks.first(where: { $0.id == viewModel.selectedOverlayID }) }
    private var outputHeight: Double { max(1, (viewModel.video?.size.height ?? 800) * viewModel.cropRect.height) }
    private var kind: TimelineOverlayTrackKind? { selected?.kind ?? viewModel.activeAnnotationTool }
    private var fillOpacity: Binding<Double> {
        Binding(get: { selected?.fillOpacity ?? viewModel.annotationFillOpacity }, set: { opacity in
            viewModel.annotationFillOpacity = opacity
            if var track = selected { track.fillOpacity = opacity; viewModel.updateOverlay(track) }
        })
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(TimelineOverlayTrackKind.allCases, id: \.self) { kind in
                    ToolButton(tool: tool(kind), currentTool: viewModel.activeAnnotationTool.map(tool) ?? .select,
                        selectedAnnotationType: selected?.kind.annotationType, action: {
                            viewModel.pausePlayback()
                            viewModel.editingOverlayID = nil; viewModel.selectedOverlayID = nil
                            viewModel.activeAnnotationTool = viewModel.activeAnnotationTool == kind ? nil : kind
                        })
                        .accessibilityIdentifier("video.tool.\(kind.rawValue)")
                }
            }
            Divider().frame(height: 22)
            ColorPicker("Color".localized, selection: Binding(get: { selected?.color.toColor() ?? viewModel.annotationColor }, set: { color in
                viewModel.annotationColor = color
                if var track = selected { track.color = ColorData(color: color); viewModel.updateOverlay(track) }
            }), supportsOpacity: false).labelsHidden().help("Color".localized)
            if kind == .text {
                Stepper(value: Binding(get: { selected.map { $0.fontScale * outputHeight } ?? viewModel.annotationFontSize }, set: { size in
                    viewModel.annotationFontSize = size
                    if var track = selected { track.fontScale = size / outputHeight; viewModel.updateOverlay(track) }
                }), in: 8...96, step: 1) {
                    Text("\(Int(selected.map { $0.fontScale * outputHeight } ?? viewModel.annotationFontSize)) pt").font(.caption)
                }.fixedSize().help("Text size".localized)
                Picker("Font Weight".localized, selection: Binding(get: {
                    selected?.fontWeight ?? viewModel.annotationFontWeight
                }, set: { weight in
                    viewModel.annotationFontWeight = weight
                    if var track = selected { track.fontWeight = weight; viewModel.updateOverlay(track) }
                })) {
                    ForEach(FontWeight.allCases, id: \.self) { weight in
                        Text(weight.rawValue.localized).tag(weight)
                    }
                }.labelsHidden().fixedSize()
                .accessibilityIdentifier("video.fontWeight")
                if let selected {
                    Button("Edit Text".localized) { viewModel.editOverlay(selected.id) }
                        .accessibilityIdentifier("video.editText")
                }
            } else {
                Stepper(value: Binding(get: { selected.map { $0.strokeScale * outputHeight } ?? viewModel.annotationStrokeWidth }, set: { size in
                    viewModel.annotationStrokeWidth = size
                    if var track = selected { track.strokeScale = size / outputHeight; viewModel.updateOverlay(track) }
                }), in: 1...12, step: 1) {
                    Text("\(Int(selected.map { $0.strokeScale * outputHeight } ?? viewModel.annotationStrokeWidth)) px").font(.caption)
                }.fixedSize().help("Line width".localized)
            }
            if kind == .rectangle || kind == .circle || kind == .highlight {
                Divider().frame(height: 22)
                Toggle("Fill".localized, isOn: Binding(get: { fillOpacity.wrappedValue > 0 }, set: { enabled in
                    fillOpacity.wrappedValue = enabled ? 0.3 : 0
                }))
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("video.fillEnabled")
                if fillOpacity.wrappedValue > 0 {
                    Picker("Opacity".localized, selection: fillOpacity) {
                        ForEach(1...10, id: \.self) { value in
                            Text("\(value * 10)%").tag(Double(value) / 10)
                        }
                    }.labelsHidden().fixedSize()
                    .accessibilityIdentifier("video.fillOpacity")
                }
            }
            if kind == .callout {
                ArrowStylePicker(selection: Binding(get: { selected?.arrowStyle ?? viewModel.annotationArrowStyle }, set: { style in
                    viewModel.annotationArrowStyle = style
                    if var track = selected { track.arrowStyle = style; viewModel.updateOverlay(track) }
                }))
                .accessibilityIdentifier("video.arrowStyle")
            }
            Spacer(minLength: 4)
            if let url = viewModel.exportedURL {
                Label(viewModel.copiedExport ? "File copied".localized : url.lastPathComponent, systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .frame(maxWidth: 160).help(url.path)
                    .accessibilityIdentifier("video.exportResult")
            }
            if selected != nil {
                Button { viewModel.removeTimelineSelection() } label: { Image(systemName: "trash") }
                    .help("Delete annotation".localized)
            }
        }
        .buttonStyle(.borderless).controlSize(.small)
        .padding(.horizontal, 12).frame(height: 44)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.annotationToolbar")
    }

    private func tool(_ kind: TimelineOverlayTrackKind) -> DrawingTool {
        switch kind {
        case .text: return .text
        case .callout: return .arrow
        case .highlight: return .highlight
        case .rectangle: return .rectangle
        case .circle: return .circle
        case .line: return .line
        }
    }
}
