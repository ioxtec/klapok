//
//  WindowCaptureService.swift
//  Klapok
//
//  Service for capturing window-based screenshots
//

import Foundation

#if os(macOS)
import AppKit
@preconcurrency import ScreenCaptureKit
import CoreMedia
import CoreVideo

// MARK: - Window Capture Service

/// Service responsible for capturing window-based screenshots
final class WindowCaptureService: ImageCaptureService {
    
    // MARK: - Properties
    
    /// Statistics tracking for this service
    private var statistics = CaptureStatistics()
    
    /// Timeout for capture operations
    private let captureTimeout: TimeInterval = 5.0
    
    // MARK: - ImageCaptureService Implementation
    
    func capture(request: CaptureRequest) async throws -> NSImage {
        guard request.mode == .image else {
            throw CaptureError.invalidConfiguration
        }
        
        let imageRequest = ImageCaptureRequest(type: request.type, configuration: .default)
        return try await captureImage(request: imageRequest)
    }
    
    func captureImage(request: ImageCaptureRequest) async throws -> NSImage {
        guard let window = request.window else {
            throw CaptureError.noWindowSelected
        }
        
        let startTime = Date()
        
        do {
            let image = try await performWindowCapture(
                window: window,
                configuration: request.configuration
            )
            
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: true, duration: duration)
            
            Logger.s("WindowCaptureService: Capture completed successfully in \(duration)s")
            return image
            
        } catch {
            // Update statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: false, duration: duration)
            
            CaptureErrorHandler.log(error as? CaptureError ?? .unknown(error), context: "WindowCapture")
            throw error
        }
    }
    
    func canCapture() -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }
        
        return true
    }
    
    func getCaptureType() -> CaptureType {
        return .window
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual window capture
    /// - Parameters:
    ///   - window: The window to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Captured image
    private func performWindowCapture(
        window: SCWindow,
        configuration: ImageCaptureConfiguration
    ) async throws -> NSImage {
        Logger.d("WindowCaptureService: Capturing window: \(window.title ?? "Unknown")")
        
        // Check if window is capturable
        guard window.owningApplication != nil else {
            throw CaptureError.noWindowSelected
        }
        
        // Validate window dimensions
        guard window.frame.width > 50 && window.frame.height > 50 else {
            throw CaptureError.invalidConfiguration
        }
        
        // Create content filter for window-only capture
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        // Create stream configuration
        let config = createStreamConfiguration(
            for: window,
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
            Logger.w("WindowCaptureService: Error stopping stream (can ignore): \(error)")
        }
        
        Logger.s("WindowCaptureService: Window capture completed")
        return image
    }
    
    /// Creates stream configuration for window capture
    /// - Parameters:
    ///   - window: The window to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Configured SCStreamConfiguration
    private func createStreamConfiguration(
        for window: SCWindow,
        configuration: ImageCaptureConfiguration
    ) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        
        // Set resolution to the window's physical pixel size, not its logical point size.
        let captureSize = ScreenPixelGeometry.captureSize(
            for: window,
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
        
        Logger.d("WindowCaptureService: Stream config - \(config.width)x\(config.height)")
        
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
        Logger.d("WindowCaptureService: Statistics reset")
    }
    
    /// Gets available windows for capture
    /// - Returns: Array of capturable windows
    func getAvailableWindows() async throws -> [SCWindow] {
        Logger.d("WindowCaptureService: Getting available windows")
        
        let content = try await SCShareableContent.current
        let windows = content.windows.filter { window in
            // Filter criteria for capturable windows
            guard let owningApp = window.owningApplication else { return false }
            guard window.frame.width > 50 && window.frame.height > 50 else { return false }
            guard !(window.title?.isEmpty ?? true) else { return false }
            
            // Exclude system windows and our own app
            let bundleIdentifier = owningApp.bundleIdentifier
            if bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            
            return true
        }
        
        Logger.d("WindowCaptureService: Found \(windows.count) capturable windows")
        return windows
    }
    
    /// Validates if a window is capturable
    /// - Parameter window: The window to validate
    /// - Returns: True if the window is capturable
    func validateWindow(_ window: SCWindow) -> Bool {
        guard window.owningApplication != nil else { return false }
        guard window.frame.width > 50 && window.frame.height > 50 else { return false }
        guard !(window.title?.isEmpty ?? true) else { return false }
        
        // Check if it's not our own app
        if let bundleId = window.owningApplication?.bundleIdentifier,
           bundleId == Bundle.main.bundleIdentifier {
            return false
        }
        
        return true
    }
    
    /// Shows window selection dialog and returns selected window
    /// - Returns: Selected window or nil if cancelled
    func showWindowSelection() async throws -> SCWindow? {
        let windows = try await getAvailableWindows()
        
        guard !windows.isEmpty else {
            throw CaptureError.noWindows
        }
        
        return try await showWindowSelectionDialog(windows: windows)
    }
    
    /// Shows window selection dialog
    /// - Parameter windows: Available windows to choose from
    /// - Returns: Selected window or nil if cancelled
    private func showWindowSelectionDialog(windows: [SCWindow]) async throws -> SCWindow? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let dialog = WindowSelectionDialog(windows: windows) { @Sendable window in
                    continuation.resume(returning: window)
                }
                dialog.show()
            }
        }
    }
}

#endif
