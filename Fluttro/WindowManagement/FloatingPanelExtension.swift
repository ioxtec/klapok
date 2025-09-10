//
//  FloatingPanelExtension.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

extension View {
    /// Present a `FloatingPanel` in SwiftUI style.
    func floatingPanel<Content: View>(
        isPresented: Binding<Bool>,
        contentRect: CGRect = CGRect(x: 0, y: 0, width: 624, height: 70),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(FloatingPanelModifier(isPresented: isPresented, contentRect: contentRect, view: content))
    }
}
