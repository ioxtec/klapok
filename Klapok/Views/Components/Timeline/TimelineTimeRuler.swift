import SwiftUI

struct TimelineTimeRuler: View {
    let duration: Double
    let width: CGFloat
    let pixelsPerSecond: CGFloat
    let onScrub: (Double) -> Void
    private var step: Double { [0.1, 0.25, 0.5, 1, 2, 5, 10, 30, 60, 120, 300].first(where: { $0 * pixelsPerSecond >= 70 }) ?? 600 }

    var body: some View {
        Canvas { context, size in
            let count = min(5000, Int(Double(width / max(0.001, pixelsPerSecond)) / (step / 5)) + 1)
            for tick in 0..<count {
                let time = Double(tick) * step / 5, x = time * pixelsPerSecond
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x, y: size.height - (tick % 5 == 0 ? 9 : 4)))
                context.stroke(path, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                if tick % 5 == 0 {
                    context.draw(Text(timelineTime(time)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary),
                        at: CGPoint(x: x + 3, y: 4), anchor: .topLeading)
                }
            }
        }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
            onScrub(max(0, min(duration, value.location.x / max(0.001, pixelsPerSecond))))
        })
    }
}

func timelineTime(_ time: Double) -> String {
    let value = max(0, time)
    return String(format: "%02d:%04.1f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60))
}
