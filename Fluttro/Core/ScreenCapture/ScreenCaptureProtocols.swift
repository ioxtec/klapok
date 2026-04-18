//
//  CaptureService.swift
//  Fluttro
//
//  Core protocols for capture functionality
//

import Foundation

#if os(macOS)
import AppKit

// MARK: - Core Capture Protocol

/// Base protocol for all capture services
protocol CaptureService {
    associatedtype ResultType
    
    /// Performs capture operation with given request
    /// - Parameter request: Capture request containing all necessary parameters
    /// - Returns: Capture result of specific type
    func capture(request: CaptureRequest) async throws -> ResultType
    
    /// Checks if the service can perform capture operation
    /// - Returns: True if capture is possible, false otherwise
    func canCapture() -> Bool
    
    /// Gets the capture type this service handles
    /// - Returns: The capture type
    func getCaptureType() -> CaptureType
}

// MARK: - Image Capture Protocol

/// Protocol for image-based capture services (screenshots)
protocol ImageCaptureService: CaptureService where ResultType == NSImage {
    /// Additional method specific to image capture
    /// - Parameter request: Image capture request
    /// - Returns: Captured image
    func captureImage(request: ImageCaptureRequest) async throws -> NSImage
}

// MARK: - Video Capture Protocol

/// Protocol for video-based capture services (future implementation)
protocol VideoCaptureService: CaptureService where ResultType == VideoRecording {
    /// Additional method specific to video capture
    /// - Parameter request: Video capture request
    /// - Returns: Video recording object
    func captureVideo(request: VideoCaptureRequest) async throws -> VideoRecording
}

// MARK: - Capture Type Enum

/// Enum representing different types of capture operations
enum CaptureType: String, CaseIterable, Identifiable {
    case fullScreen
    case area
    case window

    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .fullScreen: return "rectangle.on.rectangle"
        case .area: return "viewfinder"
        case .window: return "macwindow"
        }
    }
    
    var title: String {
        switch self {
        case .fullScreen: return LocalizationKeys.captureTypeFullScreen.localized
        case .area: return LocalizationKeys.captureTypeArea.localized
        case .window: return LocalizationKeys.captureTypeWindow.localized
        }
    }
    
    /// Get the appropriate icon name based on the capture mode
    func iconName(for mode: CaptureMode) -> String {
        switch mode {
        case .image:
            // For image capture, use the standard icons
            return iconName
        case .video:
            // For video capture, use the same icons as image mode
            // The behavior will be different based on recording state
            return iconName
        }
    }
}

// MARK: - Capture Mode Enum

/// Enum representing different capture modes
enum CaptureMode: CaseIterable {
    case image
    case video
    
    var iconName: String {
        switch self {
        case .image: return "camera"
        case .video: return "video"
        }
    }
    
    var title: String {
        switch self {
        case .image: return LocalizationKeys.captureModeImage.localized
        case .video: return LocalizationKeys.captureModeVideo.localized
        }
    }
}

#endif
