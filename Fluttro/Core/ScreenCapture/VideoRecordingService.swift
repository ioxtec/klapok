//
//  VideoRecordingService.swift
//  Fluttro
//
//  Video recording service for screen capture
//

import Foundation

#if os(macOS)
import AppKit
import ScreenCaptureKit
import CoreMedia
import AVFoundation

/// Video recording service for full screen capture
class VideoRecordingService: VideoCaptureService {
    
    // MARK: - Properties
    
    private var stream: SCStream?
    private var streamOutput: VideoStreamOutput?
    private var recordingOutput: VideoRecordingOutput?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // MARK: - VideoCaptureService Implementation
    
    func capture(request: CaptureRequest) async throws -> VideoRecording {
        guard request.mode == .video else {
            throw CaptureError.invalidRequest("Expected video capture request")
        }
        
        switch request.type {
        case .fullScreen:
            return try await captureFullScreenVideo(request: request)
        case .area:
            throw CaptureError.notImplemented("Area video capture not yet implemented")
        case .window:
            throw CaptureError.notImplemented("Window video capture not yet implemented")
        }
    }
    
    func canCapture() -> Bool {
        // Check if screen recording permission is granted
        return CGPreflightScreenCaptureAccess()
    }
    
    func getCaptureType() -> CaptureType {
        return .fullScreen
    }
    
    // MARK: - Video Capture Implementation
    
    func captureVideo(request: VideoCaptureRequest) async throws -> VideoRecording {
        return try await capture(request: CaptureRequest(type: .fullScreen, mode: .video))
    }
    
    private func captureFullScreenVideo(request: CaptureRequest) async throws -> VideoRecording {
        // For now, return a placeholder VideoRecording
        // In a real implementation, this would start actual screen recording
        
        let recording = VideoRecording(
            url: URL(fileURLWithPath: "/tmp/placeholder.mov"),
            duration: 0.0,
            size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080),
            frameRate: 30.0
        )
        
