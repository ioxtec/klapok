//
//  CaptureManager.swift
//  Fluttro
//
//  Main coordinator for all capture operations
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit

// MARK: - Capture Manager

/// Main coordinator for all capture operations
@MainActor
final class CaptureManager: ObservableObject {
    
    // MARK: - Properties
    
    /// Specialized capture services
    private let fullScreenService: FullScreenCaptureService
    private let areaService: AreaCaptureService
    private let windowService: WindowCaptureService
    
    /// Overall capture statistics
    @Published private(set) var statistics = CaptureStatistics()
    
    /// Current capture mode
    @Published var captureMode: CaptureMode = .image
    
    // MARK: - Initialization
    
    /// Initializes the capture manager with all services
    init() {
        self.fullScreenService = FullScreenCaptureService()
        self.areaService = AreaCaptureService()
        self.windowService = WindowCaptureService()
        
        Logger.s("CaptureManager: Initialized with all capture services")
    }
    
    // MARK: - Public Methods
    
    /// Captures an image based on the provided request
    /// - Parameter request: Image capture request
    /// - Returns: Captured image
    func captureImage(request: ImageCaptureRequest) async throws -> NSImage {
        let startTime = Date()
        
        do {
            let image: NSImage
            
            switch request.baseRequest.type {
            case .fullScreen:
                image = try await fullScreenService.captureImage(request: request)
            case .area:
                guard request.area != nil else {
                    throw CaptureError.invalidConfiguration
                }
                image = try await areaService.captureImage(request: request)
            case .window:
                guard request.window != nil else {
                    throw CaptureError.noWindowSelected
                }
                image = try await windowService.captureImage(request: request)
            }
            
            // Update overall statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: true, duration: duration)
            
            Logger.s("CaptureManager: Image capture completed successfully in \(duration)s")
            return image
            
        } catch {
            // Update overall statistics
            let duration = Date().timeIntervalSince(startTime)
            statistics = statistics.withNewCapture(success: false, duration: duration)
            
            CaptureErrorHandler.log(error as? CaptureError ?? .unknown(error), context: "CaptureManager")
            throw error
        }
    }
    
    /// Captures full screen image
    /// - Parameter configuration: Image capture configuration
    /// - Returns: Captured full screen image
    func captureFullScreen(configuration: ImageCaptureConfiguration = .default) async throws -> NSImage {
        let request = ImageCaptureRequest.fullScreen(configuration: configuration)
        return try await captureImage(request: request)
    }
    
    /// Captures area image
    /// - Parameters:
    ///   - area: The area to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Captured area image
    func captureArea(_ area: NSRect, configuration: ImageCaptureConfiguration = .default) async throws -> NSImage {
        guard areaService.validateArea(area) else {
            throw CaptureError.invalidConfiguration
        }
        
        let request = ImageCaptureRequest.area(area, configuration: configuration)
        return try await captureImage(request: request)
    }
    
    /// Captures window image
    /// - Parameters:
    ///   - window: The window to capture
    ///   - configuration: Image capture configuration
    /// - Returns: Captured window image
    func captureWindow(_ window: SCWindow, configuration: ImageCaptureConfiguration = .default) async throws -> NSImage {
        guard windowService.validateWindow(window) else {
            throw CaptureError.invalidConfiguration
        }
        
        let request = ImageCaptureRequest.window(window, configuration: configuration)
        return try await captureImage(request: request)
    }
    
    /// Captures selected window (shows selection dialog)
    /// - Parameter configuration: Image capture configuration
    /// - Returns: Captured window image
    func captureSelectedWindow(configuration: ImageCaptureConfiguration = .default) async throws -> NSImage {
        guard let selectedWindow = try await windowService.showWindowSelection() else {
            throw CaptureError.userCancelled
        }
        
        let request = ImageCaptureRequest.window(selectedWindow, configuration: configuration)
        return try await captureImage(request: request)
    }
    
    /// Gets available windows for capture
    /// - Returns: Array of capturable windows
    func getAvailableWindows() async throws -> [SCWindow] {
        return try await windowService.getAvailableWindows()
    }
    
    /// Checks if a specific capture type is available
    /// - Parameter type: Capture type to check
    /// - Returns: True if the capture type is available
    func canCapture(type: CaptureType) -> Bool {
        switch type {
        case .fullScreen:
            return fullScreenService.canCapture()
        case .area:
            return areaService.canCapture()
        case .window:
            return windowService.canCapture()
        }
    }
    
    /// Gets statistics for a specific capture service
    /// - Parameter type: Capture type
    /// - Returns: Statistics for the specified service
    func getStatistics(for type: CaptureType) -> CaptureStatistics {
        switch type {
        case .fullScreen:
            return fullScreenService.getStatistics()
        case .area:
            return areaService.getStatistics()
        case .window:
            return windowService.getStatistics()
        }
    }
    
    /// Gets overall capture statistics
    /// - Returns: Combined statistics from all services
    func getOverallStatistics() -> CaptureStatistics {
        return statistics
    }
    
    /// Resets all statistics
    func resetStatistics() {
        statistics = CaptureStatistics()
        fullScreenService.resetStatistics()
        areaService.resetStatistics()
        windowService.resetStatistics()
        
        Logger.d("CaptureManager: All statistics reset")
    }
    
    /// Validates an area for capture
    /// - Parameter area: Area to validate
    /// - Returns: True if the area is valid
    func validateArea(_ area: NSRect) -> Bool {
        return areaService.validateArea(area)
    }
    
    /// Validates a window for capture
    /// - Parameter window: Window to validate
    /// - Returns: True if the window is valid
    func validateWindow(_ window: SCWindow) -> Bool {
        return windowService.validateWindow(window)
    }
    
    // MARK: - Service Access (For Advanced Use Cases)
    
    /// Gets the full screen capture service
    /// - Returns: Full screen capture service
    func getFullScreenService() -> FullScreenCaptureService {
        return fullScreenService
    }
    
    /// Gets the area capture service
    /// - Returns: Area capture service
    func getAreaService() -> AreaCaptureService {
        return areaService
    }
    
    /// Gets the window capture service
    /// - Returns: Window capture service
    func getWindowService() -> WindowCaptureService {
        return windowService
    }
}

// MARK: - Capture Manager Singleton

extension CaptureManager {
    
    /// Shared instance of CaptureManager
    static let shared = CaptureManager()
}

#endif
