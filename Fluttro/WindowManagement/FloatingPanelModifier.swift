//
//  FloatingPanelModifier.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

 
/// Add a  ``FloatingPanel`` to a view hierarchy
struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    /// Determines wheter the panel should be presented or not
    @Binding var isPresented: Bool
 
    /// Determines the starting size of the panel
    var contentRect: CGRect = CGRect(x: 0, y: 0, width: 624, height: 512)
 
    /// Holds the panel content's view closure
    @ViewBuilder let view: () -> PanelContent
 
    /// Stores the panel instance with the same generic type as the view closure
    @State var panel: FloatingPanel<PanelContent>?
 
    func body(content: Content) -> some View {
        content
            .onAppear {
                /// When the view appears, create, center and present the panel if ordered
                panel = FloatingPanel(view: view, contentRect: contentRect, isPresented: $isPresented)
                panel?.center()
                if isPresented {
                    present()
                }
            }.onDisappear {
                /// When the view disappears, close and kill the panel
                panel?.close()
                panel = nil
            }.onChange(of: isPresented) { value in
                /// On change of the presentation state, make the panel react accordingly
                if value {
                    present()
                } else {
                    panel?.close()
                }
            }
    }
 
    /// Present the panel and make it the key window
    func present() {
        panel?.orderFront(nil)
        panel?.makeKey()
    }
    
    
}
