import SwiftUI

/// The two actual endpoints, not the bounding rectangle of a directional mark.
struct VideoDirectionalStroke: Shape {
    let start: CGPoint
    let end: CGPoint
    let arrow: Bool
    var headSize: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start); path.addLine(to: end)
        guard arrow, hypot(end.x - start.x, end.y - start.y) > 1 else { return path }
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = min(headSize, hypot(end.x - start.x, end.y - start.y) * 0.5)
        for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
            path.move(to: end)
            path.addLine(to: CGPoint(x: end.x - length * cos(angle + offset), y: end.y - length * sin(angle + offset)))
        }
        return path
    }
}
