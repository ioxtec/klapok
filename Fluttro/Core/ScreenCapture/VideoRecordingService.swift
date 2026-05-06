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

/// Video recording service for full screen capture
class VideoRecordingService: VideoCaptureService {
    
    // MARK: - Properties
    
    private var stream: SCStream?
    private var streamOutput: VideoStreamOutput?
    private var isRecording = false
    private var recordingStartTime: Date?
    private var recordingURL: URL?
    private var currentRecordingSize: CGSize?
    private let firstFrameTimeout: TimeInterval = 8.0
    
    // MARK: - VideoCaptureService Implementation
    
    func capture(request: CaptureRequest) async throws -> VideoRecording {
        guard request.mode == .video else {
            throw CaptureError.invalidRequest("Expected video capture request")
        }

        throw CaptureError.notImplemented("Video recording is controlled with startRecording and stopRecording")
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
        return try await capture(request: request.baseRequest)
    }
    
    // MARK: - Recording Control Methods
    
    func startRecording(
        displayID: CGDirectDisplayID? = nil,
        excludingWindows: [NSWindow] = []
    ) async throws {
        try prepareRecording()
        let firstFrameDate = try await setupScreenCapture(displayID: displayID, excludingWindows: excludingWindows)
        markRecordingStarted(at: firstFrameDate)
    }
    
    func startRecordingWindow(_ window: SCWindow, excludingWindows: [NSWindow] = []) async throws {
        try prepareRecording()
        let firstFrameDate = try await setupWindowCapture(window: window, excludingWindows: excludingWindows)
        markRecordingStarted(at: firstFrameDate)
    }
    
    func startRecordingArea(_ areaRect: NSRect, excludingWindows: [NSWindow] = []) async throws {
        try prepareRecording()
        let firstFrameDate = try await setupAreaCapture(areaRect: areaRect, excludingWindows: excludingWindows)
        markRecordingStarted(at: firstFrameDate)
    }
    
