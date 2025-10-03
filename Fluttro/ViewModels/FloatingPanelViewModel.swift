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
        @Published var screenshotType: CaptureType = .fullScreen
        @Published var isCapturing: Bool = false
        @Published var isAreaSelectionActive: Bool = false
        @Published var isWindowSelectionActive: Bool = false
        @Published var selectedArea: NSRect = .zero
        @Published var selectedWindow: SCWindow?
        
        // Video recording state
    @Published var videoRecordingState: VideoRecordingState = .idle
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var isAlwaysOnTop: Bool = false
    @Published var isVideoWindowSelectionPending: Bool = false
        private var recordingTimer: Timer?
        
        // Video editor window reference - simplified approach
        private var videoEditorWindow: NSWindow?

        // MARK: - Dependencies

        @MainActor private let captureManager = CaptureManager.shared
        private let editorViewModel: EditorViewModel
        private let areaSelectionManager = AreaSelectionManager()
        @MainActor private lazy var windowSelectionManager = WindowSelectionManager()
        private let videoRecordingService = VideoRecordingService()

        // MARK: - Panel Visibility

        weak var panelWindow: NSPanel?

        @MainActor
        func hideFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Hiding floating panel")
            panelWindow?.orderOut(nil)
        }

        @MainActor
        func showFloatingPanel() {
            Logger.d("FloatingPanelViewModel: Showing floating panel")
            panelWindow?.orderFront(nil)
            // Ensure floating panel is always on top
            if panelWindow != nil {
                ensurePanelOnTop()
            }
        }
        
        @MainActor
        func ensurePanelOnTop() {
            guard let panel = panelWindow else { return }
            
            if isAlwaysOnTop {
                // Use the highest possible level
                panel.level = .screenSaver
            } else {
                // Use the standard floating panel level (which is now very high)
                WindowDepthManager.shared.setLevel(for: panel, type: .floatingPanel)
            }
            
            // Bring to front
            panel.orderFrontRegardless()
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
        func captureScreenshot() async {
            guard captureMode == .image else {
                Logger.w("Video recording not yet implemented")
                return
            }

            isCapturing = true
            defer {
                isCapturing = false
            }

            // Hide floating panel immediately when user clicks capture button
            hideFloatingPanel()

            // Small delay to ensure panel is hidden
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

            do {
                let image: NSImage

                switch screenshotType {
                case .fullScreen:
                    image = try await captureManager.captureFullScreen()

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

                            // Wait a bit for the overlay to disappear
                            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

                            // Now take the screenshot
                            image = try await captureManager.captureArea(currentSelection)
                        } else {
                            Logger.w("FloatingPanelViewModel: No valid selection")
                            showFloatingPanel()
                            return
                        }
                    } else {
                        Logger.w("FloatingPanelViewModel: Area selection not active")
                        showFloatingPanel()
                        return
                    }

                case .window:
                    guard let window = selectedWindow else {
                        Logger.w("No window selected")
                        // Pokaż komunikat o błędzie
                        showNoWindowSelectedMessage()
                        showFloatingPanel()
                        return
                    }
                    image = try await captureManager.captureWindow(window)
                }

                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Editor opened successfully")

                // Ukryj window selection po udanym zrzucie
                if screenshotType == .window {
                    hideWindowSelection()
                }

                // Panel zostanie ukryty przez AppDelegate gdy edytor się otworzy

            } catch {
                Logger.e("FloatingPanelViewModel: Screenshot error: \(error)")

                // Ukryj overlay również w przypadku błędu
                if screenshotType == .window {
                    hideWindowSelection()
                }
                if screenshotType == .area {
                    hideAreaSelection()
                }

                // Pokaż panel z powrotem tylko w przypadku błędu
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

            Task {
                do {
                    let fullScreenImage = try await captureManager.captureFullScreen()
                    Logger.s("FloatingPanelViewModel: Background captured: \(fullScreenImage.size)")

                    await MainActor.run {
                        areaSelectionManager.show(backgroundImage: fullScreenImage) { rect in
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
                        
                        // Upewnij się że panel jest na wierzchu nad overlay
                        ensurePanelOnTop()
                    }
                } catch {
                    Logger.e("FloatingPanelViewModel: Error creating overlay: \(error)")
                }
            }
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

            // Hide area selection overlay BEFORE taking screenshot
            Logger.d("FloatingPanelViewModel: Hiding area selection overlay before screenshot")
            areaSelectionManager.hide(with: nil)
            isAreaSelectionActive = false

            // Wait a bit for the overlay to disappear
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await captureManager.captureArea(rect)
                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Area screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Area capture error: \(error)")
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

                // Zawsze ustaw selectedWindow (może być nil jeśli odznaczono)
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

                // NIE zamykamy overlay - zostaje otwarty dla dalszego wyboru (unless it's video mode)
            }
            
            // Upewnij się że panel jest na wierzchu nad overlay
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

            // Small delay to ensure overlay is hidden
            do {
                try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            } catch {
                Logger.w("FloatingPanelViewModel: Sleep interrupted: \(error)")
            }

            do {
                let image = try await captureManager.captureWindow(window)
                editorViewModel.show(image: image)
                Logger.s("FloatingPanelViewModel: Window screenshot completed")
            } catch {
                Logger.e("FloatingPanelViewModel: Window capture error: \(error)")
                showFloatingPanel()  // Show panel back on error
            }
        }

        // MARK: - Panel Visibility Control

        @MainActor
        func initializeCurrentMode() {
            Logger.d("FloatingPanelViewModel: Initializing current mode: \(screenshotType)")
            // Aktywuj aktualny tryb jeśli nie jest fullScreen
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
            
            // Upewnij się że panel jest na wierzchu
            ensurePanelOnTop()
        }

        @MainActor
        private func showNoWindowSelectedMessage() {
            // Pokaż alert lub notification o braku zaznaczonego okna
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
        func startVideoRecording() {
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
                        try await videoRecordingService.startRecording(excludingWindows: windowsToExclude)
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
                    Logger.d("Video recording started for type: \(screenshotType)")
                } catch {
                    Logger.e("Failed to start video recording: \(error)")
                    // TODO: Show error to user
                }
            }
        }
        
        
        @MainActor
        func stopVideoRecording() {
            guard videoRecordingState != .idle else { return }
            
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
                    
                    // Save video to user's chosen directory
                    await saveVideoAndOpenEditor(recording)
                } catch {
                    Logger.e("Failed to stop video recording: \(error)")
                    
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
            Logger.d("🔍 openVideoInEditor called - TESTING WITH SIMPLE WINDOW + DELEGATE")
            Logger.d("🔍 Video file: \(recording.url.path)")
            Logger.d("🔍 Video duration: \(recording.duration)")
            Logger.d("🔍 Video size: \(recording.size)")
            Logger.d("🔍 Video frame rate: \(recording.frameRate)")
            
            // Check if video file still exists
            let fileExists = FileManager.default.fileExists(atPath: recording.url.path)
            Logger.d("🔍 Video file exists: \(fileExists)")
            
            if fileExists {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: recording.url.path)[.size] as? Int64) ?? 0
                Logger.d("🔍 Video file size: \(fileSize) bytes")
            }
            
            // Create video editor view model
            let videoEditorViewModel = VideoEditorViewModel(video: recording)
            
            // Create video editor view
            let videoEditorView = VideoEditorView(viewModel: videoEditorViewModel)
            
            // Create hosting view
            let hostingView = NSHostingView(rootView: videoEditorView)
            hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
            
            // Create window delegate
            let windowDelegate = VideoEditorWindowDelegate()
            
            // Create video editor window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Video Editor - \(recording.url.lastPathComponent)"
            window.contentView = hostingView
            window.delegate = windowDelegate
            window.isReleasedWhenClosed = false
            window.center()
            window.makeKeyAndOrderFront(nil)
            
            Logger.d("🔍 Video editor window created and shown")
        }
        
        // MARK: - Panel Management
        
        @MainActor
        func closeFloatingPanel() {
            // Stop any active recording
            if videoRecordingState != .idle {
                Task {
                     stopVideoRecording()
                }
            }
            
            // Hide overlays and clear selections
            isAreaSelectionActive = false
            isWindowSelectionActive = false
            selectedArea = .zero
            selectedWindow = nil
            
            // Close the panel window
            panelWindow?.close()
            panelWindow = nil
        }
        
        @MainActor
        func toggleAlwaysOnTop() {
            isAlwaysOnTop.toggle()
            ensurePanelOnTop()
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
    override init() {
        super.init()
        print("🔍 VideoEditorWindowDelegate: init called")
    }
    
    func windowWillClose(_ notification: Notification) {
        print("🔍 VideoEditorWindowDelegate: windowWillClose called")
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("🔍 VideoEditorWindowDelegate: windowShouldClose called")
        return true
    }
    
    deinit {
        print("🔍 VideoEditorWindowDelegate: deinit called")
    }
}

#endif
