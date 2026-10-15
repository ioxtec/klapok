import Foundation

/// Storage order is back-to-front; a visual row above another renders in front.
enum TimelineLayerOrder {
    static func destination<ID: Equatable>(for source: ID, translation: CGFloat, rowStride: CGFloat,
        in visualOrder: [ID]) -> (target: ID, above: Bool)? {
        guard let index = visualOrder.firstIndex(of: source), rowStride > 0,
              translation.isFinite else { return nil }
        let offset = max(-CGFloat(visualOrder.count), min(CGFloat(visualOrder.count), translation / rowStride))
        let destination = max(0, min(visualOrder.count - 1, index + Int(offset.rounded())))
        guard destination != index else { return nil }
        return (visualOrder[destination], destination < index)
    }

    static func moving<ID: Equatable>(_ source: ID, relativeTo target: ID, above: Bool, in layers: [ID]) -> [ID] {
        guard source != target, layers.contains(source), layers.contains(target) else { return layers }
        var result = layers.filter { $0 != source }
        guard let targetIndex = result.firstIndex(of: target) else { return layers }
        result.insert(source, at: targetIndex + (above ? 1 : 0))
        return result
    }
}