        return recording
    }
    
    // MARK: - Recording Control Methods
    
    func startRecording(excludingWindows: [NSWindow] = []) async throws {
        guard !isRecording else {
            print("❌ Already recording, cannot start again")
            throw CaptureError.alreadyRecording
        }
        
        // Create temporary file URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        let settings = AppSettings.shared
        let fileExtension = settings.videoFormat.lowercased()
        recordingURL = tempDir.appendingPathComponent("fluttro_recording_\(Date().timeIntervalSince1970).\(fileExtension)")
        
        // Setup screen capture stream
        try await setupScreenCapture(excludingWindows: excludingWindows)
        
        isRecording = true
        recordingStartTime = Date()
        
        print("🎥 Started video recording at \(recordingStartTime!)")
        print("🎥 Recording to: \(recordingURL?.path ?? "unknown")")
    }
    
    func pauseRecording() async throws {
        guard isRecording else {
            print("❌ Not recording, cannot pause")
            throw CaptureError.notRecording
        }
        
        print("⏸️ Paused video recording")
        // TODO: Implement actual screen recording pause
    }
    
    func resumeRecording() async throws {
        guard isRecording else {
            print("❌ Not recording, cannot resume")
            throw CaptureError.notRecording
        }
        
        print("▶️ Resumed video recording")
        // TODO: Implement actual screen recording resume
    }
    
    func stopRecording() async throws -> VideoRecording {
        guard isRecording else {
            print("❌ Not recording, cannot stop")
            throw CaptureError.notRecording
        }
        
        isRecording = false
        let endTime = Date()
        let duration = endTime.timeIntervalSince(recordingStartTime ?? endTime)
        
        // Stop the stream
        try? await stream?.stopCapture()
        stream = nil
        
        // Clean up outputs - manually finish writing
        if let streamOutput = streamOutput {
            await streamOutput.finishWriting()
        }
        streamOutput = nil
        
        guard let recordingURL = recordingURL else {
            throw CaptureError.invalidRequest("No recording URL found")
        }
        
        let recording = VideoRecording(
            url: recordingURL,
            duration: duration,
            size: NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080),
            frameRate: 30.0
        )
        
        // Check if file was created successfully
        let fileExists = FileManager.default.fileExists(atPath: recordingURL.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: recordingURL.path)[.size] as? Int64) ?? 0
        
        print("⏹️ Stopped video recording: \(recording.duration)s")
        print("⏹️ Video saved to: \(recordingURL.path)")
        print("⏹️ File exists: \(fileExists), Size: \(fileSize) bytes")
        
        if !fileExists || fileSize == 0 {
            throw CaptureError.invalidRequest("Video file was not created or is empty")
        }
        
        self.recordingURL = nil
        return recording
    }
    
    var currentRecordingDuration: TimeInterval {
        guard let startTime = recordingStartTime, isRecording else { return 0.0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Private Methods
    
    private func setupScreenCapture(excludingWindows: [NSWindow] = []) async throws {
        guard let recordingURL = recordingURL else {
            throw CaptureError.invalidRequest("No recording URL set")
        }
        
        // Get screen content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.unavailable
        }
        
        // Convert NSWindow objects to SCWindow objects for exclusion
        let windowsToExclude = await MainActor.run {
            content.windows.filter { scWindow in
                excludingWindows.contains { nsWindow in
                    // Try to match windows by comparing their properties
                    // This is a heuristic approach since we can't directly compare NSWindow to SCWindow
                    return nsWindow.windowNumber == scWindow.windowID ||
                           (nsWindow.title == scWindow.title && nsWindow.title.count > 0)
                }
            }
        }
        
        print("🎥 Excluding \(windowsToExclude.count) windows from recording")
        for window in windowsToExclude {
            print("🎥   - Excluding window: \(window.title ?? "Unknown") (ID: \(window.windowID))")
        }
        
        // Create stream configuration
        let streamConfig = SCStreamConfiguration()
        
        // Get settings from AppSettings
        let settings = AppSettings.shared
        
        // Set resolution
        if settings.videoResolution == "Source" {
            streamConfig.width = Int(display.width)
            streamConfig.height = Int(display.height)
        } else {
            // Parse resolution (e.g., "1080p" -> 1920x1080)
            let (width, height) = parseResolution(settings.videoResolution)
            streamConfig.width = width
            streamConfig.height = height
        }
        
        // Set frame rate
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: Int32(settings.videoFrameRate))
        streamConfig.queueDepth = 5
        streamConfig.showsCursor = settings.showMouseCursor
        streamConfig.capturesAudio = settings.recordSystemAudio || settings.recordMicrophone
        
        // Create filter for main display, excluding specified windows
        let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)
        
        // Use proven AVAssetWriter approach (SCRecordingOutput has issues)
        print("🎥 Using proven VideoStreamOutput approach with improved settings")
        streamOutput = VideoStreamOutput(recordingURL: recordingURL)
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
        try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: DispatchQueue.global())
        
        // Start capture
        try await stream?.startCapture()
        
        print("🎥 Screen capture setup complete")
    }
    
    private func parseResolution(_ resolution: String) -> (Int, Int) {
        switch resolution {
        case "1080p":
            return (1920, 1080)
        case "720p":
            return (1280, 720)
        case "480p":
            return (854, 480)
        default:
            return (1920, 1080) // Default to 1080p
        }
    }
}

// MARK: - Video Recording Output (New ScreenCaptureKit approach)

@available(macOS 15.0, *)
class VideoRecordingOutput: NSObject, SCRecordingOutputDelegate {
    
    private let recordingURL: URL
    private var recordingOutput: SCRecordingOutput?
    
    init(recordingURL: URL) {
        self.recordingURL = recordingURL
        super.init()
        setupRecordingOutput()
    }
    
    private func setupRecordingOutput() {
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try FileManager.default.removeItem(at: recordingURL)
            }
            
            // Get settings from AppSettings
            let settings = AppSettings.shared
            
            print("🎥 Creating SCRecordingOutput with URL: \(recordingURL.path)")
            print("🎥 Video settings:")
            print("🎥   Resolution: \(settings.videoResolution)")
            print("🎥   Frame rate: \(settings.videoFrameRate)")
            print("🎥   Bitrate: \(settings.videoBitrate)")
            print("🎥   Format: \(settings.videoFormat)")
            print("🎥   Show cursor: \(settings.showMouseCursor)")
            print("🎥   Record audio: \(settings.recordSystemAudio)")
            print("🎥   Record microphone: \(settings.recordMicrophone)")
            
            // Create recording output configuration
            let config = SCRecordingOutputConfiguration()
            
            // Set output URL
            config.outputURL = recordingURL
            
            // Create recording output with delegate
            recordingOutput = SCRecordingOutput(configuration: config, delegate: self)
            
