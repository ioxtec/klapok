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
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.captureMode = .video
                }
            }) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.captureMode == .video ? .white : .secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.captureMode = .image
                }
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.captureMode == .image ? .white : .secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.thinMaterial)
                .frame(height: 34)
                .overlay(
                    HStack {
                        if viewModel.captureMode == .image {
                            Spacer()
                        }
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(viewModel.captureMode == .image ? .blue : .red)
                            .frame(width: 34, height: 30)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.captureMode)
                        if viewModel.captureMode == .video {
                            Spacer()
                        }
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.7)
        )
        .help(LocalizationKeys.captureModeToggleHelp.localized)
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
                        .foregroundColor(viewModel.screenshotType == type ? .white : .secondary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(PlainButtonStyle())
                .help(tooltipForType(type))
            }
        }
        .frame(width: 102)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.thinMaterial)
                .frame(height: 34)
                .overlay(
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 34 * CGFloat(positionIndex))
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(selectionColor)
                            .frame(width: 34, height: 30)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.screenshotType)
                        Spacer()
                    }
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.7)
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
        let baseTooltip: String
        
        if viewModel.captureMode == .video {
            switch viewModel.videoRecordingState {
            case .idle:
                switch type {
                case .fullScreen: baseTooltip = LocalizationKeys.recordFullScreenHelp.localized
                case .area: baseTooltip = LocalizationKeys.recordAreaHelp.localized
                case .window: baseTooltip = LocalizationKeys.recordWindowHelp.localized
                }
            case .recording:
                baseTooltip = LocalizationKeys.stopRecordingHelp.localized
            }
        } else {
            switch type {
            case .fullScreen: baseTooltip = LocalizationKeys.fullScreenCaptureHelp.localized
            case .area: baseTooltip = LocalizationKeys.areaCaptureHelp.localized
            case .window: baseTooltip = LocalizationKeys.windowCaptureHelp.localized
            }
        }

        return "\(baseTooltip) (\(keyNumber))"
    }
}

// MARK: - Capture Button

struct CaptureButton: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
        Button(action: {
            viewModel.performPrimaryCaptureAction()
        }) {
            ZStack {
                Circle()
                    .fill(buttonBackgroundColor)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                Circle()
                    .stroke(buttonStrokeColor, lineWidth: 3)
                    .frame(width: 42, height: 42)

                if viewModel.isCapturing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: buttonIconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isCapturing)
        .scaleEffect(viewModel.isCapturing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing)
        .help("\(buttonHelpText) (Space)")
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

    private var buttonHelpText: String {
        switch viewModel.captureMode {
        case .image:
            switch viewModel.screenshotType {
            case .fullScreen: return LocalizationKeys.fullScreenCaptureHelp.localized
            case .area: return LocalizationKeys.areaCaptureHelp.localized
            case .window: return LocalizationKeys.windowCaptureHelp.localized
            }
        case .video:
            if viewModel.videoRecordingState == .recording {
                return LocalizationKeys.stopRecordingHelp.localized
            }

            switch viewModel.screenshotType {
            case .fullScreen: return LocalizationKeys.recordFullScreenHelp.localized
            case .area: return LocalizationKeys.recordAreaHelp.localized
            case .window: return LocalizationKeys.recordWindowHelp.localized
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.red.opacity(0.22), lineWidth: 0.7)
        )
    }
}

// MARK: - Panel Control Buttons

struct PanelControlButtons: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                viewModel.closeFloatingPanel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(.thinMaterial)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help(LocalizationKeys.closePanelHelp.localized)
        }
    }
}

#endif
