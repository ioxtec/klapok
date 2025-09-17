//
//  FrameCollector.swift
//  Fluttro
//
//  Utility class for collecting and processing frames from capture streams
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia
import CoreVideo

// MARK: - Frame Collector

/// Utility class for collecting and processing frames from ScreenCaptureKit streams
final class FrameCollector: NSObject, SCStreamOutput {
    
    // MARK: - Properties
    
    /// Continuation for async frame collection
    var continuation: CheckedContinuation<NSImage, Error>?
    
    /// High-quality CIContext for better image processing
    private let ciContext: CIContext
    
    /// Statistics tracking
    private var frameCount: Int = 0
    private var lastFrameTime: Date = Date()
    
    // MARK: - Initialization
    
    override init() {
        // Configure high-quality CIContext for better image processing
        self.ciContext = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false,
        ])
        
        super.init()
    }
    
    // MARK: - SCStreamOutput Implementation
    
    /// Called when a new frame is available from the capture stream
    /// - Parameters:
    ///   - stream: The capture stream
    ///   - sampleBuffer: The sample buffer containing the frame data
    ///   - outputType: The type of output (screen, audio, etc.)
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        Logger.d("FrameCollector: Received sample buffer, outputType: \(outputType)")
        
        // Only process screen frames
        guard outputType == SCStreamOutputType.screen else {
            Logger.d("FrameCollector: Wrong output type, ignoring")
            return
        }
        
        // Extract image buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            Logger.e("FrameCollector: Failed to get image buffer from sample")
            return
        }
        
        // Process the frame
        processFrame(pixelBuffer: pixelBuffer)
    }
    
    // MARK: - Private Methods
    
    /// Processes a pixel buffer and converts it to NSImage
    /// - Parameter pixelBuffer: The pixel buffer to process
    private func processFrame(pixelBuffer: CVPixelBuffer) {
        Logger.d("FrameCollector: Creating CIImage from buffer...")
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        
        Logger.d("FrameCollector: Creating CGImage from CIImage...")
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            Logger.e("FrameCollector: Failed to create CGImage")
            handleFrameError(CaptureError.frameConversionFailed)
            return
        }
        
        Logger.d("FrameCollector: Creating NSImage from CGImage...")
        // Keep the full physical resolution as the NSImage size for high quality
        let nsImage = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        
        // Update statistics
        updateStatistics()
        
        Logger.s("FrameCollector: NSImage created successfully, size: \(nsImage.size)")
        
        // Resume continuation on main actor for UI operations
        Task { @MainActor in
            resumeContinuation(with: nsImage)
        }
    }
    
    /// Handles frame processing errors
    /// - Parameter error: The error that occurred
    private func handleFrameError(_ error: CaptureError) {
        Task { @MainActor in
            if let continuation = self.continuation {
                Logger.d("FrameCollector: Resuming continuation with error")
                self.continuation = nil
                continuation.resume(throwing: error)
            } else {
                Logger.w("FrameCollector: WARNING - No continuation available for error!")
            }
        }
    }
    
    /// Resumes the continuation with the captured image
    /// - Parameter image: The captured image
    private func resumeContinuation(with image: NSImage) {
        if let continuation = self.continuation {
            Logger.d("FrameCollector: Resuming continuation with image")
            self.continuation = nil
            continuation.resume(returning: image)
        } else {
            Logger.w("FrameCollector: WARNING - No continuation available!")
        }
    }
    
    /// Updates frame collection statistics
    private func updateStatistics() {
        frameCount += 1
        lastFrameTime = Date()
        
        // Log statistics every 10 frames for debugging
        if frameCount % 10 == 0 {
            Logger.d("FrameCollector: Processed \(frameCount) frames, last at \(lastFrameTime)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Resets the frame collector state
    func reset() {
        frameCount = 0
        lastFrameTime = Date()
        continuation = nil
        Logger.d("FrameCollector: Reset completed")
    }
    
    /// Gets current frame collection statistics
    /// - Returns: Dictionary containing frame statistics
    func getStatistics() -> [String: Any] {
        return [
            "frameCount": frameCount,
            "lastFrameTime": lastFrameTime,
            "hasContinuation": continuation != nil
        ]
    }
}

// MARK: - Frame Collector Factory

/// Factory for creating frame collectors with different configurations
struct FrameCollectorFactory {
    
    /// Creates a standard frame collector
    /// - Returns: A new FrameCollector instance
    static func createStandard() -> FrameCollector {
        return FrameCollector()
    }
    
    /// Creates a frame collector optimized for high-quality captures
    /// - Returns: A new FrameCollector instance with high-quality settings
    static func createHighQuality() -> FrameCollector {
        // For now, return standard collector
        // In the future, we could create collectors with different CIContext configurations
        return FrameCollector()
    }
    
    /// Creates a frame collector optimized for performance
    /// - Returns: A new FrameCollector instance optimized for speed
    static func createPerformanceOptimized() -> FrameCollector {
        // For now, return standard collector
        // In the future, we could create collectors with performance-optimized settings
        return FrameCollector()
    }
}

#endif
