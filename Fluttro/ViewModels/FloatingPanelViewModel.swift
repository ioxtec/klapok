//
//  FloatingPanelViewModel.swift
//  Fluttro
//
//  ViewModel for floating panel controls
//

import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
    import ScreenCaptureKit

    final class FloatingPanelViewModel: ObservableObject {
        // MARK: - Published Properties

        @Published var captureMode: CaptureMode = .image
        @Published var screenshotType: CaptureType = AppSettings.shared.defaultCaptureType
        @Published var isCapturing: Bool = false
        @Published var isAreaSelectionActive: Bool = false
        @Published var isWindowSelectionActive: Bool = false
        @Published var isDisplayPickerPresented: Bool = false
        @Published var availableDisplays: [CaptureDisplay] = []
        @Published var selectedArea: NSRect = .zero
        @Published var selectedWindow: SCWindow?
        
        // Video recording state
        @Published var videoRecordingState: VideoRecordingState = .idle
        @Published var recordingDuration: TimeInterval = 0.0
        @Published var isVideoWindowSelectionPending: Bool = false
        private var recordingTimer: Timer?
        
        // Video editor window reference - simplified approach
        private var videoEditorWindow: NSWindow?
        private var videoEditorWindowDelegate: VideoEditorWindowDelegate?

        // MARK: - Dependencies

        @MainActor private let captureManager = CaptureManager.shared
        private let editorViewModel: EditorViewModel
        private let areaSelectionManager = AreaSelectionManager()
        @MainActor private lazy var windowSelectionManager = WindowSelectionManager()
        private let videoRecordingService = VideoRecordingService()

        // MARK: - Panel Visibility

        weak var panelWindow: NSPanel?
        var onPanelVisibilityChanged: (@MainActor (Bool) -> Void)?
        var onPanelClosed: (@MainActor () -> Void)?

        @MainActor
        func hideFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Hiding floating panel")
            panelWindow?.alphaValue = 1.0
            panelWindow?.orderOut(nil)
            onPanelVisibilityChanged?(false)
        }

        @MainActor
        func showFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Showing floating panel")
            panelWindow?.orderFront(nil)
            onPanelVisibilityChanged?(true)
            // Ensure floating panel is always on top
            if panelWindow != nil {
                ensurePanelOnTop()
            }
        }

        @MainActor
        func hideVideoEditorWindow() {
            videoEditorWindow?.orderOut(nil)
        }
        
        @MainActor
        func ensurePanelOnTop() {
            guard let panel = panelWindow else { return }

            panel.alphaValue = panelOpacity
            panel.hidesOnDeactivate = false
            panel.sharingType = .none
            panel.collectionBehavior = [
                .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
            ]

            WindowDepthManager.shared.ensureFloatingPanelOnTop(panel, pinned: true)
            
            // Bring to front
            panel.orderFrontRegardless()
        }

        private var panelOpacity: CGFloat {
            videoRecordingState == .recording ? 0.76 : 1.0
        }

        // MARK: - Initialization

        init(editorViewModel: EditorViewModel) {
            self.editorViewModel = editorViewModel
        }
        
        deinit {
            // Clean up video editor window if it exists
            if let window = videoEditorWindow {
                Task { @MainActor in
                    window.close()
                }
            }
            videoEditorWindow = nil
        }

        // MARK: - Public Methods

        @MainActor
        func setScreenshotType(_ newType: CaptureType) {
            let oldType = screenshotType
            screenshotType = newType
            handleScreenshotTypeChange(from: oldType, to: newType)
        }

        @MainActor
        func prepareForPresentation(mode: CaptureMode) {
            guard videoRecordingState == .idle else {
                captureMode = mode
                ensurePanelOnTop()
                return
            }

            captureMode = mode
            setScreenshotType(AppSettings.shared.defaultCaptureType)
            isDisplayPickerPresented = false
            resizePanelForDisplayPicker(false)
            ensurePanelOnTop()
        }

        @MainActor
        func performPrimaryCaptureAction() {
            if captureMode == .video && videoRecordingState == .recording {
                stopVideoRecording()
                return
            }

            if screenshotType == .fullScreen {
                presentDisplayPickerOrRunDefault()
                return
            }

            switch captureMode {
            case .image:
                Task {
                    await captureScreenshot()
                }
            case .video:
                switch videoRecordingState {
                case .idle:
                    if screenshotType == .window && selectedWindow == nil {
                        showWindowSelectionForVideo()
                    } else {
                        startVideoRecording()
                    }
                case .recording:
                    stopVideoRecording()
                }
            }
        }

        @MainActor
        func cancelDisplayPicker() {
            isDisplayPickerPresented = false
            resizePanelForDisplayPicker(false)
        }

        @MainActor
        func selectDisplay(_ display: CaptureDisplay) {
            isDisplayPickerPresented = false
            resizePanelForDisplayPicker(false)
            performFullScreenCapture(displayID: display.id)
        }

        @MainActor
        private func presentDisplayPickerOrRunDefault() {
            let displays = CaptureDisplayResolver.availableDisplays
            guard displays.count > 1 else {
                performFullScreenCapture(displayID: displays.first?.id)
                return
            }

            availableDisplays = displays
            resizePanelForDisplayPicker(true)
            isDisplayPickerPresented = true
            ensurePanelOnTop()
        }

        @MainActor
        private func resizePanelForDisplayPicker(_ isPresented: Bool) {
            guard let panel = panelWindow else { return }

            let targetSize = isPresented
                ? NSSize(width: 560, height: 250)
                : NSSize(width: 480, height: 90)
            var frame = panel.frame
            guard frame.size != targetSize else { return }

            frame.origin.x += (frame.width - targetSize.width) / 2
            frame.size = targetSize
            panel.setFrame(frame, display: true, animate: true)
        }

        @MainActor
        private func performFullScreenCapture(displayID: CGDirectDisplayID?) {
            switch captureMode {
            case .image:
                Task {
                    await captureFullScreen(displayID: displayID)
                }
            case .video:
                switch videoRecordingState {
                case .idle:
                    startVideoRecording(displayID: displayID)
                case .recording:
                    stopVideoRecording()
                }
            }
        }

        @MainActor
        private func captureFullScreen(displayID: CGDirectDisplayID?) async {
            isCapturing = true
            hideFloatingPanel()

            do {
                let image = try await captureManager.captureFullScreen(displayID: displayID)
                let sourceRect = ScreenPixelGeometry.screen(for: displayID)?.frame ?? NSScreen.main?.frame
                isCapturing = false
                presentCapturedScreenshot(image, sourceRect: sourceRect)
            } catch {
                isCapturing = false
                Logger.e("FloatingPanelViewModel: Full screen screenshot error: \(error)")
                showFloatingPanel()
            }
        }

        @MainActor
        func captureScreenshot() async {
            guard captureMode == .image else {
                Logger.w("FloatingPanelViewModel: Ignoring screenshot capture while video mode is active")
                return
            }

            isCapturing = true

            do {
                let image: NSImage
                let sourceRect: NSRect?

                switch screenshotType {
                case .fullScreen:
                    hideFloatingPanel()
                    image = try await captureManager.captureFullScreen()
                    sourceRect = NSScreen.main?.frame

                case .area:
                    Logger.d("FloatingPanelViewModel: Area mode - checking for active selection")

                    if isAreaSelectionActive {
                        let currentSelection = areaSelectionManager.getCurrentSelection()
                        Logger.d("FloatingPanelViewModel: Got selection: \(currentSelection)")

                        if !currentSelection.isEmpty && currentSelection.width > 10
                            && currentSelection.height > 10
                        {
                            // Hide area selection overlay BEFORE taking screenshot
                            Logger.d(
                                "FloatingPanelViewModel: Hiding area selection overlay before screenshot"
                            )
                            areaSelectionManager.hide(with: nil)
                            isAreaSelectionActive = false
                            hideFloatingPanel()

                            // Wait a bit for the overlay to disappear
                            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

                            // Now take the screenshot
                            image = try await captureManager.captureArea(currentSelection)
                            sourceRect = currentSelection
                        } else {
                            Logger.w("FloatingPanelViewModel: No valid selection")
                            isCapturing = false
                            showFloatingPanel()
                            return
                        }
                    } else {
                        Logger.w("FloatingPanelViewModel: Area selection not active")
                        isCapturing = false
                        showFloatingPanel()
                        return
                    }

                case .window:
                    guard let window = selectedWindow else {
                        Logger.w("No window selected")
                        // Show error message
                        showNoWindowSelectedMessage()
                        isCapturing = false
                        showFloatingPanel()
                        return
                    }
                    hideFloatingPanel()
                    image = try await captureManager.captureWindow(window)
                    sourceRect = window.frame
                }

                isCapturing = false
                presentCapturedScreenshot(image, sourceRect: sourceRect)
                Logger.s("FloatingPanelViewModel: Screenshot review opened successfully")

                // Hide window selection after successful capture
                if screenshotType == .window {
                    hideWindowSelection()
                }

                // Panel will be hidden by AppDelegate when editor opens

            } catch {
                isCapturing = false
                Logger.e("FloatingPanelViewModel: Screenshot error: \(error)")

                // Hide overlay in case of error as well
                if screenshotType == .window {
                    hideWindowSelection()
                }
                if screenshotType == .area {
                    hideAreaSelection()
                }

                // Show panel again only in case of error
                showFloatingPanel()
            }
        }

        // MARK: - Private Methods

        @MainActor
        private func handleScreenshotTypeChange(
            from oldType: CaptureType, to newType: CaptureType
        ) {
            Logger.d(
                "FloatingPanelViewModel: Screenshot type changing from \(oldType) to \(newType)")

            // Clean up old mode with delay to prevent race conditions
            switch oldType {
            case .area:
                hideAreaSelection()
            case .window:
                hideWindowSelection()
            case .fullScreen:
                break
            }

            // Add delay before activating new mode to ensure cleanup is complete
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay

                // Activate new mode
                switch newType {
                case .fullScreen:
                    break
                case .area:
                    showAreaSelection()
                case .window:
                    showWindowSelection()
                }
            }
        }

        @MainActor
        private func showAreaSelection() {
            Logger.d("FloatingPanelViewModel: Showing area selection")
            WindowDepthManager.shared.logCurrentLevels()

            hideAreaSelection()

            areaSelectionManager.show { rect in
                Logger.s(
                    "FloatingPanelViewModel: Area selection completed: \(String(describing: rect))"
                )
                if let rect = rect {
                    self.selectedArea = rect
                    Task {
                        await self.captureSelectedArea(rect: rect)
                    }
                } else {
                    // User cancelled (pressed Esc) - just hide area selection
                    Logger.d(
                        "FloatingPanelViewModel: Area selection cancelled"
                    )
                    self.hideAreaSelection()
                    // Don't automatically switch to fullScreen - let user choose
                }
            }

            isAreaSelectionActive = true
            Logger.s("FloatingPanelViewModel: Area selection active")

            // Ensure panel is on top of overlay
            ensurePanelOnTop()
        }

        @MainActor
        private func hideAreaSelection() {
            Logger.d("FloatingPanelViewModel: Hiding area selection")

            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false
            //selectedArea = .zero

            Logger.d("FloatingPanelViewModel: Area selection hidden")
        }

        @MainActor
        private func captureSelectedArea(rect: NSRect) async {
            Logger.d("FloatingPanelViewModel: Capturing selected area: \(rect)")
            isCapturing = true

            // Hide area selection overlay BEFORE taking screenshot
            Logger.d("FloatingPanelViewModel: Hiding area selection overlay before screenshot")
            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false
            hideFloatingPanel()

            // Wait a bit for the overlay to disappear
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await captureManager.captureArea(rect)
                isCapturing = false
                presentCapturedScreenshot(image, sourceRect: rect)
                Logger.s("FloatingPanelViewModel: Area screenshot completed")
            } catch {
                isCapturing = false
                Logger.e("FloatingPanelViewModel: Area capture error: \(error)")
                showFloatingPanel()
            }
        }

        @MainActor
        func showWindowSelectionForVideo() {
            isVideoWindowSelectionPending = true
            showWindowSelection()
        }
        
        @MainActor
        private func showWindowSelection() {
            Logger.d("FloatingPanelViewModel: Showing window selection")

            hideWindowSelection()

            windowSelectionManager.show { [weak self] selectedWindow in
                Logger.d(
                    "FloatingPanelViewModel: Window selection completed: \(String(describing: selectedWindow?.title))"
                )

                // Always set selectedWindow (may be nil if deselected)
                self?.selectedWindow = selectedWindow

                if let window = selectedWindow {
                    Logger.d(
                        "FloatingPanelViewModel: Window selected: \(window.title ?? "Unknown")")
                    
                    // If this was video window selection, start recording automatically
                    if self?.isVideoWindowSelectionPending == true {
                        self?.isVideoWindowSelectionPending = false
                        // Hide overlay and start recording
                        self?.hideWindowSelection()
                        Task {
                            self?.startVideoRecording()
                        }
                    }
                } else {
                    Logger.d("FloatingPanelViewModel: Window deselected")
                    // Reset the pending flag if window was deselected
                    self?.isVideoWindowSelectionPending = false
                }

                // Don't close overlay - it stays open for further selection (unless it's video mode)
            }
            
            // Ensure panel is on top of overlay
            ensurePanelOnTop()

            isWindowSelectionActive = true
            Logger.s("FloatingPanelViewModel: Window selection active")
        }

        @MainActor
        private func hideWindowSelection() {
            Logger.d("FloatingPanelViewModel: Hiding window selection")

            windowSelectionManager.hide()
            isWindowSelectionActive = false
            selectedWindow = nil

            Logger.d("FloatingPanelViewModel: Window selection hidden")
        }

        @MainActor
        private func captureSelectedWindow(window: SCWindow) async {
            Logger.d(
                "FloatingPanelViewModel: Capturing selected window: \(window.title ?? "Unknown")")

            // Hide window selection overlay
            hideWindowSelection()
            hideFloatingPanel()

            // Small delay to ensure overlay is hidden
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await captureManager.captureWindow(window)
                presentCapturedScreenshot(image, sourceRect: window.frame)
                Logger.s("FloatingPanelViewModel: Window screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Window capture error: \(error)")
                showFloatingPanel()  // Show panel back on error
            }
        }

        @MainActor
        private func presentCapturedScreenshot(_ image: NSImage, sourceRect: NSRect?) {
            ScreenshotReviewPresenter.shared.present(image: image, sourceRect: sourceRect) { [weak self] image in
                self?.editorViewModel.show(image: image)
            }
        }

        // MARK: - Panel Visibility Control

        @MainActor
        func initializeCurrentMode() {
            Logger.d("FloatingPanelViewModel: Initializing current mode: \(screenshotType)")
            // Activate current mode if not fullScreen
            switch screenshotType {
            case .area:
                if !isAreaSelectionActive {
                    showAreaSelection()
                }
            case .window:
                if !isWindowSelectionActive {
                    showWindowSelection()
                }
            case .fullScreen:
                break
            }
            
            // Ensure panel is on top
            ensurePanelOnTop()
        }

        @MainActor
        private func showNoWindowSelectedMessage() {
            // Show alert or notification about no selected window
            let alert = NSAlert()
            alert.messageText = "No Window Selected"
            alert.informativeText = "Please select a window first by clicking on it in the overlay."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")

            // Show me alert for 3s and close it.
            alert.runModal()
        }
        
        // MARK: - Video Recording Methods
        
        @MainActor
        func startVideoRecording(displayID: CGDirectDisplayID? = nil) {
            guard videoRecordingState == .idle else { return }
            
            // Store selected window and area before hiding overlays
            let windowToRecord = selectedWindow
            let areaToRecord = isAreaSelectionActive ? areaSelectionManager.getCurrentSelection() : nil
            
            // Hide window selection overlay before starting recording (area selection stays visible)
            if isWindowSelectionActive {
                hideWindowSelection()
            }
            // Note: We keep area selection overlay visible during video recording so user can see what's being recorded
            
            Task {
                do {
                    // Pass floating panel window to exclude from recording
                    let windowsToExclude: [NSWindow] = (panelWindow != nil) ? [panelWindow!] : []
                    
                    // Start recording based on current capture type
                    switch screenshotType {
                    case .fullScreen:
                        try await videoRecordingService.startRecording(
                            displayID: displayID,
                            excludingWindows: windowsToExclude
                        )
                    case .area:
                        // For area recording, check if an area is selected
                        if let area = areaToRecord, !area.isEmpty && area.width > 10 && area.height > 10 {
                            Logger.d("Starting area recording for: \(area)")
                            
                            // Start recording mode in area selection overlay
                            areaSelectionManager.startRecording()
                            
                            try await videoRecordingService.startRecordingArea(area, excludingWindows: windowsToExclude)
                        } else {
                            Logger.w("No valid area selected for area recording, falling back to full screen")
                            try await videoRecordingService.startRecording(excludingWindows: windowsToExclude)
                        }
                    case .window:
                        // For window recording, check if a window is selected
                        if let window = windowToRecord {
                            Logger.d("Starting window recording for: \(window.title ?? "Unknown")")
                            
                            // Bring the selected window to the front before recording
                            videoRecordingService.bringWindowToFront(window)
                            
                            try await videoRecordingService.startRecordingWindow(window, excludingWindows: windowsToExclude)
                        } else {
                            Logger.w("No window selected for window recording, falling back to full screen")
                            try await videoRecordingService.startRecording(excludingWindows: windowsToExclude)
                        }
                    }
                    
                    videoRecordingState = .recording
                    startRecordingTimer()
                    ensurePanelOnTop()
                    Logger.d("Video recording started for type: \(screenshotType)")
                } catch {
                    Logger.e("Failed to start video recording: \(error)")
                    videoRecordingState = .idle
                    ensurePanelOnTop()
                }
            }
        }
        
        
        @MainActor
        func stopVideoRecording() {
            guard videoRecordingState != .idle else { return }
            hideFloatingPanel()
            
            Task {
                do {
                    let recording = try await videoRecordingService.stopRecording()
                    videoRecordingState = .idle
                    stopRecordingTimer()
                    recordingDuration = 0.0
                    Logger.d("Video recording stopped: \(recording.duration)s")
                    
                    // Stop recording mode in area selection overlay
                    areaSelectionManager.stopRecording()
                    
                    // Hide any active overlays after recording stops
                    if isWindowSelectionActive {
                        hideWindowSelection()
                    }
                    if isAreaSelectionActive {
                        hideAreaSelection()
                    }
                    
                    await saveVideoAndOpenEditor(recording)
                } catch {
                    Logger.e("Failed to stop video recording: \(error)")
                    videoRecordingState = .idle
                    stopRecordingTimer()
                    recordingDuration = 0.0
                    showFloatingPanel()
                    
                    // Stop recording mode in area selection overlay
                    areaSelectionManager.stopRecording()
                    
                    // Hide overlays even if there was an error
                    if isWindowSelectionActive {
                        hideWindowSelection()
                    }
                    if isAreaSelectionActive {
                        hideAreaSelection()
                    }
                }
            }
        }

        @MainActor
        func cancelVideoRecording() {
            guard videoRecordingState != .idle else {
                cancelActiveCapture()
                return
            }

            videoRecordingState = .idle
            stopRecordingTimer()
            recordingDuration = 0.0
            ensurePanelOnTop()
            areaSelectionManager.stopRecording()
            cancelActiveCapture()

            Task {
                await videoRecordingService.cancelRecording()
                Logger.d("Video recording cancelled and discarded")
            }
        }
        
        @MainActor
        private func saveVideoAndOpenEditor(_ recording: VideoRecording) async {
            let settings = AppSettings.shared
            let originalDirectory = settings.videoSaveDirectory
            
            // Save video to user's chosen directory
            if let savedURL = settings.saveVideo(recording.url) {
                Logger.d("Video saved to: \(savedURL.path)")
                
                // Check if directory changed (fallback to default)
                if settings.videoSaveDirectory != originalDirectory {
                    showDirectoryChangedAlert(for: "video")
                }
                
                // Create new VideoRecording with saved URL
                let savedRecording = VideoRecording(
                    url: savedURL,
                    duration: recording.duration,
                    size: recording.size,
                    frameRate: recording.frameRate
                )
                
                // Open video in editor
                await openVideoInEditor(savedRecording)
            } else {
                Logger.e("Failed to save video")
                showSaveErrorAlert()
            }
        }
        
        @MainActor
        private func showDirectoryChangedAlert(for type: String) {
            let alert = NSAlert()
            alert.messageText = "Directory Changed"
            alert.informativeText = "Could not save \(type) to the selected directory due to permissions. Saved to default directory instead."
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .informational
            alert.runModal()
        }
        
        @MainActor
        private func showSaveErrorAlert() {
            let alert = NSAlert()
            alert.messageText = "Save Failed"
            alert.informativeText = "Could not save the video file. Please check your directory permissions."
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
        
        @MainActor
        private func openVideoInEditor(_ recording: VideoRecording) async {
            let fileExists = FileManager.default.fileExists(atPath: recording.url.path)
            guard fileExists else {
                Logger.e("FloatingPanelViewModel: Cannot open missing video file: \(recording.url.path)")
                return
            }
            
            // Create video editor view model
            let videoEditorViewModel = VideoEditorViewModel(video: recording)
            
            // Create video editor view
            let videoEditorView = VideoEditorView(viewModel: videoEditorViewModel)
            
            let hostingController = NSHostingController(rootView: videoEditorView)
            hostingController.view.wantsLayer = true
            hostingController.view.layer?.cornerRadius = 18
            hostingController.view.layer?.cornerCurve = .continuous
            hostingController.view.layer?.masksToBounds = true
            
            // Create window delegate
            let windowDelegate = VideoEditorWindowDelegate()
            
            // Create video editor window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.contentViewController = hostingController
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            window.contentView?.layer?.cornerRadius = 18
            window.contentView?.layer?.cornerCurve = .continuous
            window.contentView?.layer?.masksToBounds = true
            window.title = "Fluttro Video Editor"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.delegate = windowDelegate
            window.minSize = NSSize(width: 1180, height: 720)
            window.isReleasedWhenClosed = false
            WindowPlacement.center(window, on: panelWindow?.screen)
            videoEditorWindow = window
            videoEditorWindowDelegate = windowDelegate
            window.makeKeyAndOrderFront(nil)
            refreshVideoEditorWindowLayout(window)

            DispatchQueue.main.async {
                self.refreshVideoEditorWindowLayout(window)
            }
        }

        @MainActor
        private func refreshVideoEditorWindowLayout(_ window: NSWindow) {
            window.contentView?.needsLayout = true
            window.contentView?.layoutSubtreeIfNeeded()
            window.contentView?.needsDisplay = true
            window.invalidateShadow()

            let frame = window.frame
            let nudgedFrame = NSRect(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width + 1,
                height: frame.height
            )

            window.setFrame(nudgedFrame, display: true, animate: false)
            window.setFrame(frame, display: true, animate: false)
        }
        
        // MARK: - Panel Management
        
        @MainActor
        func closeFloatingPanel() {
            if videoRecordingState != .idle {
                cancelVideoRecording()
            } else {
                cancelActiveCapture()
            }

            // Close the panel window
            panelWindow?.close()
            panelWindow = nil
            onPanelClosed?()
        }

        @MainActor
        private func cancelActiveCapture() {
            hideAreaSelection()
            hideWindowSelection()
            isVideoWindowSelectionPending = false
            selectedArea = .zero
        }
        
        private func startRecordingTimer() {
            stopRecordingTimer() // Stop any existing timer
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.recordingDuration = self?.videoRecordingService.currentRecordingDuration ?? 0.0
                }
            }
        }
        
        private func stopRecordingTimer() {
            recordingTimer?.invalidate()
            recordingTimer = nil
        }
        
        func formattedRecordingDuration() -> String {
            let minutes = Int(recordingDuration) / 60
            let seconds = Int(recordingDuration) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

// MARK: - Video Editor Window Delegate
@MainActor
class VideoEditorWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
}

#endif
