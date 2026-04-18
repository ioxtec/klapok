//
//  CaptureDisplay.swift
//  Fluttro
//
//  Display model and resolver used by multi-monitor capture flows.
//

import Foundation

#if os(macOS)
import AppKit
import CoreGraphics
import ScreenCaptureKit

struct CaptureDisplay: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let index: Int
    let frame: CGRect
    let visibleFrame: CGRect
    let logicalSize: CGSize
    let pixelSize: CGSize
    let localizedName: String
    let isMain: Bool

    var title: String {
        localizedName.isEmpty ? "Display \(index)" : localizedName
    }

    var subtitle: String {
        "\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px"
    }

    var aspectRatio: CGFloat {
        guard logicalSize.height > 0 else { return 16.0 / 9.0 }
        return max(0.35, min(logicalSize.width / logicalSize.height, 3.2))
    }
}

enum CaptureDisplayResolver {
    static var availableDisplays: [CaptureDisplay] {
        NSScreen.screens.enumerated().map { offset, screen in
            let displayID = ScreenPixelGeometry.displayID(for: screen)
            return CaptureDisplay(
                id: displayID,
                index: offset + 1,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                logicalSize: screen.frame.size,
                pixelSize: ScreenPixelGeometry.pixelSize(for: screen),
                localizedName: screen.localizedName,
                isMain: screen == NSScreen.main
            )
        }
    }

    static var mainDisplayID: CGDirectDisplayID? {
        NSScreen.main.map { ScreenPixelGeometry.displayID(for: $0) }
    }

    static func display(for id: CGDirectDisplayID?) -> CaptureDisplay? {
        guard let id else { return nil }
        return availableDisplays.first { $0.id == id }
    }

    static func screen(for id: CGDirectDisplayID?) -> NSScreen? {
        guard let id else { return NSScreen.main }
        return NSScreen.screens.first { ScreenPixelGeometry.displayID(for: $0) == id }
    }

    static func screen(containing rect: CGRect) -> NSScreen? {
        ScreenPixelGeometry.screen(containing: rect)
    }

    static func scDisplay(for id: CGDirectDisplayID?, in content: SCShareableContent) -> SCDisplay? {
        if let id, let display = content.displays.first(where: { $0.displayID == id }) {
            return display
        }

        if let mainID = mainDisplayID,
           let display = content.displays.first(where: { $0.displayID == mainID }) {
            return display
        }

        return content.displays.first
    }

    static func scDisplay(containing rect: CGRect, in content: SCShareableContent) -> SCDisplay? {
        let screen = screen(containing: rect)
        return scDisplay(for: screen.map { ScreenPixelGeometry.displayID(for: $0) }, in: content)
    }
}

#endif
