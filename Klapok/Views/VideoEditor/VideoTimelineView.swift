import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VideoTimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var layerInsertion: TimelineLayerInsertion?
    private let labelWidth: CGFloat = 144
    private let rulerHeight: CGFloat = 30
    private let layerHeight: CGFloat = 36
    private let videoHeight: CGFloat = 68
    private let audioHeight: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()
            GeometryReader { geometry in
                let viewport = max(1, geometry.size.width - labelWidth - 18)
                let pixelsPerSecond = max(1, viewport / max(1, viewModel.editedDuration) * viewModel.zoomScale)
                let contentWidth = max(viewport, CGFloat(viewModel.editedDuration) * pixelsPerSecond)
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        trackLabels
                        ScrollView(.horizontal) {
                            ZStack(alignment: .topLeading) {
                                VStack(spacing: 4) {
                                    TimelineTimeRuler(duration: viewModel.editedDuration, width: contentWidth,
                                        pixelsPerSecond: pixelsPerSecond, onScrub: { viewModel.updateCurrentTime(to: $0) })
                                        .frame(height: rulerHeight)
                                    ForEach(Array(viewModel.overlayTracks.reversed())) { track in
                                        VideoAnnotationLane(track: track, viewModel: viewModel,
                                            pixelsPerSecond: pixelsPerSecond, width: contentWidth)
                                            .frame(height: layerHeight)
                                            .modifier(TimelineLayerInsertionMarker(id: track.id.uuidString,
                                                insertion: layerInsertion))
                                    }
                                    videoLane(width: contentWidth, pixelsPerSecond: pixelsPerSecond)
                                        .frame(height: videoHeight)
                                    audioLane(width: contentWidth, pixelsPerSecond: pixelsPerSecond)
                                        .frame(height: audioHeight)
                                }
                                Rectangle().fill(Color.accentColor)
                                    .frame(width: 1, height: rulerHeight + CGFloat(viewModel.overlayTracks.count) * (layerHeight + 4) + videoHeight + audioHeight + 8)
                                    .overlay(alignment: .top) {
                                        Image(systemName: "arrowtriangle.down.fill").font(.system(size: 10)).foregroundStyle(Color.accentColor)
                                    }
                                    .offset(x: CGFloat(viewModel.currentTime) * pixelsPerSecond)
                                    .allowsHitTesting(false)
                            }
                            .frame(width: contentWidth)
                            .padding(.horizontal, 8).padding(.bottom, 8)
                            .task(id: "\(viewModel.video?.url.path ?? "")-\(Int(contentWidth))") {
                                await viewModel.loadTimelineThumbnails(for: contentWidth)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.025))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("video.timeline")
    }

    private var commandBar: some View {
        HStack(spacing: 10) {
            Button { viewModel.stepFrame(-1) } label: { Image(systemName: "backward.end.fill") }
                .help("Previous frame".localized).accessibilityIdentifier("video.previousFrame")
            Button { viewModel.togglePlayback() } label: { Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill") }
                .help((viewModel.isPlaying ? "Pause" : "Play").localized)
                .accessibilityIdentifier("video.playPause")
                .accessibilityValue(viewModel.isPlaying ? "playing" : "paused")
            Button { viewModel.stopPlayback() } label: { Image(systemName: "stop.fill") }
                .help("Stop".localized).accessibilityIdentifier("video.stop")
            Button { viewModel.stepFrame(1) } label: { Image(systemName: "forward.end.fill") }
                .help("Next frame".localized).accessibilityIdentifier("video.nextFrame")
            Divider().frame(height: 18)
            Button { viewModel.splitAtPlayhead() } label: { Label("Split".localized, systemImage: "scissors") }
                .disabled(!viewModel.canSplit)
            Button { viewModel.mergeSelectedClips() } label: { Image(systemName: "link") }
                .disabled(!viewModel.canMerge).help("Merge".localized)
            Button { viewModel.removeTimelineSelection() } label: { Image(systemName: "trash") }
                .disabled(viewModel.selectedOverlayID == nil && !viewModel.canRemove).help("Remove".localized)
            AnnotationLayerMenu(viewModel: viewModel)
            Spacer(minLength: 8)
            Text("\(timelineTime(viewModel.currentTime)) / \(timelineTime(viewModel.editedDuration))")
                .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            Button { viewModel.zoomOut() } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(!viewModel.canZoomOut)
            Slider(value: Binding(get: { viewModel.zoomScale }, set: { viewModel.updateZoomScale($0) }), in: 0.55...3.5)
                .frame(width: 100).controlSize(.small)
            Button { viewModel.zoomIn() } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(!viewModel.canZoomIn)
            Button("Fit".localized) { viewModel.updateZoomScale(1) }
        }
        .buttonStyle(.borderless).controlSize(.small)
        .padding(.horizontal, 12).frame(height: 38)
    }

    private var trackLabels: some View {
        VStack(spacing: 4) {
            HStack { Text("Tracks".localized).font(.caption).foregroundStyle(.secondary); Spacer() }
                .frame(height: rulerHeight)
            ForEach(Array(viewModel.overlayTracks.reversed().enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 7) {
                    TimelineLayerReorderHandle(id: track.id.uuidString,
                        visualOrder: viewModel.overlayTracks.reversed().map { $0.id.uuidString },
                        rowStride: layerHeight + 4, help: "Drag to reorder layers".localized,
                        insertion: $layerInsertion,
                        onBegin: { viewModel.pausePlayback(); viewModel.selectOverlay(track.id) },
                        onMove: moveLayer)
                    Image(systemName: track.kind.icon).foregroundStyle(.purple).frame(width: 16)
                    Text(track.title).font(.caption).lineLimit(1)
                    Spacer(minLength: 2)
                    Button { viewModel.removeOverlay(track.id) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                        .buttonStyle(.plain).help("Delete annotation".localized)
                }
                .padding(.horizontal, 8).frame(height: layerHeight)
                .background(viewModel.selectedOverlayID == track.id ? Color.purple.opacity(0.12) : .clear)
                .contentShape(Rectangle()).onTapGesture(count: 2) { viewModel.editOverlay(track.id) }
                .onTapGesture { viewModel.selectOverlay(track.id) }
                .contextMenu { Button("Edit".localized) { viewModel.editOverlay(track.id) } }
                .modifier(TimelineLayerInsertionMarker(id: track.id.uuidString,
                    insertion: layerInsertion))
                .accessibilityIdentifier("video.layer.\(index)")
            }
            trackLabel("Video".localized, icon: "film", height: videoHeight)
            trackLabel(viewModel.hasAudioTrack ? "Audio".localized : "No audio".localized,
                icon: viewModel.hasAudioTrack ? "waveform" : "speaker.slash", height: audioHeight)
                .opacity(viewModel.hasAudioTrack ? 1 : 0.35)
        }.padding(.horizontal, 6).frame(width: labelWidth).background(Color.primary.opacity(0.02))
    }

    private func trackLabel(_ title: String, icon: String, height: CGFloat) -> some View {
        HStack(spacing: 7) { Image(systemName: icon).frame(width: 16); Text(title).font(.caption); Spacer() }
            .foregroundStyle(.secondary).padding(.horizontal, 8).frame(height: height)
    }

    private func moveLayer(_ source: String, _ target: String, _ above: Bool) {
        guard let source = UUID(uuidString: source), let target = UUID(uuidString: target) else { return }
        viewModel.moveOverlay(source, relativeTo: target, above: above)
    }

    private func videoLane(width: CGFloat, pixelsPerSecond: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(viewModel.clips) { clip in
                VideoTimelineFilmstrip(clip: clip, viewModel: viewModel,
                    width: CGFloat(clip.duration) * pixelsPerSecond)
                    .onDrag { viewModel.draggedTimelineClipID = clip.id; return NSItemProvider(object: clip.id.uuidString as NSString) }
                    .onDrop(of: [UTType.text], delegate: VideoClipDropTarget(destination: clip.id, viewModel: viewModel))
            }
            Color.clear.frame(width: max(0, width - CGFloat(viewModel.editedDuration) * pixelsPerSecond))
                .onDrop(of: [UTType.text], delegate: VideoClipDropTarget(destination: nil, viewModel: viewModel))
        }.frame(width: width, alignment: .leading).background(Color.primary.opacity(0.03))
    }

    private func audioLane(width: CGFloat, pixelsPerSecond: CGFloat) -> some View {
        HStack(spacing: 0) {
            if viewModel.hasAudioTrack {
                ForEach(viewModel.clips) { clip in
                    TimelineAudioWaveform(levels: viewModel.audioLevels(for: clip,
                        sampleCount: max(12, Int(clip.duration * pixelsPerSecond / 3))))
                        .frame(width: CGFloat(clip.duration) * pixelsPerSecond)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: width).background(viewModel.hasAudioTrack ? Color.teal.opacity(0.14) : Color.primary.opacity(0.02))
        .overlay { if !viewModel.hasAudioTrack { Text("No audio".localized).font(.caption2).foregroundStyle(.tertiary) } }
        .opacity(viewModel.hasAudioTrack ? 1 : 0.45)
        .accessibilityIdentifier("video.audioTrack")
        .accessibilityValue(viewModel.hasAudioTrack ? "available" : "unavailable")
    }
}

struct AnnotationLayerMenu: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    var body: some View {
        Menu {
            ForEach(TimelineOverlayTrackKind.allCases, id: \.self) { kind in
                Button { viewModel.addOverlayTrack(kind: kind) } label: { Label(kind.displayName, systemImage: kind.icon) }
                    .accessibilityIdentifier("video.add.\(kind.rawValue)")
            }
        } label: { Label("Add annotation".localized, systemImage: "plus") }
        .accessibilityIdentifier("video.addAnnotation")
    }
}

private struct VideoTimelineFilmstrip: View {
    @State private var isRenaming = false
    @State private var editedName = ""
    let clip: VideoTimelineClip
    @ObservedObject var viewModel: VideoEditorViewModel
    let width: CGFloat
    var body: some View {
        let thumbnails = viewModel.clipThumbnails(for: clip, targetCount: max(1, Int(width / 72)))
        ZStack(alignment: .bottomLeading) {
            Color.blue.opacity(0.15)
            HStack(spacing: 0) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, thumbnail in
                    Image(nsImage: thumbnail).resizable().scaledToFill().frame(width: width / CGFloat(max(1, thumbnails.count)), height: 60).clipped()
                }
            }
            if thumbnails.isEmpty {
                if viewModel.isLoadingTimelineThumbnails {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Button("Reload previews".localized) {
                        Task { await viewModel.loadTimelineThumbnails(for: max(72, width)) }
                    }
                    .font(.caption2).buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            HStack(spacing: 3) {
                Text(clip.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                Button(action: beginRenaming) {
                    Image(systemName: "pencil").font(.system(size: 10))
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Rename clip…".localized)
                .accessibilityLabel("Rename clip…".localized)
                .accessibilityIdentifier("video.renameClip.\(clip.id.uuidString)")
                .layoutPriority(1)
            }
            .padding(.leading, 6).padding(.trailing, 2)
            .background(.regularMaterial)
            .frame(maxWidth: max(1, width), alignment: .leading)
        }
        .frame(width: max(1, width), height: 60).clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).stroke(viewModel.selectedClipIDs.contains(clip.id) ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: viewModel.selectedClipIDs.contains(clip.id) ? 2 : 1) }
        .contentShape(Rectangle())
        .accessibilityIdentifier("video.clip.\(clip.id.uuidString)")
        .accessibilityValue(thumbnails.isEmpty ? "empty" : "frames")
        .onTapGesture(count: 2) { beginRenaming() }
        .onTapGesture { viewModel.selectClip(clip.id, extendSelection: NSApp.currentEvent?.modifierFlags.contains(.command) == true) }
        .contextMenu {
            Button("Rename clip…".localized) { beginRenaming() }
        }
        .alert("Edit clip name".localized, isPresented: $isRenaming) {
            TextField("Clip name".localized, text: $editedName)
            Button("Cancel".localized, role: .cancel) {}
            Button("Save".localized) { viewModel.renameClip(clip.id, to: editedName) }
        }
    }

    private func beginRenaming() {
        viewModel.selectClip(clip.id, extendSelection: false)
        editedName = clip.name
        isRenaming = true
    }
}

private struct VideoClipDropTarget: DropDelegate {
    let destination: UUID?
    let viewModel: VideoEditorViewModel
    func dropEntered(info: DropInfo) { if let id = viewModel.draggedTimelineClipID { viewModel.moveClip(id, before: destination) } }
    func performDrop(info: DropInfo) -> Bool { viewModel.draggedTimelineClipID = nil; return true }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}
