import SwiftUI

struct SidebarNumericField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let displayMultiplier: Double
    @Environment(\.locale) private var locale
    @FocusState private var isFocused: Bool
    @State private var draft = ""

    var body: some View {
        HStack(spacing: 4) {
            TextField("", text: $draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .accessibilityLabel(Text(title.localized))
                .accessibilityIdentifier("sidebar.value.\(title)")
                .onSubmit { commit(); isFocused = false }
                .onExitCommand { resetDraft(); isFocused = false }
            if !unit.isEmpty {
                Text(unit).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .frame(width: unit.isEmpty ? 72 : 94)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
        }
        .onAppear { resetDraft() }
        .onChange(of: isFocused) { _, focused in if !focused { commit() } }
        .onChange(of: value) { _, _ in if !isFocused { resetDraft() } }
        .onChange(of: locale.identifier) { _, _ in if !isFocused { resetDraft() } }
    }

    private func commit() {
        if let entered = SidebarNumericValue.committed(draft, range: range,
            displayMultiplier: displayMultiplier, allowsFraction: step < 1) {
            value = entered
        }
        resetDraft()
    }

    private func resetDraft() {
        draft = (value * displayMultiplier).formatted(.number.locale(locale)
            .grouping(.never).precision(.fractionLength(0...3)))
    }
}
