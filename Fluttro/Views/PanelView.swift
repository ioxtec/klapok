import SwiftUI

struct PanelView: View {
    @State var showPanel = true
 
    var body: some View {
        EmptyView()
            .floatingPanel(isPresented: $showPanel) {
                VisualEffectView(material: NSVisualEffectView.Material.sidebar, blendingMode: NSVisualEffectView.BlendingMode.behindWindow)
                Button(action: {
                    // Code
                }) {
                    Text("Borderless")
                        .buttonStyle(.plain)
                }
            }
    }
}

#Preview {
    PanelView()
}
