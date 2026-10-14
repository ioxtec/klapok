import SwiftUI

struct VideoPreviewView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    let video: VideoRecording
    @State private var draft: CGRect?
    @State private var draftStart: CGPoint?
    @State private var draftEnd: CGPoint?
    private let canvasCoordinateSpace = "videoPreviewCoordinates"

    var body: some View {
        GeometryReader { geometry in
            let size = CGSize(width: video.size.width * viewModel.cropRect.width, height: video.size.height * viewModel.cropRect.height)
            let frame = QuickEditGeometry.aspectFit(size, in: geometry.size)
            ZStack(alignment: .topLeading) {
                VideoPlayerView(videoURL: video.url, viewModel: viewModel)
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(SpatialTapGesture(coordinateSpace: .named(canvasCoordinateSpace)).onEnded { value in
                        let point = value.location
                        let hit = viewModel.overlayTracks.reversed().first { track in
                            guard viewModel.currentTime >= track.start && viewModel.currentTime < track.end else { return false }
                            return CGRect(x: track.x * frame.width, y: track.y * frame.height,
                                width: track.width * frame.width, height: track.height * frame.height)
                                .standardized.insetBy(dx: -8, dy: -8).contains(point)
                        }
                        if let hit { viewModel.selectOverlay(hit.id) }
                        else { viewModel.selectVideoAtPlayhead() }
                    })
                ForEach(viewModel.overlayTracks) { track in
                    if viewModel.currentTime >= track.start && viewModel.currentTime < track.end {
                        VideoCanvasAnnotation(track: track, viewModel: viewModel, canvasSize: frame.size)
                            .frame(width: frame.width, height: frame.height)
                            .allowsHitTesting(viewModel.activeAnnotationTool == nil)
                    }
                }
                if let kind = viewModel.activeAnnotationTool {
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .frame(width: frame.width, height: frame.height)
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(canvasCoordinateSpace)).onChanged { value in
                            draftStart = value.startLocation; draftEnd = value.location
                            draft = CGRect(x: value.startLocation.x, y: value.startLocation.y,
                                width: value.translation.width, height: value.translation.height).standardized
                        }.onEnded { value in
                            let start = normalized(value.startLocation, in: frame.size)
                            let end = normalized(value.location, in: frame.size)
                            viewModel.addOverlayTrack(kind: kind)
                            guard var track = viewModel.overlayTracks.last else { return }
                            track.color = ColorData(color: viewModel.annotationColor)
                            track.x = start.x; track.y = start.y
                            if kind != .text {
                                if kind == .line || kind == .callout {
                                    track.width = end.x - start.x; track.height = end.y - start.y
                                } else {
                                    track.x = min(start.x, end.x); track.y = min(start.y, end.y)
                                    track.width = max(0.02, abs(end.x - start.x)); track.height = max(0.02, abs(end.y - start.y))
                                }
                            } else {
                                track.text = ""; track.width = min(0.5, 1 - track.x); track.height = min(0.25, 1 - track.y)
                                viewModel.editingOverlayID = track.id
                            }
                            viewModel.updateOverlay(track, recordUndo: false)
                            viewModel.activeAnnotationTool = nil; draft = nil; draftStart = nil; draftEnd = nil
                        })
                    if let draft, kind != .text {
                        if (kind == .line || kind == .callout), let start = draftStart, let end = draftEnd {
                            VideoDirectionalStroke(start: start, end: end, arrow: kind == .callout)
                                .stroke(viewModel.annotationColor, style: StrokeStyle(lineWidth: max(1, viewModel.annotationStrokeWidth * frame.height / max(1, size.height)), lineCap: .round, lineJoin: .round))
                                .allowsHitTesting(false)
                        } else {
                            Rectangle().stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .frame(width: draft.width, height: draft.height)
                                .offset(x: draft.minX, y: draft.minY).allowsHitTesting(false)
                        }
                    }
                }
                if viewModel.isPreparingPreview { ProgressView().padding(8) }
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .coordinateSpace(name: canvasCoordinateSpace)
            .clipped()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("video.canvas")
            .accessibilityLabel(viewModel.selectedOverlayID == nil ? "Video preview".localized : "Video preview, annotation selected".localized)
            .offset(x: frame.minX, y: frame.minY)
        }
    }

    private func normalized(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: max(0, min(0.95, point.x / max(1, size.width))),
            y: max(0, min(0.95, point.y / max(1, size.height))))
    }
}
