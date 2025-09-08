//
//  ScreenshotService.swift
//  Fluttro
//
//  Captures screen (entire display or window) and returns NSImage.
//

import Foundation
#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia
import CoreVideo

enum ScreenshotError: Error {
    case unavailable
    case noDisplays
    case frameConversionFailed
}

/// Provides APIs to capture screenshots.
final class ScreenshotService {
    /// Captures the entire main display and returns an NSImage using ScreenCaptureKit.
    @MainActor
    func captureMainDisplay() async throws -> NSImage {
        guard #available(macOS 13.0, *) else { throw ScreenshotError.unavailable }

        let content = try await SCShareableContent.current
        guard let mainNSScreen = NSScreen.main else { throw ScreenshotError.noDisplays }

        // Match SCDisplay to NSScreen by displayID
        let displays = content.displays
        guard let display = displays.first(where: { $0.displayID == mainNSScreen.displayID }) ?? displays.first else {
            throw ScreenshotError.noDisplays
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        final class FrameCollector: NSObject, SCStreamOutput {
            var continuation: CheckedContinuation<NSImage, Error>?
            private let ciContext = CIContext()

            func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
                guard outputType == SCStreamOutputType.screen, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                let ciImage = CIImage(cvImageBuffer: pb)
                guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                if let continuation {
                    self.continuation = nil
                    continuation.resume(returning: nsImage)
                    Task { try? await stream.stopCapture() }
                }
            }
        }

        let output = FrameCollector()
        try stream.addStreamOutput(output, type: SCStreamOutputType.screen, sampleHandlerQueue: DispatchQueue.main)

        try await stream.startCapture()

        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            output.continuation = continuation
        }

        try? await stream.stopCapture()

        return image
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

#endif

