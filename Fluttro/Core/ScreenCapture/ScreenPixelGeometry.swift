//
//  ScreenPixelGeometry.swift
//  Fluttro
//
//  Helpers for keeping captures aligned to physical display pixels.
//

import Foundation

#if os(macOS)
import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenPixelGeometry {
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }

    static func screen(for displayID: CGDirectDisplayID?) -> NSScreen? {
        guard let displayID else { return NSScreen.main }
        return NSScreen.screens.first { self.displayID(for: $0) == displayID }
    }

    static func pixelSize(for screen: NSScreen?) -> CGSize {
        guard let screen else {
            return CGSize(width: 1920, height: 1080)
        }

        let displayID = displayID(for: screen)
        let pixelWidth = CGDisplayPixelsWide(displayID)
        let pixelHeight = CGDisplayPixelsHigh(displayID)
        let backingSize = pixelSize(for: screen.frame, on: screen)

        if pixelWidth > 0, pixelHeight > 0 {
            return largerPixelSize(
                CGSize(width: pixelWidth, height: pixelHeight),
                backingSize
            )
        }

        return backingSize
    }

    static func captureSize(for screen: NSScreen?, mode: CapturePixelMode) -> CGSize {
        guard let screen else {
            return CGSize(width: 1920, height: 1080)
        }

        switch mode {
        case .realPixels:
            return pixelSize(for: screen)
        case .scaledScreenSize:
            return roundedSize(screen.frame.size)
        }
    }

    static func pixelSize(for display: SCDisplay) -> CGSize {
        CGSize(width: max(1, display.width), height: max(1, display.height))
    }

    static func captureSize(for display: SCDisplay, screen: NSScreen?, mode: CapturePixelMode) -> CGSize {
        switch mode {
        case .realPixels:
            return largerPixelSize(pixelSize(for: display), pixelSize(for: screen))
        case .scaledScreenSize:
            return roundedSize(screen?.frame.size ?? display.frame.size)
        }
    }

    static func pixelSize(for rect: CGRect, on screen: NSScreen?) -> CGSize {
        let scale = screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        return CGSize(
            width: max(1, (rect.width * scale).rounded()),
            height: max(1, (rect.height * scale).rounded())
        )
    }

    static func captureSize(for rect: CGRect, on screen: NSScreen?, mode: CapturePixelMode) -> CGSize {
        switch mode {
        case .realPixels:
            return pixelSize(for: rect, on: screen)
        case .scaledScreenSize:
            return roundedSize(rect.size)
        }
    }

    static func pixelSize(for window: SCWindow) -> CGSize {
        pixelSize(for: window.frame, on: screen(containing: window.frame))
    }

    static func captureSize(for window: SCWindow, mode: CapturePixelMode) -> CGSize {
        switch mode {
        case .realPixels:
            return pixelSize(for: window)
        case .scaledScreenSize:
            return roundedSize(window.frame.size)
        }
    }

    static func pixelSize(for image: NSImage) -> CGSize {
        if let representation = image.representations
            .filter({ $0.pixelsWide > 0 && $0.pixelsHigh > 0 })
            .max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }

        var proposedRect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }

        return roundedSize(image.size)
    }

    static func screen(containing rect: CGRect) -> NSScreen? {
        let intersectingScreens = NSScreen.screens
            .map { screen in
                (screen: screen, area: rect.intersection(screen.frame).area)
            }
            .filter { $0.area > 0 }

        return intersectingScreens.max { $0.area < $1.area }?.screen ?? NSScreen.main
    }

    private static func roundedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: max(1, size.width.rounded()),
            height: max(1, size.height.rounded())
        )
    }

    private static func largerPixelSize(_ lhs: CGSize, _ rhs: CGSize) -> CGSize {
        lhs.width * lhs.height >= rhs.width * rhs.height ? lhs : rhs
    }
}

extension NSImage {
    var pixelSize: CGSize {
        ScreenPixelGeometry.pixelSize(for: self)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}

#endif
