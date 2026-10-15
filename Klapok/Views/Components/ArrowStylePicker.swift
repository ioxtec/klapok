import SwiftUI

struct ArrowStylePicker: View {
    @Binding var selection: ArrowStyle

    var body: some View {
        Menu {
            ForEach(ArrowStyle.allCases, id: \.self) { style in
                Button { selection = style } label: {
                    Label(style.displayName.localized, systemImage: selection == style ? "checkmark" : "arrow.up.right")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Canvas { context, size in
                    let geometry = ArrowGeometry(start: CGPoint(x: 2, y: size.height - 3),
                        end: CGPoint(x: size.width - 2, y: 3), style: selection, headSize: 10, strokeWidth: 2)
                    context.stroke(Path(geometry.stroke), with: .foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    context.fill(Path(geometry.fill), with: .foreground)
                }.frame(width: 26, height: 22)
                Text("Arrow style".localized).font(.caption)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(selection.displayName.localized)
        .accessibilityLabel("Arrow style".localized)
        .accessibilityValue(selection.displayName.localized)
    }
}