            print("🎥 SCRecordingOutput created successfully")
            
        } catch {
            print("❌ Failed to setup SCRecordingOutput: \(error)")
        }
    }
    
    func getRecordingOutput() -> SCRecordingOutput? {
        return recordingOutput
    }
    
    private func parseResolution(_ resolution: String) -> (Int, Int) {
        switch resolution {
        case "1080p":
            return (1920, 1080)
        case "720p":
            return (1280, 720)
        case "480p":
            return (854, 480)
        default:
            return (1920, 1080) // Default to 1080p
        }
    }
    
    // MARK: - SCRecordingOutputDelegate
    
    func recordingOutput(_ output: SCRecordingOutput, didComplete recordingURL: URL, error: Error?) {
        if let error = error {
            print("❌ Recording failed: \(error.localizedDescription)")
        } else {
            print("🎥 Recording completed successfully: \(recordingURL.path)")
        }
    }
}

// MARK: - Legacy Video Stream Output (for older macOS versions)

class VideoStreamOutput: NSObject, SCStreamOutput {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let recordingURL: URL
    private var sessionStarted: Bool = false
    
    init(recordingURL: URL) {
        self.recordingURL = recordingURL
        super.init()
        setupAssetWriter()
    }
    
    private func setupAssetWriter() {
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: recordingURL.path) {
                try FileManager.default.removeItem(at: recordingURL)
            }
            
            // Get settings from AppSettings
            let settings = AppSettings.shared
            
            // Determine file type based on settings
            let fileType: AVFileType
            switch settings.videoFormat {
            case "MP4":
                fileType = .mp4
            case "MOV":
                fileType = .mov
            default:
                fileType = .mov
            }
            
            // Create asset writer
            print("🎥 Creating legacy AVAssetWriter with URL: \(recordingURL.path)")
            print("🎥 File type: \(fileType.rawValue)")
            assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: fileType)
            
            // Get screen size
            let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
            
            // Determine codec based on settings
            let codec: AVVideoCodecType
            switch settings.videoCodec {
            case "H.264":
                codec = .h264
            case "H.265":
                codec = .hevc
            default:
                codec = .h264
            }
            
            // Video settings with maximum compatibility
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: Int(screenSize.width),
                AVVideoHeightKey: Int(screenSize.height),
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: settings.videoBitrate,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel, // Use Baseline for maximum compatibility
                    AVVideoMaxKeyFrameIntervalKey: settings.videoFrameRate * 2,
                    AVVideoExpectedSourceFrameRateKey: settings.videoFrameRate,
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCAVLC,
                    AVVideoPixelAspectRatioKey: [AVVideoPixelAspectRatioHorizontalSpacingKey: 1, AVVideoPixelAspectRatioVerticalSpacingKey: 1]
                ]
            ]
            
            // Create video input
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            print("🎥 Video input created with settings:")
            print("🎥   Codec: \(codec.rawValue)")
            print("🎥   Width: \(Int(screenSize.width))")
            print("🎥   Height: \(Int(screenSize.height))")
            print("🎥   Bitrate: \(settings.videoBitrate)")
            print("🎥   Profile: Baseline (max compatibility)")
            
            // Create pixel buffer adaptor
            let pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(screenSize.width),
                kCVPixelBufferHeightKey as String: Int(screenSize.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: pixelBufferAttributes
            )
            
            // Add input to writer
            if assetWriter?.canAdd(videoInput!) == true {
                assetWriter?.add(videoInput!)
            }
            
            // Start writing
            if assetWriter?.startWriting() == true {
                // Don't start session yet - wait for first frame
                print("🎥 Legacy asset writer started successfully")
                print("🎥 Session will start with first frame")
            } else {
                print("❌ Failed to start legacy asset writer: \(assetWriter?.error?.localizedDescription ?? "Unknown error")")
            }
            
        } catch {
            print("❌ Failed to setup legacy asset writer: \(error)")
        }
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        // Start session with first frame if not started yet
        if let assetWriter = assetWriter, assetWriter.status == .writing {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !sessionStarted {
                assetWriter.startSession(atSourceTime: presentationTime)
                sessionStarted = true
                print("🎥 Video session started with first frame at time: \(presentationTime)")
            }
        }
        
        // Append sample buffer directly
        videoInput.append(sampleBuffer)
    }
    
    func finishWriting() async {
        guard let videoInput = videoInput else { 
            print("❌ No video input to finish")
            return 
        }
        
        print("🎥 Finishing video writing...")
        print("🎥 Session started: \(sessionStarted)")
        
        videoInput.markAsFinished()
        
        if let assetWriter = assetWriter {
            await assetWriter.finishWriting()
            if assetWriter.status == .completed {
                print("🎥 Legacy video writing finished successfully")
                print("🎥 Asset writer status: \(assetWriter.status.rawValue)")
            } else {
                print("❌ Legacy video writing failed: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
                print("🎥 Asset writer status: \(assetWriter.status.rawValue)")
            }
        } else {
            print("❌ No legacy asset writer to finish")
        }
    }
}

#endif
