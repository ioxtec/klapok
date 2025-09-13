//
//  ScreenshotService.swift
//  Fluttro
//
//  Captures screen (entire display or window) and returns NSImage.
//

import Foundation

#if os(macOS)
    import AppKit
    @preconcurrency import ScreenCaptureKit
    import CoreImage
    import CoreMedia
    import CoreVideo

    // ScreenshotError is now defined in Core/Models/ScreenshotModels.swift

    /// Provides APIs to capture screenshots.
    final class ScreenshotService {

        // MARK: - Frame Collector Helper

        private final class FrameCollector: NSObject, SCStreamOutput {
            var continuation: CheckedContinuation<NSImage, Error>?
            private let ciContext = CIContext()

            nonisolated func stream(
                _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType
            ) {
                Logger.d("FrameCollector: Received sample buffer, outputType: \(outputType)")

                guard outputType == SCStreamOutputType.screen else {
                    Logger.d("FrameCollector: Wrong output type, ignoring")
                    return
                }

                guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    Logger.e("FrameCollector: Failed to get image buffer from sample")
                    return
                }

                Logger.d("FrameCollector: Creating CIImage from buffer...")
                let ciImage = CIImage(cvImageBuffer: pb)

                Logger.d("FrameCollector: Creating CGImage from CIImage...")
                guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                    Logger.e("FrameCollector: Failed to create CGImage")
                    return
                }

                Logger.d("FrameCollector: Creating NSImage from CGImage...")
                let nsImage = NSImage(
                    cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                Logger.s("FrameCollector: NSImage created successfully, size: \(nsImage.size)")

                // Use MainActor for UI operations
                Task { @MainActor in
                    if let continuation = self.continuation {
                        Logger.d("FrameCollector: Resuming continuation with image")
                        self.continuation = nil
                        continuation.resume(returning: nsImage)
                    } else {
                        Logger.w("FrameCollector: WARNING - No continuation available!")
                    }
                }
            }
        }

        // MARK: - Full Screen Capture

        /// Captures the entire main display and returns an NSImage using ScreenCaptureKit.
        @MainActor
        func captureMainDisplay() async throws -> NSImage {
            guard #available(macOS 13.0, *) else { throw ScreenshotError.unavailable }

            // Spróbuj bezpośrednio - jeśli nie ma uprawnień, ScreenCaptureKit rzuci błąd
            let content: SCShareableContent

            // Spróbuj bezpośrednio - system sam pokaże dialog uprawnień jeśli potrzeba
            content = try await SCShareableContent.current
            guard let mainNSScreen = NSScreen.main else { throw ScreenshotError.noDisplays }

            // Match SCDisplay to NSScreen by displayID
            let displays = content.displays
            guard
                let display = displays.first(where: { $0.displayID == mainNSScreen.displayID })
                    ?? displays.first
            else {
                throw ScreenshotError.noDisplays
            }

            let filter = SCContentFilter(
                display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.showsCursor = false
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let output = FrameCollector()
            try stream.addStreamOutput(
                output, type: SCStreamOutputType.screen, sampleHandlerQueue: DispatchQueue.main)

            try await stream.startCapture()

            let image: NSImage = try await withCheckedThrowingContinuation { continuation in
                output.continuation = continuation
            }

            do {
                try await stream.stopCapture()
            } catch {
                Logger.w("Błąd podczas zatrzymywania streamu (można zignorować): \(error)")
            }

            return image
        }

        // MARK: - Timeout Helper

        @MainActor
        private func withTimeout<T>(
            seconds: TimeInterval, operation: @escaping () async throws -> T
        ) async throws -> T {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask {
                    try await operation()
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw ScreenshotError.unavailable  // Timeout error
                }

                guard let result = try await group.next() else {
                    throw ScreenshotError.unavailable
                }

                group.cancelAll()
                return result
            }
        }

        // MARK: - Public Area Capture

        // captureArea method is now implemented below (was captureAreaInternal)

        // MARK: - Public Window Capture

        /// Captures a specific window
        @MainActor
        func captureWindow(_ window: SCWindow) async throws -> NSImage {
            return try await captureWindowInternal(window)
        }

        // MARK: - Area Selection Capture
        // Note: Area selection is now handled by AreaSelectionManager in the UI layer

        @MainActor
        func captureArea(rect: NSRect) async throws -> NSImage {
            Logger.d("ScreenshotService: captureAreaInternal started with rect: \(rect)")

            guard #available(macOS 13.0, *) else {
                Logger.e("ScreenshotService: ERROR - macOS 13.0+ required")
                throw ScreenshotError.unavailable
            }

            Logger.d("ScreenshotService: Getting SCShareableContent...")
            let content = try await SCShareableContent.current
            Logger.s("ScreenshotService: SCShareableContent obtained successfully")

            guard let mainNSScreen = NSScreen.main else {
                Logger.e("ScreenshotService: ERROR - No main screen found")
                throw ScreenshotError.noDisplays
            }
            Logger.d("ScreenshotService: Main screen found: \(mainNSScreen.frame)")

            let displays = content.displays
            Logger.d("ScreenshotService: Found \(displays.count) displays")

            guard
                let display = displays.first(where: { $0.displayID == mainNSScreen.displayID })
                    ?? displays.first
            else {
                Logger.e("ScreenshotService: ERROR - No matching display found")
                throw ScreenshotError.noDisplays
            }
            Logger.d("ScreenshotService: Using display: \(display.displayID)")

            // Convert screen coordinates to display coordinates
            let screenFrame = mainNSScreen.frame
            let displayRect = NSRect(
                x: rect.minX,
                y: screenFrame.height - rect.maxY,  // Flip Y coordinate
                width: rect.width,
                height: rect.height
            )
            Logger.d("ScreenshotService: Original rect: \(rect)")
            Logger.d("ScreenshotService: Screen frame: \(screenFrame)")
            Logger.d("ScreenshotService: Converted displayRect: \(displayRect)")

            Logger.d("ScreenshotService: Creating SCContentFilter...")
            let filter = SCContentFilter(
                display: display, excludingApplications: [], exceptingWindows: [])

            Logger.d("ScreenshotService: Creating SCStreamConfiguration...")
            let config = SCStreamConfiguration()
            config.width = Int(rect.width)
            config.height = Int(rect.height)
            config.sourceRect = CGRect(
                x: displayRect.minX, y: displayRect.minY, width: displayRect.width,
                height: displayRect.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.showsCursor = false
            Logger.d("ScreenshotService: Config - width: \(config.width), height: \(config.height)")
            Logger.d("ScreenshotService: Config - sourceRect: \(config.sourceRect)")

            Logger.d("ScreenshotService: Creating SCStream...")
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            Logger.d("ScreenshotService: Creating FrameCollector...")
            let output = FrameCollector()

            Logger.d("ScreenshotService: Adding stream output...")
            try stream.addStreamOutput(
                output, type: SCStreamOutputType.screen, sampleHandlerQueue: DispatchQueue.main)

            Logger.d("ScreenshotService: Starting stream capture...")
            try await stream.startCapture()
            Logger.s("ScreenshotService: Stream capture started successfully")

            Logger.d("ScreenshotService: Waiting for frame in continuation...")
            let image: NSImage = try await withTimeout(seconds: 10) {
                try await withCheckedThrowingContinuation { continuation in
                    output.continuation = continuation
                    Logger.d("ScreenshotService: Continuation set, waiting for frame...")
                }
            }
            Logger.s("ScreenshotService: Frame received successfully!")

            Logger.d("ScreenshotService: Stopping stream capture...")
            do {
                try await stream.stopCapture()
                Logger.s("ScreenshotService: Stream stopped successfully")
            } catch {
                Logger.w("ScreenshotService: Error stopping stream (can ignore): \(error)")
            }

            Logger.s("ScreenshotService: captureAreaInternal completed successfully")
            return image
        }

        // MARK: - Window Capture

        /// Captures a specific application window selected by the user
        @MainActor
        func captureSelectedWindow() async throws -> NSImage {
            guard #available(macOS 13.0, *) else { throw ScreenshotError.unavailable }

            let content = try await SCShareableContent.current
            let windows = content.windows.filter { window in
                window.owningApplication != nil && window.frame.width > 50
                    && window.frame.height > 50 && !(window.title?.isEmpty ?? true)
            }

            guard !windows.isEmpty else {
                throw ScreenshotError.noWindowSelected
            }

            // Show window selection dialog
            let selectedWindow = try await showWindowSelectionDialog(windows: windows)

            guard let window = selectedWindow else {
                throw ScreenshotError.userCancelled
            }

            return try await captureWindowInternal(window)
        }

        private func showWindowSelectionDialog(windows: [SCWindow]) async throws -> SCWindow? {
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    let dialog = WindowSelectionDialog(windows: windows) { window in
                        continuation.resume(returning: window)
                    }
                    dialog.show()
                }
            }
        }

        @MainActor
        private func captureWindowInternal(_ window: SCWindow) async throws -> NSImage {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.showsCursor = false

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let output = FrameCollector()
            try stream.addStreamOutput(
                output, type: SCStreamOutputType.screen, sampleHandlerQueue: DispatchQueue.main)

            try await stream.startCapture()

            let image: NSImage = try await withCheckedThrowingContinuation { continuation in
                output.continuation = continuation
            }

            do {
                try await stream.stopCapture()
            } catch {
                Logger.w("Błąd podczas zatrzymywania streamu window (można zignorować): \(error)")
            }
            return image
        }
    }

    extension NSScreen {
        fileprivate var displayID: CGDirectDisplayID {
            return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                ?? 0
        }
    }

#endif
