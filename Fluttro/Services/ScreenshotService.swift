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

    enum ScreenshotError: Error {
        case unavailable
        case noDisplays
        case frameConversionFailed
        case userCancelled
        case noWindowSelected
    }

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
                print("FrameCollector: Received sample buffer, outputType: \(outputType)")

                guard outputType == SCStreamOutputType.screen else {
                    print("FrameCollector: Wrong output type, ignoring")
                    return
                }

                guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    print("FrameCollector: Failed to get image buffer from sample")
                    return
                }

                print("FrameCollector: Creating CIImage from buffer...")
                let ciImage = CIImage(cvImageBuffer: pb)

                print("FrameCollector: Creating CGImage from CIImage...")
                guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                    print("FrameCollector: Failed to create CGImage")
                    return
                }

                print("FrameCollector: Creating NSImage from CGImage...")
                let nsImage = NSImage(
                    cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                print("FrameCollector: NSImage created successfully, size: \(nsImage.size)")

                // Use MainActor for UI operations
                Task { @MainActor in
                    if let continuation = self.continuation {
                        print("FrameCollector: Resuming continuation with image")
                        self.continuation = nil
                        continuation.resume(returning: nsImage)
                    } else {
                        print("FrameCollector: WARNING - No continuation available!")
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
                print("Błąd podczas zatrzymywania streamu (można zignorować): \(error)")
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

        /// Captures a specific area of the screen
        @MainActor
        func captureArea(rect: NSRect) async throws -> NSImage {
            print("ScreenshotService.captureArea() rozpoczęte z rect: \(rect)")
            let result = try await captureAreaInternal(rect: rect)
            print("ScreenshotService.captureArea() zakończone pomyślnie")
            return result
        }

        // MARK: - Public Window Capture

        /// Captures a specific window
        @MainActor
        func captureWindow(_ window: SCWindow) async throws -> NSImage {
            return try await captureWindowInternal(window)
        }

        // MARK: - Area Selection Capture

        /// Captures a user-selected area of the screen using interactive selection
        @MainActor
        func captureSelectedArea() async throws -> NSImage {
            guard #available(macOS 13.0, *) else { throw ScreenshotError.unavailable }

            print("ScreenshotService: captureSelectedArea started")

            // First capture the full screen for overlay
            let fullScreenImage = try await captureMainDisplay()
            print("ScreenshotService: full screen captured")

            // Create selection overlay window
            let selectionResult = try await showAreaSelectionOverlay(
                backgroundImage: fullScreenImage)
            print(
                "ScreenshotService: overlay returned result: \(String(describing: selectionResult))"
            )

            guard let selectedRect = selectionResult else {
                print("ScreenshotService: user cancelled")
                throw ScreenshotError.userCancelled
            }

            print("ScreenshotService: capturing area: \(selectedRect)")
            // Capture the selected area
            let result = try await captureAreaInternal(rect: selectedRect)
            print("ScreenshotService: area captured successfully")
            return result
        }

        @MainActor
        private func showAreaSelectionOverlay(backgroundImage: NSImage) async throws -> NSRect? {
            print("ScreenshotService: showAreaSelectionOverlay started")
            return try await withCheckedThrowingContinuation { continuation in
                let overlay = AreaSelectionOverlay(backgroundImage: backgroundImage) { rect in
                    print(
                        "ScreenshotService: overlay completion called with rect: \(String(describing: rect))"
                    )
                    continuation.resume(returning: rect)
                }
                overlay.show()
                print("ScreenshotService: overlay.show() called")
            }
        }

        @MainActor
        private func captureAreaInternal(rect: NSRect) async throws -> NSImage {
            print("ScreenshotService: captureAreaInternal started with rect: \(rect)")

            guard #available(macOS 13.0, *) else {
                print("ScreenshotService: ERROR - macOS 13.0+ required")
                throw ScreenshotError.unavailable
            }

            print("ScreenshotService: Getting SCShareableContent...")
            let content = try await SCShareableContent.current
            print("ScreenshotService: SCShareableContent obtained successfully")

            guard let mainNSScreen = NSScreen.main else {
                print("ScreenshotService: ERROR - No main screen found")
                throw ScreenshotError.noDisplays
            }
            print("ScreenshotService: Main screen found: \(mainNSScreen.frame)")

            let displays = content.displays
            print("ScreenshotService: Found \(displays.count) displays")

            guard
                let display = displays.first(where: { $0.displayID == mainNSScreen.displayID })
                    ?? displays.first
            else {
                print("ScreenshotService: ERROR - No matching display found")
                throw ScreenshotError.noDisplays
            }
            print("ScreenshotService: Using display: \(display.displayID)")

            // Convert screen coordinates to display coordinates
            let screenFrame = mainNSScreen.frame
            let displayRect = NSRect(
                x: rect.minX,
                y: screenFrame.height - rect.maxY,  // Flip Y coordinate
                width: rect.width,
                height: rect.height
            )
            print("ScreenshotService: Original rect: \(rect)")
            print("ScreenshotService: Screen frame: \(screenFrame)")
            print("ScreenshotService: Converted displayRect: \(displayRect)")

            print("ScreenshotService: Creating SCContentFilter...")
            let filter = SCContentFilter(
                display: display, excludingApplications: [], exceptingWindows: [])

            print("ScreenshotService: Creating SCStreamConfiguration...")
            let config = SCStreamConfiguration()
            config.width = Int(rect.width)
            config.height = Int(rect.height)
            config.sourceRect = CGRect(
                x: displayRect.minX, y: displayRect.minY, width: displayRect.width,
                height: displayRect.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.capturesAudio = false
            config.showsCursor = false
            print("ScreenshotService: Config - width: \(config.width), height: \(config.height)")
            print("ScreenshotService: Config - sourceRect: \(config.sourceRect)")

            print("ScreenshotService: Creating SCStream...")
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            print("ScreenshotService: Creating FrameCollector...")
            let output = FrameCollector()

            print("ScreenshotService: Adding stream output...")
            try stream.addStreamOutput(
                output, type: SCStreamOutputType.screen, sampleHandlerQueue: DispatchQueue.main)

            print("ScreenshotService: Starting stream capture...")
            try await stream.startCapture()
            print("ScreenshotService: Stream capture started successfully")

            print("ScreenshotService: Waiting for frame in continuation...")
            let image: NSImage = try await withTimeout(seconds: 10) {
                try await withCheckedThrowingContinuation { continuation in
                    output.continuation = continuation
                    print("ScreenshotService: Continuation set, waiting for frame...")
                }
            }
            print("ScreenshotService: Frame received successfully!")

            print("ScreenshotService: Stopping stream capture...")
            do {
                try await stream.stopCapture()
                print("ScreenshotService: Stream stopped successfully")
            } catch {
                print("ScreenshotService: Error stopping stream (can ignore): \(error)")
            }

            print("ScreenshotService: captureAreaInternal completed successfully")
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
                print("Błąd podczas zatrzymywania streamu window (można zignorować): \(error)")
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
