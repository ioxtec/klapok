//
//  ScreenCaptureModels.swift
//  Fluttro
//
//  Models for screen capture operations including requests, results, and configurations
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreMedia

// MARK: - Video Recording State

/// States for video recording operations
enum VideoRecordingState {
    case idle
    case starting
    case recording
    
    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .starting:
            return "Starting"
        case .recording:
            return "Recording"
        }
    }

    var isActive: Bool {
        self != .idle
    }
}

// MARK: - Base Capture Request

/// Base capture request containing common parameters
struct CaptureRequest {
    let type: CaptureType
    let mode: CaptureMode
    let timestamp: Date
    
    init(type: CaptureType, mode: CaptureMode = .image) {
        self.type = type
        self.mode = mode
        self.timestamp = Date()
    }
}

// MARK: - Image Capture Request

/// Request for image capture operations
struct ImageCaptureRequest {
    let baseRequest: CaptureRequest
    let area: NSRect?
    let window: SCWindow?
    let displayID: CGDirectDisplayID?
    let configuration: ImageCaptureConfiguration
    
    init(
        type: CaptureType,
        area: NSRect? = nil,
        window: SCWindow? = nil,
        displayID: CGDirectDisplayID? = nil,
        configuration: ImageCaptureConfiguration = .default
    ) {
        self.baseRequest = CaptureRequest(type: type, mode: .image)
        self.area = area
        self.window = window
        self.displayID = displayID
        self.configuration = configuration
    }
    
    // Convenience initializers for different capture types
    static func fullScreen(
        displayID: CGDirectDisplayID? = nil,
        configuration: ImageCaptureConfiguration = .default
    ) -> ImageCaptureRequest {
        return ImageCaptureRequest(type: .fullScreen, displayID: displayID, configuration: configuration)
    }
    
    static func area(_ rect: NSRect, configuration: ImageCaptureConfiguration = .default) -> ImageCaptureRequest {
        return ImageCaptureRequest(type: .area, area: rect, configuration: configuration)
    }
    
    static func window(_ window: SCWindow, configuration: ImageCaptureConfiguration = .default) -> ImageCaptureRequest {
        return ImageCaptureRequest(type: .window, window: window, configuration: configuration)
    }
}

// MARK: - Video Capture Request (Future)

/// Request for video capture operations
struct VideoCaptureRequest {
    let baseRequest: CaptureRequest
    let area: NSRect?
    let window: SCWindow?
    let configuration: VideoCaptureConfiguration
    
    init(type: CaptureType, area: NSRect? = nil, window: SCWindow? = nil, configuration: VideoCaptureConfiguration = .default) {
        self.baseRequest = CaptureRequest(type: type, mode: .video)
        self.area = area
        self.window = window
        self.configuration = configuration
    }
}

// MARK: - Capture Configuration

/// Configuration for image capture operations
struct ImageCaptureConfiguration {
    let pixelFormat: OSType
    let captureResolution: SCCaptureResolutionType
    let showsCursor: Bool
    let capturesAudio: Bool
    let minimumFrameInterval: CMTime
    let scalesToFit: Bool
    let preservesAspectRatio: Bool
    
    static let `default` = ImageCaptureConfiguration(
        pixelFormat: kCVPixelFormatType_32BGRA,
        captureResolution: .best,
        showsCursor: false,
        capturesAudio: false,
        minimumFrameInterval: CMTime(value: 1, timescale: 60),
        scalesToFit: false,
        preservesAspectRatio: true
    )
    
    static let highQuality = ImageCaptureConfiguration(
        pixelFormat: kCVPixelFormatType_32BGRA,
        captureResolution: .best,
        showsCursor: false,
        capturesAudio: false,
        minimumFrameInterval: CMTime(value: 1, timescale: 120),
        scalesToFit: false,
        preservesAspectRatio: true
    )
}

