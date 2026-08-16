//
//  GradientEditorView.swift
//  Fluttro
//
//  Gradient editor for creating custom gradients
//

import SwiftUI
import AppKit

@MainActor
private final class GradientEditorViewState: ObservableObject {
    @Published var gradientName = ""
    @Published var direction: GradientDirection = .topLeadingToBottomTrailing
    @Published var opacity: Double = 1.0
    @Published var stops: [EditableGradientStop] = [
        EditableGradientStop(color: Color(red: 0.98, green: 0.29, blue: 0.36), location: 0),
        EditableGradientStop(color: Color(red: 0.77, green: 0.22, blue: 0.91), location: 1)
    ]
}

struct GradientEditorView: View {
    @ObservedObject var backgroundManager: BackgroundManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewState = GradientEditorViewState()

    private let minimumStopCount = 2
    private let maximumStopCount = 6

    private var gradientName: String {
        get { viewState.gradientName }
        nonmutating set { viewState.gradientName = newValue }
    }

    private var direction: GradientDirection {
        get { viewState.direction }
        nonmutating set { viewState.direction = newValue }
    }

    private var opacity: Double {
        get { viewState.opacity }
        nonmutating set { viewState.opacity = newValue }
    }

    private var stops: [EditableGradientStop] {
        get { viewState.stops }
        nonmutating set { viewState.stops = newValue }
    }

    private var gradientNameBinding: Binding<String> {
        Binding(get: { gradientName }, set: { gradientName = $0 })
    }

    private var directionBinding: Binding<GradientDirection> {
        Binding(get: { direction }, set: { direction = $0 })
    }

    private var opacityBinding: Binding<Double> {
        Binding(get: { opacity }, set: { opacity = $0 })
    }

    private var stopsBinding: Binding<[EditableGradientStop]> {
        Binding(get: { stops }, set: { stops = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    nameField
                    directionPicker
                    colorStopsEditor
                    opacitySlider
                }
                .padding(22)
            }

            Divider()

            footer
        }
        .frame(width: 520, height: 640)
        .centeredSheetWindow()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Create Gradient")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Build a reusable background from color stops, direction, and opacity.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var preview: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(
                gradient: Gradient(stops: gradientStops),
                startPoint: direction.startPoint,
                endPoint: direction.endPoint
            ))
            .frame(height: 132)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.callout)

            TextField("Gradient name", text: gradientNameBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direction")
                .font(.callout)

            Picker("", selection: directionBinding) {
                ForEach(GradientDirection.allCases) { direction in
                    Text(direction.shortName).tag(direction)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var colorStopsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Color Stops")
                        .font(.callout)

                    Text("Set where each color lands in the gradient.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    addStop()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .controlSize(.small)
                .disabled(stops.count >= maximumStopCount)
            }

            VStack(spacing: 8) {
                ForEach(stopsBinding) { $stop in
                    GradientStopRow(
                        stop: $stop,
                        canDelete: stops.count > minimumStopCount,
                        onDelete: {
                            removeStop(withId: stop.id)
                        }
                    )
                }
            }
        }
    }

    private var opacitySlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Opacity")
                    .font(.callout)

                Spacer()

                Text("\(Int(opacity * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(value: opacityBinding, in: 0.1...1.0, step: 0.1)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Create Gradient") {
                createGradient()
            }
            .buttonStyle(.borderedProminent)
            .disabled(gradientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var gradientStops: [Gradient.Stop] {
        normalizedStops.map {
            Gradient.Stop(color: $0.color.opacity(opacity), location: $0.location)
        }
    }

    private var normalizedStops: [EditableGradientStop] {
        stops
            .map {
                EditableGradientStop(
                    id: $0.id,
                    color: $0.color,
                    location: min(max($0.location, 0), 1)
                )
            }
            .sorted { $0.location < $1.location }
    }

    private func addStop() {
        guard stops.count < maximumStopCount else { return }

        let sortedStops = normalizedStops
        let largestGap = sortedStops.adjacentPairs()
            .max { leftPair, rightPair in
                (leftPair.1.location - leftPair.0.location) < (rightPair.1.location - rightPair.0.location)
            }

        let location: Double
        let color: Color

        if let largestGap {
            location = (largestGap.0.location + largestGap.1.location) / 2
            color = largestGap.0.color
        } else {
            location = 0.5
            color = .white
        }

        stops.append(EditableGradientStop(color: color, location: location))
        stops.sort { $0.location < $1.location }
    }

    private func removeStop(withId id: UUID) {
        guard stops.count > minimumStopCount else { return }
        stops.removeAll { $0.id == id }
    }

    private func createGradient() {
        let trimmedName = gradientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelStops = normalizedStops.map {
            GradientStopData(
                id: $0.id,
                color: ColorData(color: $0.color),
                location: $0.location
            )
        }

        guard let firstStop = modelStops.first,
              let lastStop = modelStops.last
        else { return }

        let customGradient = CustomGradient(
            name: trimmedName,
            color1: firstStop.color,
            color2: lastStop.color,
            opacity: opacity,
            direction: direction,
            stops: modelStops
        )

        backgroundManager.addCustomGradient(customGradient)
        backgroundManager.selectGradient(withId: customGradient.id)
        dismiss()
    }
}

private struct EditableGradientStop: Identifiable {
    let id: UUID
    var color: Color
    var location: Double

    init(id: UUID = UUID(), color: Color, location: Double) {
        self.id = id
        self.color = color
        self.location = min(max(location, 0), 1)
    }
}

private struct GradientStopRow: View {
    @Binding var stop: EditableGradientStop
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RectangularColorPicker(color: $stop.color)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(stop.location * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $stop.location, in: 0...1, step: 0.01)
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canDelete)
            .help("Remove color stop")
        }
    }
}

private struct RectangularColorPicker: View {
    @Binding var color: Color

    var body: some View {
        ColorSwatchButton(color: $color)
        .frame(width: 52, height: 36)
        .help("Edit color")
    }
}

private struct ColorSwatchButton: NSViewRepresentable {
    @Binding var color: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color)
    }

    func makeNSView(context: Context) -> ColorSwatchNSView {
        let view = ColorSwatchNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ColorSwatchNSView, context: Context) {
        context.coordinator.color = $color
        nsView.color = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    }

    final class Coordinator: NSObject {
        var color: Binding<Color>
        weak var activeSwatch: ColorSwatchNSView?

        init(color: Binding<Color>) {
            self.color = color
        }

        @objc func colorDidChange(_ sender: NSColorPanel) {
            color.wrappedValue = Color(sender.color)
            activeSwatch?.color = sender.color
        }
    }
}

private final class ColorSwatchNSView: NSView {
    weak var coordinator: ColorSwatchButton.Coordinator?

    var color: NSColor = .systemBlue {
        didSet {
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        color.setFill()
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focusPath = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4)
            focusPath.lineWidth = 2
            focusPath.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        openColorPanel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            openColorPanel()
        } else {
            super.keyDown(with: event)
        }
    }

    private func openColorPanel() {
        guard let coordinator else { return }

        coordinator.activeSwatch = self

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = color
        panel.setTarget(coordinator)
        panel.setAction(#selector(ColorSwatchButton.Coordinator.colorDidChange(_:)))
        panel.makeKeyAndOrderFront(nil)
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { ($0, $1) }
    }
}
