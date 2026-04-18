//
//  AreaCaptureService.swift
//  Fluttro
//
//  Service for capturing area-based screenshots
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo

// MARK: - Area Capture Service

/// Service responsible for capturing area-based screenshots
final class AreaCaptureService: ImageCaptureService {
    
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
        guard let area = request.area else {
            throw CaptureError.invalidConfiguration
        }
        
        let startTime = Date()
        
        do {
            let image = try await performAreaCapture(
                area: area,
                configuration: request.configuration
            )
            
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: true, duration: duration)
            
            Logger.s("AreaCaptureService: Capture completed successfully in \(duration)s")
            return image
            
        } catch {
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: false, duration: duration)
            
            CaptureErrorHandler.log(error as? CaptureError ?? .unknown(error), context: "AreaCapture")
            throw error
        }
    }
    
    func canCapture() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }
        
        // Check if we have access to displays and valid area
        return NSScreen.main != nil
    }
    
    func getCaptureType() -> CaptureType {
        return .area
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual area capture
    /// - Parameters:
    ///   - area: The area to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Captured image
    private func performAreaCapture(
        area: NSRect,
        configuration: ImageCaptureConfiguration
    ) async throws -> NSImage {
        Logger.d("AreaCaptureService: Starting area capture with rect: \(area)")
        
        // Get shareable content
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw CaptureError.permissionDenied
        }
        
        guard let screen = ScreenPixelGeometry.screen(containing: area) else {
            throw CaptureError.noDisplays
        }
        guard let display = CaptureDisplayResolver.scDisplay(for: ScreenPixelGeometry.displayID(for: screen), in: content) else {
            throw CaptureError.noDisplays
        }

        Logger.d("AreaCaptureService: Using display: \(display.displayID)")
        
        // Convert screen coordinates to display coordinates
        let displayRect = convertScreenRectToDisplayRect(area, screen: screen)
        Logger.d("AreaCaptureService: Converted displayRect: \(displayRect)")
        
        // Create content filter for full display
        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )
        
        // Create stream configuration
        let config = createStreamConfiguration(
            for: area,
            display: display,
            screen: screen,
            configuration: configuration
        )
        
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
            Logger.w("AreaCaptureService: Error stopping stream (can ignore): \(error)")
        }
        
        Logger.s("AreaCaptureService: Area capture completed")
        return image
    }
    
    /// Converts screen coordinates to display coordinates
    /// - Parameters:
    ///   - screenRect: Rectangle in screen coordinates
    ///   - screen: The screen reference
    /// - Returns: Rectangle in display coordinates
    private func convertScreenRectToDisplayRect(_ screenRect: NSRect, screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        return NSRect(
            x: screenRect.minX - screenFrame.minX,
            y: screenFrame.maxY - screenRect.maxY,
            width: screenRect.width,
            height: screenRect.height
        )
    }
    
    /// Creates stream configuration for area capture
    /// - Parameters:
    ///   - area: The area to capture
    ///   - display: The display to capture from
    ///   - screen: The screen reference
    ///   - configuration: Image capture configuration
    /// - Returns: Configured SCStreamConfiguration
    private func createStreamConfiguration(
        for area: NSRect,
        display: SCDisplay,
        screen: NSScreen,
        configuration: ImageCaptureConfiguration
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // Convert screen coordinates to display coordinates
        let displayRect = convertScreenRectToDisplayRect(area, screen: screen)
        
        // Use physical pixels for the output image while keeping sourceRect in display points.
        let captureSize = ScreenPixelGeometry.captureSize(
            for: area,
            on: screen,
            mode: AppSettings.shared.capturePixelMode
        )
        config.width = Int(captureSize.width)
        config.height = Int(captureSize.height)
        
        // Set source rectangle in logical coordinates
        config.sourceRect = CGRect(
            x: displayRect.minX,
            y: displayRect.minY,
            width: displayRect.width,
            height: displayRect.height
        )
        
        // Apply configuration settings
        config.pixelFormat = configuration.pixelFormat
        config.capturesAudio = configuration.capturesAudio
        config.captureResolution = configuration.captureResolution
        config.showsCursor = configuration.showsCursor
        config.minimumFrameInterval = configuration.minimumFrameInterval
        config.scalesToFit = configuration.scalesToFit
        config.preservesAspectRatio = configuration.preservesAspectRatio
        
        Logger.d("AreaCaptureService: Stream config - \(config.width)x\(config.height)")
        Logger.d("AreaCaptureService: Source rect - \(config.sourceRect)")
        
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
        Logger.d("AreaCaptureService: Statistics reset")
    }
    
    /// Validates if an area is capturable
    /// - Parameter area: The area to validate
    /// - Returns: True if the area is valid for capture
    func validateArea(_ area: NSRect) -> Bool {
        guard area.width > 10 && area.height > 10 else {
            return false
        }

        return ScreenPixelGeometry.screen(containing: area) != nil
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
