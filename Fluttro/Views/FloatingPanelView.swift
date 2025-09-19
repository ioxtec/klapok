//
//  FloatingPanelView.swift
//  Fluttro
//
//  SwiftUI view for floating screenshot panel
//

import SwiftUI

#if os(macOS)

    struct FloatingPanelView: View {
        @ObservedObject var viewModel: FloatingPanelViewModel

        init(viewModel: FloatingPanelViewModel) {
            self.viewModel = viewModel
        }

        // Backward compatibility initializer
        init(editorViewModel: EditorViewModel) {
            self.viewModel = FloatingPanelViewModel(editorViewModel: editorViewModel)
        }

        var body: some View {
            VStack(spacing: 8) {
                HStack(spacing: 20) {
                    captureModeToggle
                    
                    if viewModel.captureMode == .image {
                        // Image mode: show 3 buttons for fullscreen/area/window
                        animatedTypeSelector
                    } else {
                        // Video mode: show recording indicator (red dot + timer + stop)
                        videoRecordingIndicator
                    }
                    
                    captureButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 80)
            .onKeyPress(.space) {
                Task {
                    await viewModel.captureScreenshot()
                }
                return .handled
            }
            .onKeyPress("1") {
                viewModel.setScreenshotType(.fullScreen)
                return .handled
            }
            .onKeyPress("2") {
                viewModel.setScreenshotType(.area)
                return .handled
            }
            .onKeyPress("3") {
                viewModel.setScreenshotType(.window)
                return .handled
            }
            .onKeyPress("v") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.captureMode = viewModel.captureMode == .image ? .video : .image
                }
                return .handled
            }
        }

        // MARK: - Capture Mode Toggle

        private var captureModeToggle: some View {
            HStack(spacing: 0) {
                // Camera icon (Image mode)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.captureMode = .video
                    }
                }) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.captureMode == .image ? .white : .primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Video icon (Video mode)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.captureMode = .image
                    }
                }) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.captureMode == .video ? .white : .primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 32)
                    .overlay(
                        // Animated selection indicator
                        HStack {
                            if viewModel.captureMode == .image {
                                Spacer()
                            }
                            RoundedRectangle(cornerRadius: 14)
                                .fill(viewModel.captureMode == .image ? .blue : .red)
                                .frame(width: 32, height: 28)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.captureMode)
                            if viewModel.captureMode == .video {
                                Spacer()
                            }
                        }
                    )
            )
            .help("Switch between photo and video mode (V)")
        }

        // MARK: - Animated Type Selector

        private var animatedTypeSelector: some View {
            HStack(spacing: 0) {
                ForEach(Array(CaptureType.allCases.enumerated()), id: \.element) { index, type in
                    Button(action: {
                        if viewModel.captureMode == .video {
                            // In video mode, handle recording control
                            handleVideoControlAction(for: type)
                        } else {
                            // In image mode, handle screenshot type selection
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.setScreenshotType(type)
                            }
                        }
                    }) {
                        Image(systemName: type.iconName(for: viewModel.captureMode))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(viewModel.screenshotType == type ? .white : .primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(tooltipForType(type))
                }
            }
            .frame(width: 95) // Fixed width to match videoRecordingIndicator
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 32)
                    .overlay(
                        // Animated selection indicator
                        HStack(spacing: 0) {
                            Spacer()
                                .frame(width: 32 * CGFloat(positionIndex))
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectionColor)
                                .frame(width: 32, height: 28)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.screenshotType)
                            Spacer()
                        }
                    )
            )
        }
        
        // MARK: - Layout Properties
        
        private var selectionColor: Color {
            switch viewModel.captureMode {
            case .image:
                return .blue
            case .video:
                return .red
            }
        }
        
        private var positionIndex: Int {
            switch viewModel.screenshotType {
            case .fullScreen:
                return 0
            case .area:
                return 1
            case .window:
                return 2
            }
        }
        
        // MARK: - Video Control Actions
        
        private func handleVideoControlAction(for type: CaptureType) {
            // First, update the selection with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.setScreenshotType(type)
            }
            
            // Then, handle the recording control action
            switch type {
            case .fullScreen:
                // Play button - start recording
                Task {
                    viewModel.startVideoRecording()
                }
            case .area:
                // Pause button - pause/resume recording
                Task {
                    if viewModel.videoRecordingState == .recording {
                        viewModel.pauseVideoRecording()
                    } else if viewModel.videoRecordingState == .paused {
                        viewModel.resumeVideoRecording()
                    }
                }
            case .window:
                // Stop button - stop recording
                Task {
                    viewModel.stopVideoRecording()
                }
            }
        }

        // MARK: - Capture Button

        private var captureButton: some View {
            Button(action: {
                handleCaptureAction()
            }) {
                ZStack {
                    Circle()
                        .fill(buttonBackgroundColor)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Circle()
                        .stroke(buttonStrokeColor, lineWidth: 3)
                        .frame(width: 52, height: 52)

                    if viewModel.isCapturing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: buttonIconName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isCapturing)
            .scaleEffect(viewModel.isCapturing ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing)
            .help("Take \(viewModel.screenshotType.title.lowercased()) (Space)")
        }
        
        // MARK: - Video Recording Indicator
        
        private var videoRecordingIndicator: some View {
            HStack(spacing: 12) {
                // Always visible dot (gray when idle, red when recording)
                Circle()
                    .fill(recordingIndicatorColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(viewModel.videoRecordingState == .recording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                             value: viewModel.videoRecordingState == .recording)
                
                // Recording timer with fixed width to prevent layout shifts
                Text(viewModel.formattedRecordingDuration())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 40, alignment: .leading) // Fixed width to prevent layout shifts
                
                // Always visible stop button (disabled when idle)
                Button(action: {
                    Task {
                        viewModel.stopVideoRecording()
                    }
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(stopButtonColor)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.videoRecordingState == .idle)
                .help(stopButtonTooltip)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 95) // Fixed width to prevent layout shifts
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 32)
            )
        }
        
        // MARK: - Action Handlers
        
        private func handleCaptureAction() {
            switch viewModel.captureMode {
            case .image:
                Task {
                    await viewModel.captureScreenshot()
                }
            case .video:
                handleVideoAction()
            }
        }
        
        private func handleVideoAction() {
            switch viewModel.videoRecordingState {
            case .idle:
                viewModel.startVideoRecording()
            case .recording:
                viewModel.pauseVideoRecording()
            case .paused:
                viewModel.resumeVideoRecording()
            }
        }
        
        // MARK: - Button Styling Properties
        
        private var buttonBackgroundColor: Color {
            if viewModel.isCapturing {
                return .gray
            } else if viewModel.captureMode == .video && viewModel.videoRecordingState == .recording {
                return .red.opacity(0.8)
            } else {
                return .white
            }
        }
        
        private var buttonStrokeColor: Color {
            if viewModel.captureMode == .video && viewModel.videoRecordingState == .recording {
                return .red
            } else {
                return .primary.opacity(0.3)
            }
        }
        
        private var buttonIconName: String {
            switch viewModel.captureMode {
            case .image:
                return "camera.fill"
            case .video:
                // In video mode, show play/pause based on recording state
                switch viewModel.videoRecordingState {
                case .idle:
                    return "play.circle.fill"
                case .recording:
                    return "pause.circle.fill"
                case .paused:
                    return "play.circle.fill"
                }
            }
        }
        
        // MARK: - Video Recording Properties
        
        private var recordingIndicatorColor: Color {
            switch viewModel.videoRecordingState {
            case .idle:
                return .gray // Dark gray dot when idle
            case .recording:
                return .red
            case .paused:
                return .orange
            }
        }
        
        private var stopButtonColor: Color {
            switch viewModel.videoRecordingState {
            case .idle:
                return .gray // Gray when disabled
            case .recording, .paused:
                return .red // Red when active
            }
        }
        
        private var stopButtonTooltip: String {
            switch viewModel.videoRecordingState {
            case .idle:
                return "Start recording to enable stop"
            case .recording, .paused:
                return "Stop recording"
            }
        }
        
        private var recordingStatusText: String {
            switch viewModel.videoRecordingState {
            case .idle:
                return ""
            case .recording:
                return "Recording"
            case .paused:
                return "Paused"
            }
        }

        // MARK: - Helper Methods
        
        private func tooltipForType(_ type: CaptureType) -> String {
            let keyNumber = CaptureType.allCases.firstIndex(of: type)! + 1
            
            if viewModel.captureMode == .video {
                // Video mode tooltips
                switch type {
                case .fullScreen: return "Start Recording (\(keyNumber))"
                case .area: return "Pause/Resume Recording (\(keyNumber))"
                case .window: return "Stop Recording (\(keyNumber))"
                }
            } else {
                // Image mode tooltips
                switch type {
                case .fullScreen: return "Full Screen (\(keyNumber))"
                case .area: return "Area Selection (\(keyNumber))"
                case .window: return "Window Capture (\(keyNumber))"
                }
            }
        }
    }

    #Preview {
        FloatingPanelView(viewModel: FloatingPanelViewModel(editorViewModel: EditorViewModel()))
            .padding()
    }

#endif
