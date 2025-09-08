//
//  EditorViewModel.swift
//  Fluttro
//

import Foundation
#if os(macOS)
import AppKit

final class EditorViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isPresented: Bool = false

    func show(image: NSImage) {
        self.image = image
        self.isPresented = true
    }

    func close() {
        self.isPresented = false
    }
}

#endif