    func stopRecording() async throws -> VideoRecording {
        guard isRecording else {
            Logger.e("VideoRecordingService: Not recording, cannot stop")
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
            size: currentRecordingSize ?? ScreenPixelGeometry.captureSize(
                for: NSScreen.main,
                mode: AppSettings.shared.capturePixelMode
            ),
            frameRate: 30.0
        )
        
        // Check if file was created successfully
        let fileExists = FileManager.default.fileExists(atPath: recordingURL.path)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: recordingURL.path)[.size] as? Int64) ?? 0
        
        Logger.s("VideoRecordingService: Stopped recording after \(recording.duration)s")
        Logger.d("VideoRecordingService: Video saved to \(recordingURL.path), size \(fileSize) bytes")
        
        if !fileExists || fileSize == 0 {
            throw CaptureError.invalidRequest("Video file was not created or is empty")
        }
        
        self.recordingURL = nil
        self.currentRecordingSize = nil
        return recording
    }

    func cancelRecording() async {
        let hasPendingRecordingResources = stream != nil || streamOutput != nil || recordingURL != nil
        guard isRecording || hasPendingRecordingResources else {
            Logger.w("VideoRecordingService: Not recording, cannot cancel")
            return
        }

        isRecording = false
        let urlToRemove = recordingURL

        try? await stream?.stopCapture()
        stream = nil

        if let streamOutput = streamOutput {
            await streamOutput.finishWriting()
        }
        streamOutput = nil
        recordingStartTime = nil
        recordingURL = nil
        currentRecordingSize = nil

        if let urlToRemove {
            try? FileManager.default.removeItem(at: urlToRemove)
            Logger.d("VideoRecordingService: Cancelled recording and removed \(urlToRemove.path)")
        }
    }
    
    var currentRecordingDuration: TimeInterval {
        guard let startTime = recordingStartTime, isRecording else { return 0.0 }
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Private Methods

    private func prepareRecording() throws {
        guard !isRecording else {
            throw CaptureError.alreadyRecording
        }

        let settings = AppSettings.shared
        let fileExtension = settings.videoFormat.lowercased()
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fluttro_recording_\(Date().timeIntervalSince1970).\(fileExtension)")
    }

    private func markRecordingStarted(at startDate: Date) {
        isRecording = true
        recordingStartTime = startDate
    }

    private func matchingExcludedWindows(
        in content: SCShareableContent,
        excludingWindows: [NSWindow],
        keeping windowID: CGWindowID? = nil
    ) async -> [SCWindow] {
        await MainActor.run {
            content.windows.filter { scWindow in
                if let windowID, scWindow.windowID == windowID {
                    return false
                }

                return excludingWindows.contains { nsWindow in
                    nsWindow.windowNumber == scWindow.windowID ||
                    (nsWindow.title == scWindow.title && !nsWindow.title.isEmpty)
                }
            }
        }
    }

    private func makeStreamConfiguration(
        sourceSize: CGSize,
        settings: AppSettings = .shared
    ) -> (configuration: SCStreamConfiguration, outputSize: CGSize) {
        let streamSettings = VideoCaptureConfigurationBuilder.streamSettings(
            sourceSize: sourceSize,
            settings: settings
        )
        return (streamSettings.makeStreamConfiguration(), streamSettings.outputSize)
    }

    private func startStream(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        recordingURL: URL,
        outputSize: CGSize
    ) async throws -> Date {
        currentRecordingSize = outputSize
        let output = VideoStreamOutput(recordingURL: recordingURL, outputSize: outputSize)
        streamOutput = output
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream?.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInitiated))
        try await stream?.startCapture()
        return try await waitForFirstFrame(from: output)
    }
    
    private func setupScreenCapture(
        displayID: CGDirectDisplayID? = nil,
        excludingWindows: [NSWindow] = []
    ) async throws -> Date {
        guard let recordingURL = recordingURL else {
            throw CaptureError.invalidRequest("No recording URL set")
        }
        
        // Get screen content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = CaptureDisplayResolver.scDisplay(for: displayID, in: content) else {
            throw CaptureError.unavailable
        }
        let screen = ScreenPixelGeometry.screen(for: display.displayID) ?? NSScreen.main
        
        let windowsToExclude = await matchingExcludedWindows(
            in: content,
            excludingWindows: excludingWindows
        )
        let settings = AppSettings.shared
        let sourceSize = ScreenPixelGeometry.captureSize(
            for: display,
            screen: screen,
            mode: settings.capturePixelMode
        )
        let stream = makeStreamConfiguration(sourceSize: sourceSize, settings: settings)
        let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)

        return try await startStream(
            filter: filter,
            configuration: stream.configuration,
            recordingURL: recordingURL,
            outputSize: stream.outputSize
        )
    }
    
    private func setupWindowCapture(window: SCWindow, excludingWindows: [NSWindow] = []) async throws -> Date {
        guard let recordingURL = recordingURL else {
            throw CaptureError.invalidRequest("No recording URL set")
        }
        
        // Get screen content to find the window
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let windowsToExclude = await matchingExcludedWindows(
            in: content,
            excludingWindows: excludingWindows,
            keeping: window.windowID
        )
        let settings = AppSettings.shared
        let sourceSize = ScreenPixelGeometry.captureSize(
            for: window,
            mode: settings.capturePixelMode
        )
        let stream = makeStreamConfiguration(sourceSize: sourceSize, settings: settings)
        let filter: SCContentFilter
        if #available(macOS 12.3, *) {
            filter = SCContentFilter(desktopIndependentWindow: window)
        } else {
            guard let display = content.displays.first else {
                throw CaptureError.unavailable
            }
            filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)
        }

        return try await startStream(
            filter: filter,
            configuration: stream.configuration,
            recordingURL: recordingURL,
            outputSize: stream.outputSize
        )
    }
    
    private func setupAreaCapture(areaRect: NSRect, excludingWindows: [NSWindow] = []) async throws -> Date {
        guard let recordingURL = recordingURL else {
            throw CaptureError.invalidRequest("No recording URL set")
        }
        
        // Get screen content to find the display
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        let windowsToExclude = await matchingExcludedWindows(
            in: content,
            excludingWindows: excludingWindows
        )
        let settings = AppSettings.shared
        
        guard let sourceScreen = ScreenPixelGeometry.screen(containing: areaRect) else {
            throw CaptureError.unavailable
        }
        guard let display = CaptureDisplayResolver.scDisplay(for: ScreenPixelGeometry.displayID(for: sourceScreen), in: content) else {
            throw CaptureError.unavailable
        }

        let convertedRect = CGRect(
            x: areaRect.minX - sourceScreen.frame.minX,
            y: sourceScreen.frame.maxY - areaRect.maxY,
            width: areaRect.width,
            height: areaRect.height
        )

        let sourceSize = ScreenPixelGeometry.captureSize(
            for: areaRect,
            on: sourceScreen,
            mode: settings.capturePixelMode
        )
        let stream = makeStreamConfiguration(sourceSize: sourceSize, settings: settings)
        stream.configuration.sourceRect = convertedRect
        let filter = SCContentFilter(display: display, excludingWindows: windowsToExclude)

        return try await startStream(
            filter: filter,
            configuration: stream.configuration,
            recordingURL: recordingURL,
            outputSize: stream.outputSize
        )
    }

    private func waitForFirstFrame(from output: VideoStreamOutput) async throws -> Date {
        let deadline = Date().addingTimeInterval(firstFrameTimeout)

        while Date() < deadline {
            try Task.checkCancellation()

            if let firstFrameDate = output.firstFrameDate {
                return firstFrameDate
            }

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        throw CaptureError.timeout
    }
    
    // MARK: - Window Activation
    
    /// Brings the selected window's application to the front
    @MainActor
    func bringWindowToFront(_ window: SCWindow) {
        guard let owningApp = window.owningApplication else {
            Logger.w("VideoRecordingService: Cannot bring window to front; no owning application")
            return
        }
        
        let appName = owningApp.applicationName
        let bundleId = owningApp.bundleIdentifier
        let windowTitle = window.title ?? "Untitled Window"
        
        Logger.d("VideoRecordingService: Bringing window to front: \(appName), \(bundleId), \(windowTitle)")
        
        // Try to activate the application first
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
        
        // Find the running application by bundle identifier
        if let targetApp = runningApps.first(where: { $0.bundleIdentifier == bundleId }) {
            // Activate the application
            targetApp.activate(options: [.activateIgnoringOtherApps])
            
            guard !bundleId.isEmpty, !windowTitle.isEmpty else {
                return
            }

            // Run AppleScript off the main thread so a slow Apple event does not freeze the floating panel UI.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
                self.bringSpecificWindowToFront(bundleIdentifier: bundleId, windowTitle: windowTitle)
            }
        } else {
            Logger.w("VideoRecordingService: Application not found in running apps: \(bundleId)")
        }
    }
    
    /// Uses AppleScript to bring a specific window to the front
    private func bringSpecificWindowToFront(bundleIdentifier: String, windowTitle: String) {
        let escapedBundleIdentifier = escapeAppleScriptString(bundleIdentifier)
        let escapedWindowTitle = escapeAppleScriptString(windowTitle)
        let script = """
        tell application id "\(escapedBundleIdentifier)"
            activate
            try
                set index of window "\(escapedWindowTitle)" to 1
            end try
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            Logger.w("VideoRecordingService: AppleScript window activation failed: \(error)")
        }
    }

    private func escapeAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
}

#endif
