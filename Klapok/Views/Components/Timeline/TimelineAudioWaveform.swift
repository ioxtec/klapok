import SwiftUI

struct TimelineAudioWaveform: View {
    let levels: [CGFloat]
    var tint: Color = .teal

    var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }
            var path = Path()
            for (index, level) in levels.enumerated() {
                let x = CGFloat(index) / CGFloat(levels.count) * size.width
                let height = max(0.5, level * (size.height - 8))
                path.move(to: CGPoint(x: x, y: (size.height - height) / 2))
                path.addLine(to: CGPoint(x: x, y: (size.height + height) / 2))
            }
            context.stroke(path, with: .color(tint), lineWidth: 1)
        }
    }
}
