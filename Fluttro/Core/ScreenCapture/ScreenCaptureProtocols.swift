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
enum CaptureType: CaseIterable {
    case fullScreen
    case area
    case window
    
    var iconName: String {
        switch self {
        case .fullScreen: return "rectangle.on.rectangle"
        case .area: return "viewfinder"
        case .window: return "macwindow"
        }
    }
    
    var title: String {
        switch self {
        case .fullScreen: return "Cały ekran"
        case .area: return "Wycinek"
        case .window: return "Okno"
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
        case .image: return "Obraz"
        case .video: return "Video"
        }
    }
}

#endif
