//
//  CaptureError.swift
//  Fluttro
//
//  Error types for capture operations
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit

// MARK: - Capture Error Types

/// Base error type for all capture operations
enum CaptureError: Error, LocalizedError {
    case unavailable
    case noDisplays
    case noWindows
    case noWindowSelected
    case userCancelled
    case permissionDenied
    case timeout
    case invalidConfiguration
    case frameConversionFailed
    case streamCreationFailed
    case streamStartFailed
    case streamStopFailed
    case notImplemented(String)
    case alreadyRecording
    case notRecording
    case invalidRequest(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Capture service is not available on this system"
        case .noDisplays:
            return "No displays available for capture"
        case .noWindows:
            return "No windows available for capture"
        case .noWindowSelected:
            return "No window has been selected for capture"
        case .userCancelled:
            return "User cancelled the capture operation"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .timeout:
            return "Capture operation timed out"
        case .invalidConfiguration:
            return "Invalid capture configuration provided"
        case .frameConversionFailed:
            return "Failed to convert captured frame to image"
        case .streamCreationFailed:
            return "Failed to create capture stream"
        case .streamStartFailed:
            return "Failed to start capture stream"
        case .streamStopFailed:
            return "Failed to stop capture stream"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .alreadyRecording:
            return "Video recording is already in progress"
        case .notRecording:
            return "No video recording is currently active"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .unknown(let error):
            return "Unknown error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unavailable:
            return "Make sure you're running macOS 13.0 or later"
        case .noDisplays:
            return "Check your display configuration"
        case .noWindows:
            return "Make sure there are windows available to capture"
        case .noWindowSelected:
            return "Select a window before attempting to capture"
        case .userCancelled:
            return "Try the capture operation again"
        case .permissionDenied:
            return "Grant screen recording permission in System Preferences > Security & Privacy"
        case .timeout:
            return "Try again with a shorter timeout or check system performance"
        case .invalidConfiguration:
            return "Check your capture configuration settings"
        case .frameConversionFailed:
            return "Try again or check system memory availability"
        case .streamCreationFailed:
            return "Check system resources and try again"
        case .streamStartFailed:
            return "Check permissions and system resources"
        case .streamStopFailed:
            return "This error can usually be ignored"
        case .notImplemented:
            return "This feature will be available in a future update"
        case .alreadyRecording:
            return "Stop the current recording before starting a new one"
        case .notRecording:
            return "Start a recording first"
        case .invalidRequest:
            return "Check your request parameters"
        case .unknown:
            return "Check the console for more details"
        }
    }
}

// MARK: - Capture Error Categories

/// Categories for organizing capture errors
enum CaptureErrorCategory {
    case system
    case permission
    case configuration
    case network
    case user
    case unknown
    
    init(from error: CaptureError) {
        switch error {
        case .unavailable, .noDisplays, .noWindows, .streamCreationFailed, .streamStartFailed, .streamStopFailed:
            self = .system
        case .permissionDenied:
            self = .permission
        case .invalidConfiguration, .invalidRequest:
            self = .configuration
        case .timeout:
            self = .network
        case .userCancelled, .noWindowSelected, .alreadyRecording, .notRecording:
            self = .user
        case .frameConversionFailed, .unknown, .notImplemented:
            self = .unknown
        }
    }
}

// MARK: - Error Handling Utilities

/// Utility class for handling capture errors
struct CaptureErrorHandler {
    
    /// Logs capture error with appropriate level
    /// - Parameters:
    ///   - error: The capture error to log
    ///   - context: Additional context information
    static func log(_ error: CaptureError, context: String = "") {
        let category = CaptureErrorCategory(from: error)
        let logMessage = "Capture Error\(context.isEmpty ? "" : " in \(context)"): \(error.localizedDescription)"
        
        switch category {
        case .system, .permission, .configuration:
            Logger.e(logMessage)
        case .user:
            Logger.d(logMessage) // User actions are typically debug level
        case .network, .unknown:
            Logger.w(logMessage)
        }
    }
    
    /// Determines if an error is recoverable
    /// - Parameter error: The capture error to check
    /// - Returns: True if the error is recoverable, false otherwise
    static func isRecoverable(_ error: CaptureError) -> Bool {
        switch error {
        case .unavailable, .permissionDenied:
            return false
        case .noDisplays, .noWindows, .noWindowSelected, .userCancelled, .timeout, .invalidConfiguration, .frameConversionFailed, .streamCreationFailed, .streamStartFailed, .streamStopFailed, .notImplemented, .alreadyRecording, .notRecording, .invalidRequest, .unknown:
            return true
        }
    }
    
    /// Gets user-friendly error message for display
    /// - Parameter error: The capture error
    /// - Returns: User-friendly error message
    static func userFriendlyMessage(for error: CaptureError) -> String {
        switch error {
        case .permissionDenied:
            return "Screen recording permission is required. Please enable it in System Preferences."
        case .noWindowSelected:
            return "Please select a window to capture."
        case .userCancelled:
            return "Capture was cancelled."
        case .timeout:
            return "Capture timed out. Please try again."
        default:
            return "Capture failed. Please try again."
        }
    }
}

#endif
