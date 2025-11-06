//
//  FloatingPanelComponents.swift
//  Fluttro
//
//  Components for the floating screenshot panel
//

import SwiftUI

#if os(macOS)

// MARK: - Capture Mode Toggle

struct CaptureModeToggle: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Video icon button
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
            
            // Camera icon button
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
}

// MARK: - Capture Type Selector

struct CaptureTypeSelector: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(availableCaptureTypes.enumerated()), id: \.element) { index, type in
                Button(action: {
                    if viewModel.captureMode == .video {
                        handleVideoControlAction(for: type)
                    } else {
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
        .frame(width: 95)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 32)
                .overlay(
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
    
    private var availableCaptureTypes: [CaptureType] {
        return CaptureType.allCases
    }
    
    private var selectionColor: Color {
        switch viewModel.captureMode {
        case .image: return .blue
        case .video: return .red
        }
    }
    
    private var positionIndex: Int {
        switch viewModel.screenshotType {
        case .fullScreen: return 0
        case .area: return 1
        case .window: return 2
        }
    }
    
    private func handleVideoControlAction(for type: CaptureType) {
        guard availableCaptureTypes.contains(type) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.setScreenshotType(type)
        }
    }
    
    private func tooltipForType(_ type: CaptureType) -> String {
        let keyNumber = CaptureType.allCases.firstIndex(of: type)! + 1
        
        if viewModel.captureMode == .video {
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
            switch type {
            case .fullScreen: return "Full Screen (\(keyNumber))"
            case .area: return "Area Selection (\(keyNumber))"
            case .window: return "Window Capture (\(keyNumber))"
            }
        }
    }
}

// MARK: - Capture Button

struct CaptureButton: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
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
            if viewModel.screenshotType == .window && viewModel.selectedWindow == nil {
                viewModel.showWindowSelectionForVideo()
            } else {
                viewModel.startVideoRecording()
            }
        case .recording:
            viewModel.stopVideoRecording()
        }
    }
    
    private var buttonBackgroundColor: Color {
        if viewModel.isCapturing {
            return .gray
        } else {
            switch viewModel.captureMode {
            case .image: return .blue
            case .video: return .red
            }
        }
    }
    
    private var buttonStrokeColor: Color {
        switch viewModel.captureMode {
        case .image: return .blue
        case .video: return .red
        }
    }
    
    private var buttonIconName: String {
        switch viewModel.captureMode {
        case .image:
            return "camera.fill"
        case .video:
            switch viewModel.videoRecordingState {
            case .idle: return "video.fill"
            case .recording: return "stop.circle.fill"
            }
        }
    }
}

// MARK: - Recording Indicator

struct RecordingIndicator: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
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
}

// MARK: - Panel Control Buttons

struct PanelControlButtons: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // Always on top toggle
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
            
            // Close button
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
    }
}

#endif

