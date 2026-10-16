import CoreGraphics

enum ArrowStyle: String, Codable, CaseIterable {
    case open
    case triangle
    case tapered

    var displayName: String {
        switch self {
        case .open: return "Open arrowhead"
        case .triangle: return "Triangle arrowhead"
        case .tapered: return "Tapered arrow"
        }
    }
}

/// Shared vector geometry for canvas previews, image export and video frames.
struct ArrowGeometry {
    let stroke: CGPath
    let fill: CGPath

    init(start: CGPoint, end: CGPoint, style: ArrowStyle, headSize: CGFloat, strokeWidth: CGFloat) {
        let stroke = CGMutablePath(), fill = CGMutablePath()
        self.stroke = stroke; self.fill = fill
        let distance = hypot(end.x - start.x, end.y - start.y)
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite,
              distance.isFinite, distance > 0.01 else { return }
        let ux = (end.x - start.x) / distance, uy = (end.y - start.y) / distance
        let length = min(max(headSize, strokeWidth * 3.5), distance * 0.45)
        let base = CGPoint(x: end.x - ux * length, y: end.y - uy * length)
        func side(_ point: CGPoint, _ offset: CGFloat) -> CGPoint {
            CGPoint(x: point.x - uy * offset, y: point.y + ux * offset)
        }
        switch style {
        case .open:
            let openLength = min(max(headSize, strokeWidth * 3.5), distance * 0.5)
            let openBase = CGPoint(x: end.x - ux * openLength * cos(.pi / 6),
                y: end.y - uy * openLength * cos(.pi / 6))
            stroke.move(to: start); stroke.addLine(to: end)
            stroke.move(to: side(openBase, openLength * 0.5)); stroke.addLine(to: end)
            stroke.addLine(to: side(openBase, -openLength * 0.5))
        case .triangle:
            stroke.move(to: start); stroke.addLine(to: base)
            fill.move(to: end); fill.addLine(to: side(base, length * 0.55))
            fill.addLine(to: side(base, -length * 0.55)); fill.closeSubpath()
        case .tapered:
            let shaftHalfWidth = min(length * 0.3, max(strokeWidth * 0.5, length * 0.16))
            fill.move(to: start)
            fill.addLine(to: side(base, shaftHalfWidth))
            fill.addLine(to: side(base, length * 0.6))
            fill.addLine(to: end)
            fill.addLine(to: side(base, -length * 0.6))
            fill.addLine(to: side(base, -shaftHalfWidth))
            fill.closeSubpath()
        }
    }
}
