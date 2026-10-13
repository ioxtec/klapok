import SwiftUI

struct VideoPreviewView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    let video: VideoRecording

    var body: some View {
        GeometryReader { geometry in
            let size = CGSize(width: video.size.width * viewModel.cropRect.width,
                              height: video.size.height * viewModel.cropRect.height)
            let frame = QuickEditGeometry.aspectFit(size, in: geometry.size)
            VideoPlayerView(videoURL: video.url, viewModel: viewModel)
                .overlay(alignment: .top) {
                    if viewModel.isPreparingPreview { ProgressView().padding(8) }
                }
                .overlay {
                    if let id = viewModel.placingOverlayID {
                        Rectangle().fill(Color.accentColor.opacity(0.08))
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                                guard var track = viewModel.overlayTracks.first(where: { $0.id == id }),
                                      frame.width > 0, frame.height > 0 else { return }
                                track.x = max(0, min(0.95, (value.startLocation.x - frame.minX) / frame.width))
                                track.y = max(0, min(0.95, (value.startLocation.y - frame.minY) / frame.height))
                                if track.kind != .text {
                                    let dx = (value.location.x - value.startLocation.x) / frame.width
                                    let dy = (value.location.y - value.startLocation.y) / frame.height
                                    if track.kind == .highlight {
                                        track.x = min(track.x, max(0, (value.location.x - frame.minX) / frame.width))
                                        track.y = min(track.y, max(0, (value.location.y - frame.minY) / frame.height))
                                        track.width = max(0.02, abs(dx)); track.height = max(0.02, abs(dy))
                                    } else {
                                        track.width = dx; track.height = dy
                                    }
                                }
                                viewModel.updateOverlay(track)
                                viewModel.placingOverlayID = nil
                            })
                            .overlay(alignment: .top) {
                                HStack {
                                    Text("Click to place text, or drag to draw an arrow or highlight.".localized)
                                    Button("Cancel".localized) { viewModel.placingOverlayID = nil }
                                }.padding(8).background(.regularMaterial)
                            }
                    }
                }
        }
    }
}
