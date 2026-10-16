import Foundation

enum SidebarNumericValue {
    static func committed(_ text: String, range: ClosedRange<Double>,
                          displayMultiplier: Double = 1, allowsFraction: Bool = false) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[+-]?(?:[0-9]+(?:[.,][0-9]*)?|[.,][0-9]+)$"#,
                         options: .regularExpression) != nil,
              let displayed = Double(text.replacingOccurrences(of: ",", with: ".")),
              displayed.isFinite, displayMultiplier.isFinite, displayMultiplier > 0 else { return nil }
        let value = displayed / displayMultiplier
        let precise = allowsFraction ? value : value.rounded()
        return min(range.upperBound, max(range.lowerBound, precise))
    }

    static func snapped(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        guard value.isFinite, step.isFinite, step > 0 else { return range.lowerBound }
        let snapped = range.lowerBound + ((value - range.lowerBound) / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }
}
