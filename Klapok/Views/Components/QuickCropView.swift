import SwiftUI

/// Shared image/video crop selector. The crop is applied only after confirmation.
struct QuickCropView: View {
    let image: NSImage?
    let sourceSize: CGSize
    let onApply: (CGRect) -> Void
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selection = QuickEditGeometry.fullFrame

    var body: some View {
        VStack(spacing: 12) {
            Text("Crop".localized).font(.headline)
            Text("Drag to select the area to keep.".localized).foregroundStyle(.secondary)
            GeometryReader { geometry in
                let frame = QuickEditGeometry.aspectFit(sourceSize, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.12)
                    if let image {
                        Image(nsImage: image).resizable().frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                    }
                    Rectangle().stroke(.white, lineWidth: 2)
                        .background(Color.accentColor.opacity(0.15))
                        .frame(width: selection.width * frame.width, height: selection.height * frame.height)
                        .offset(x: frame.minX + selection.minX * frame.width,
                                y: frame.minY + selection.minY * frame.height)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                    guard frame.width > 0, frame.height > 0 else { return }
                    let start = CGPoint(x: (value.startLocation.x - frame.minX) / frame.width,
                                        y: (value.startLocation.y - frame.minY) / frame.height)
                    let end = CGPoint(x: (value.location.x - frame.minX) / frame.width,
                                      y: (value.location.y - frame.minY) / frame.height)
                    selection = QuickEditGeometry.normalizedCrop(CGRect(x: start.x, y: start.y,
                        width: end.x - start.x, height: end.y - start.y))
                })
            }
            HStack {
                Menu("Aspect ratio".localized) {
                    Button("1:1") { selectRatio(1) }
                    Button("16:9") { selectRatio(16.0 / 9) }
                    Button("4:3") { selectRatio(4.0 / 3) }
                }
                Button("Reset".localized) { selection = QuickEditGeometry.fullFrame }
                Spacer()
                Button("Cancel".localized) { close() }.keyboardShortcut(.cancelAction)
                Button("Apply crop".localized) { onApply(selection); close() }
                    .accessibilityIdentifier("editor.applyCrop")
                    .keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 720, height: 520)
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func selectRatio(_ ratio: Double) {
        let sourceRatio = sourceSize.width / max(1, sourceSize.height)
        let width = min(1, ratio / sourceRatio), height = min(1, sourceRatio / ratio)
        selection = CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }
}
