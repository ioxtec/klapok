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
            VStack(spacing: 0) {
                // Header with recording indicator and controls
                HStack {
                    // Recording indicator (top-left)
                    if viewModel.captureMode == .video && viewModel.videoRecordingState == .recording {
                        recordingIndicator
                    }
                    
                    Spacer()
                    
                    // Top-right controls
                    HStack(spacing: 8) {
                        // Always on top toggle
                        alwaysOnTopToggle
                        
                        // Close button
                        closeButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Main controls
                HStack(spacing: 20) {
                    captureModeToggle
                    
                    // Both modes now show the same 3 buttons (fullscreen/area/window)
                    animatedTypeSelector
                    
                    captureButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
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
                ForEach(Array(availableCaptureTypes.enumerated()), id: \.element) { index, type in
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
            .frame(width: 95) // Fixed width for consistent layout
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
        
        private var availableCaptureTypes: [CaptureType] {
            // Now area selection is supported in video mode with sourceRect
            return CaptureType.allCases
        }
        
        private var selectionColor: Color {
            switch viewModel.captureMode {
            case .image:
                return .blue
            case .video:
                // In video mode, use different colors based on recording state
                switch viewModel.videoRecordingState {
                case .idle:
                    return .red
                case .recording:
                    return .red
                }
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
            // Only handle available types in video mode
            guard availableCaptureTypes.contains(type) else { return }
            
            // In video mode, just update the selection - don't start recording
            // Recording will start only when user clicks the capture button
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.setScreenshotType(type)
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
                // Check if we need to show window selection first
                if viewModel.screenshotType == .window && viewModel.selectedWindow == nil {
                    // Show window selection overlay first (will auto-start recording after selection)
                    viewModel.showWindowSelectionForVideo()
                } else {
                    // Start recording directly
                    viewModel.startVideoRecording()
                }
            case .recording:
                viewModel.stopVideoRecording()
            }
        }
        
        // MARK: - Button Styling Properties
        
        private var buttonBackgroundColor: Color {
            if viewModel.isCapturing {
                return .gray
            } else {
                switch viewModel.captureMode {
                case .image:
                    return .blue
                case .video:
                    return .red
                }
            }
        }
        
        private var buttonStrokeColor: Color {
            switch viewModel.captureMode {
            case .image:
                return .blue
            case .video:
                return .red
            }
        }
        
        private var buttonIconName: String {
            switch viewModel.captureMode {
            case .image:
                return "camera.fill"
            case .video:
                // In video mode, show video camera/stop based on recording state
                switch viewModel.videoRecordingState {
                case .idle:
                    return "video.fill"
                case .recording:
                    return "stop.circle.fill"
                }
            }
        }
        
        
        private var recordingStatusText: String {
            switch viewModel.videoRecordingState {
            case .idle:
                return ""
            case .recording:
                return "Recording"
            }
        }

        // MARK: - Recording Indicator
        
        private var recordingIndicator: some View {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.8)
                
                Text(viewModel.formattedRecordingDuration())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
            )
        }
        
        // MARK: - Always On Top Toggle
        
        private var alwaysOnTopToggle: some View {
            Button(action: {
                viewModel.toggleAlwaysOnTop()
            }) {
                Image(systemName: viewModel.isAlwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.isAlwaysOnTop ? .blue : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .help(viewModel.isAlwaysOnTop ? "Disable Always On Top" : "Enable Always On Top")
        }
        
        // MARK: - Close Button
        
        private var closeButton: some View {
            Button(action: {
                viewModel.closeFloatingPanel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close Panel")
        }
        

        // MARK: - Helper Methods
        
        private func tooltipForType(_ type: CaptureType) -> String {
            let keyNumber = CaptureType.allCases.firstIndex(of: type)! + 1
            
            if viewModel.captureMode == .video {
                // Video mode tooltips based on recording state
                switch viewModel.videoRecordingState {
                case .idle:
                    switch type {
                    case .fullScreen: return "Record Full Screen (\(keyNumber))"
                    case .area: return "Area recording not available in video mode"
                    case .window: return "Record Selected Window (\(keyNumber))"
                    }
                case .recording:
                    switch type {
                    case .fullScreen: return "Stop Recording (\(keyNumber))"
                    case .area: return "Stop Recording (\(keyNumber))"
                    case .window: return "Stop Recording (\(keyNumber))"
                    }
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
