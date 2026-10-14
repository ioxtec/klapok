import SwiftUI

struct VideoAnnotationToolbar: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    private var selected: TimelineOverlayTrack? { viewModel.overlayTracks.first(where: { $0.id == viewModel.selectedOverlayID }) }
    private var outputHeight: Double { max(1, (viewModel.video?.size.height ?? 800) * viewModel.cropRect.height) }

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
            if viewModel.activeAnnotationTool == .text || selected?.kind == .text {
                Stepper(value: Binding(get: { selected.map { $0.fontScale * outputHeight } ?? viewModel.annotationFontSize }, set: { size in
                    viewModel.annotationFontSize = size
                    if var track = selected { track.fontScale = size / outputHeight; viewModel.updateOverlay(track) }
                }), in: 8...96, step: 1) {
                    Text("\(Int(selected.map { $0.fontScale * outputHeight } ?? viewModel.annotationFontSize)) pt").font(.caption)
                }.fixedSize().help("Text size".localized)
            } else {
                Stepper(value: Binding(get: { selected.map { $0.strokeScale * outputHeight } ?? viewModel.annotationStrokeWidth }, set: { size in
                    viewModel.annotationStrokeWidth = size
                    if var track = selected { track.strokeScale = size / outputHeight; viewModel.updateOverlay(track) }
                }), in: 1...12, step: 1) {
                    Text("\(Int(selected.map { $0.strokeScale * outputHeight } ?? viewModel.annotationStrokeWidth)) px").font(.caption)
                }.fixedSize().help("Line width".localized)
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
