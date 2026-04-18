//
//  FullScreenCaptureService.swift
//  Fluttro
//
//  Service for capturing full screen screenshots
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo

// MARK: - Full Screen Capture Service

/// Service responsible for capturing full screen screenshots
final class FullScreenCaptureService: ImageCaptureService {
    
    // MARK: - Properties
    
    /// Statistics tracking for this service
    private var statistics = CaptureStatistics()
    
    /// Timeout for capture operations
    private let captureTimeout: TimeInterval = 10.0
    
    // MARK: - ImageCaptureService Implementation
    
    func capture(request: CaptureRequest) async throws -> NSImage {
        guard request.mode == .image else {
            throw CaptureError.invalidConfiguration
        }
        
        let imageRequest = ImageCaptureRequest(type: request.type, configuration: .default)
        return try await captureImage(request: imageRequest)
    }
    
    func captureImage(request: ImageCaptureRequest) async throws -> NSImage {
        let startTime = Date()
        
        do {
            let image = try await performFullScreenCapture(
                displayID: request.displayID,
                configuration: request.configuration
            )
            
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: true, duration: duration)
            
            Logger.s("FullScreenCaptureService: Capture completed successfully in \(duration)s")
            return image
            
        } catch {
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: false, duration: duration)
            
            CaptureErrorHandler.log(error as? CaptureError ?? .unknown(error), context: "FullScreenCapture")
            throw error
        }
    }
    
    func canCapture() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }
        
        // Check if we have access to displays
        return NSScreen.main != nil
    }
    
    func getCaptureType() -> CaptureType {
        return .fullScreen
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual full screen capture
    /// - Parameter configuration: Image capture configuration
    /// - Returns: Captured image
    private func performFullScreenCapture(
        displayID: CGDirectDisplayID?,
        configuration: ImageCaptureConfiguration
    ) async throws -> NSImage {
        Logger.d("FullScreenCaptureService: Starting full screen capture")
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw CaptureError.permissionDenied
        }
        
        guard let display = CaptureDisplayResolver.scDisplay(for: displayID, in: content) else {
            throw CaptureError.noDisplays
        }
        let screen = ScreenPixelGeometry.screen(for: display.displayID) ?? NSScreen.main
        
        Logger.d("FullScreenCaptureService: Using display: \(display.displayID)")
        
        // Create content filter for full display
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )
        
        // Create stream configuration
        let config = createStreamConfiguration(for: display, screen: screen, configuration: configuration)
        
        // Create and configure stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let frameCollector = FrameCollectorFactory.createStandard()
        
        try stream.addStreamOutput(
            frameCollector,
            type: SCStreamOutputType.screen,
            sampleHandlerQueue: DispatchQueue.main
        )
        
        // Start capture with timeout
        let image: NSImage = try await withTimeout(seconds: captureTimeout) {
            try await stream.startCapture()
            
            return try await withCheckedThrowingContinuation { continuation in
                frameCollector.continuation = continuation
            }
        }
        
        // Stop capture (ignore errors during stop)
        do {
            try await stream.stopCapture()
        } catch {
            Logger.w("FullScreenCaptureService: Error stopping stream (can ignore): \(error)")
        }
        
        Logger.s("FullScreenCaptureService: Full screen capture completed")
        return image
    }
    
    /// Creates stream configuration for full screen capture
    /// - Parameters:
    ///   - display: The display to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Configured SCStreamConfiguration
    private func createStreamConfiguration(
        for display: SCDisplay,
        screen: NSScreen?,
        configuration: ImageCaptureConfiguration
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // Set resolution to the physical display pixel size, not macOS logical points.
        let captureSize = ScreenPixelGeometry.captureSize(
            for: display,
            screen: screen,
            mode: AppSettings.shared.capturePixelMode
        )
        config.width = Int(captureSize.width)
        config.height = Int(captureSize.height)
        
        // Apply configuration settings
        config.pixelFormat = configuration.pixelFormat
        config.capturesAudio = configuration.capturesAudio
        config.captureResolution = configuration.captureResolution
        config.showsCursor = configuration.showsCursor
        config.minimumFrameInterval = configuration.minimumFrameInterval
        config.scalesToFit = configuration.scalesToFit
        config.preservesAspectRatio = configuration.preservesAspectRatio
        
        Logger.d("FullScreenCaptureService: Stream config - \(config.width)x\(config.height), mode: \(AppSettings.shared.capturePixelMode.rawValue), display: \(display.width)x\(display.height), screen: \(String(describing: screen?.frame.size))")
        
        return config
    }
    
    /// Executes operation with timeout
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: Operation to execute
    /// - Returns: Result of the operation
    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CaptureError.timeout
            }
            
            guard let result = try await group.next() else {
                throw CaptureError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Public Methods
    
    /// Gets capture statistics for this service
    /// - Returns: Current capture statistics
    func getStatistics() -> CaptureStatistics {
        return statistics
    }
    
    /// Resets statistics
    func resetStatistics() {
        statistics = CaptureStatistics()
        Logger.d("FullScreenCaptureService: Statistics reset")
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    fileprivate var displayID: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            ?? 0
    }
}

#endif