/// Configuration for video capture operations (Future)
struct VideoCaptureConfiguration {
    let pixelFormat: OSType
    let frameRate: Double
    let bitRate: Int
    let resolution: CGSize
    let capturesAudio: Bool
    let showsCursor: Bool
    
    static let `default` = VideoCaptureConfiguration(
        pixelFormat: kCVPixelFormatType_32BGRA,
        frameRate: 30.0,
        bitRate: 5_000_000, // 5 Mbps
        resolution: CGSize(width: 1920, height: 1080),
        capturesAudio: true,
        showsCursor: false
    )
}

// MARK: - Capture Result

/// Base result container for capture operations
struct CaptureResult<T> {
    let data: T
    let metadata: CaptureMetadata
    let timestamp: Date
    
    init(data: T, metadata: CaptureMetadata) {
        self.data = data
        self.metadata = metadata
        self.timestamp = Date()
    }
}

// MARK: - Image Capture Result

/// Result of image capture operation
typealias ImageCaptureResult = CaptureResult<NSImage>

// MARK: - Video Capture Result (Future)

/// Placeholder for video recording result
struct VideoRecording {
    let url: URL
    let duration: TimeInterval
    let size: CGSize
    let frameRate: Double
    
    init(url: URL, duration: TimeInterval, size: CGSize, frameRate: Double) {
        self.url = url
        self.duration = duration
        self.size = size
        self.frameRate = frameRate
    }
}

/// Result of video capture operation
typealias VideoCaptureResult = CaptureResult<VideoRecording>

// MARK: - Capture Metadata

/// Metadata associated with capture operations
struct CaptureMetadata {
    let type: CaptureType
    let mode: CaptureMode
    let area: NSRect?
    let windowTitle: String?
    let screenSize: CGSize
    let captureDuration: TimeInterval
    let configuration: String
    
    init(type: CaptureType, mode: CaptureMode, area: NSRect? = nil, windowTitle: String? = nil, screenSize: CGSize, captureDuration: TimeInterval, configuration: String = "default") {
        self.type = type
        self.mode = mode
        self.area = area
        self.windowTitle = windowTitle
        self.screenSize = screenSize
        self.captureDuration = captureDuration
        self.configuration = configuration
    }
}

// MARK: - Capture Statistics

/// Statistics for capture operations
struct CaptureStatistics {
    let totalCaptures: Int
    let successfulCaptures: Int
    let failedCaptures: Int
    let averageCaptureTime: TimeInterval
    let lastCaptureTime: Date?
    
    var successRate: Double {
        guard totalCaptures > 0 else { return 0.0 }
        return Double(successfulCaptures) / Double(totalCaptures)
    }
    
    init() {
        self.totalCaptures = 0
        self.successfulCaptures = 0
        self.failedCaptures = 0
        self.averageCaptureTime = 0.0
        self.lastCaptureTime = nil
    }
    
    init(totalCaptures: Int, successfulCaptures: Int, failedCaptures: Int, averageCaptureTime: TimeInterval, lastCaptureTime: Date?) {
        self.totalCaptures = totalCaptures
        self.successfulCaptures = successfulCaptures
        self.failedCaptures = failedCaptures
        self.averageCaptureTime = averageCaptureTime
        self.lastCaptureTime = lastCaptureTime
    }
    
    func withNewCapture(success: Bool, duration: TimeInterval) -> CaptureStatistics {
        let newTotal = totalCaptures + 1
        let newSuccessful = successfulCaptures + (success ? 1 : 0)
        let newFailed = failedCaptures + (success ? 0 : 1)
        
        let newAverageTime: TimeInterval
        if newTotal == 1 {
            newAverageTime = duration
        } else {
            newAverageTime = (averageCaptureTime * Double(totalCaptures) + duration) / Double(newTotal)
        }
        
        return CaptureStatistics(
            totalCaptures: newTotal,
            successfulCaptures: newSuccessful,
            failedCaptures: newFailed,
            averageCaptureTime: newAverageTime,
            lastCaptureTime: Date()
        )
    }
}

#endif
