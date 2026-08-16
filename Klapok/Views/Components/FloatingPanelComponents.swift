//
//  FloatingPanelComponents.swift
//  Klapok
//
//  Components for the floating screenshot panel
//

import SwiftUI

#if os(macOS)

private enum FloatingPanelSegmentedMetrics {
    static let itemWidth: CGFloat = 34
    static let itemHeight: CGFloat = 34
    static let highlightInset: CGFloat = 2
    static let cornerRadius: CGFloat = 17
    static let highlightCornerRadius: CGFloat = 15
}

private struct FloatingPanelSegmentedTrack: View {
    let itemCount: Int
    let selectedIndex: Int
    let tint: Color

    private var totalWidth: CGFloat {
        CGFloat(itemCount) * FloatingPanelSegmentedMetrics.itemWidth
    }

    private var highlightSize: CGFloat {
        FloatingPanelSegmentedMetrics.itemWidth - (FloatingPanelSegmentedMetrics.highlightInset * 2)
    }

    private var highlightOffset: CGFloat {
        (CGFloat(selectedIndex) * FloatingPanelSegmentedMetrics.itemWidth)
            + FloatingPanelSegmentedMetrics.highlightInset
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(
                cornerRadius: FloatingPanelSegmentedMetrics.cornerRadius,
                style: .continuous
            )
            .fill(.thinMaterial)

            RoundedRectangle(
                cornerRadius: FloatingPanelSegmentedMetrics.highlightCornerRadius,
                style: .continuous
            )
            .fill(tint)
            .frame(width: highlightSize, height: highlightSize)
            .offset(x: highlightOffset)
        }
        .frame(width: totalWidth, height: FloatingPanelSegmentedMetrics.itemHeight)
        .overlay(
            RoundedRectangle(
                cornerRadius: FloatingPanelSegmentedMetrics.cornerRadius,
                style: .continuous
            )
            .stroke(.white.opacity(0.14), lineWidth: 0.7)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: tint)
    }
}

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
                    .frame(
                        width: FloatingPanelSegmentedMetrics.itemWidth,
                        height: FloatingPanelSegmentedMetrics.itemHeight
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Video mode")
            .accessibilityIdentifier("floatingPanel.mode.video")
            .accessibilityValue(viewModel.captureMode == .video ? "selected" : "unselected")
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.captureMode = .image
                }
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.captureMode == .image ? .white : .secondary)
                    .frame(
                        width: FloatingPanelSegmentedMetrics.itemWidth,
                        height: FloatingPanelSegmentedMetrics.itemHeight
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Image mode")
            .accessibilityIdentifier("floatingPanel.mode.image")
            .accessibilityValue(viewModel.captureMode == .image ? "selected" : "unselected")
        }
        .background(
            FloatingPanelSegmentedTrack(
                itemCount: 2,
                selectedIndex: viewModel.captureMode == .video ? 0 : 1,
                tint: viewModel.captureMode == .image ? .blue : .red
            )
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
                        .frame(
                            width: FloatingPanelSegmentedMetrics.itemWidth,
                            height: FloatingPanelSegmentedMetrics.itemHeight
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(type.title)
                .accessibilityIdentifier("floatingPanel.captureType.\(type.rawValue)")
                .accessibilityValue(viewModel.screenshotType == type ? "selected" : "unselected")
                .help(tooltipForType(type))
            }
        }
        .frame(width: FloatingPanelSegmentedMetrics.itemWidth * CGFloat(availableCaptureTypes.count))
        .background(
            FloatingPanelSegmentedTrack(
                itemCount: availableCaptureTypes.count,
                selectedIndex: positionIndex,
                tint: selectionColor
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
        let baseTooltip: String
        
        if viewModel.captureMode == .video {
            switch viewModel.videoRecordingState {
            case .idle:
                switch type {
                case .fullScreen: baseTooltip = LocalizationKeys.recordFullScreenHelp.localized
                case .area: baseTooltip = LocalizationKeys.recordAreaHelp.localized
                case .window: baseTooltip = LocalizationKeys.recordWindowHelp.localized
                }
            case .starting:
                baseTooltip = LocalizationKeys.stopRecordingHelp.localized
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

// MARK: - Quick Settings Button

struct QuickSettingsButton: View {
    @ObservedObject var viewModel: FloatingPanelViewModel
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        Menu {
            Toggle(
                mouseCursorTitle,
                isOn: screenshotCursorBinding
            )

            if viewModel.captureMode == .video {
                Divider()

                Toggle(
                    LocalizationKeys.recordSystemAudioTitle.localized,
                    isOn: $settings.recordSystemAudio
                )
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 0.7)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Quick settings")
        .accessibilityIdentifier("floatingPanel.quickSettings")
        .help(quickSettingsHelpText)
    }

    private var mouseCursorTitle: String {
        switch viewModel.captureMode {
        case .image:
            return LocalizationKeys.showMouseCursorTitle.localized
        case .video:
            return LocalizationKeys.showMouseCursorVideoTitle.localized
        }
    }

    private var screenshotCursorBinding: Binding<Bool> {
        Binding(
            get: {
                switch viewModel.captureMode {
                case .image:
                    return settings.screenshotShowsMouseCursor
                case .video:
                    return settings.showMouseCursor
                }
            },
            set: { newValue in
                switch viewModel.captureMode {
                case .image:
                    settings.screenshotShowsMouseCursor = newValue
                case .video:
                    settings.showMouseCursor = newValue
                }
            }
        )
    }

    private var quickSettingsHelpText: String {
        switch viewModel.captureMode {
        case .image:
            return "Quick screenshot settings"
        case .video:
            return "Quick recording settings"
        }
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

                if viewModel.captureMode == .video && viewModel.videoRecordingState == .starting {
                    Circle()
                        .trim(from: 0.0, to: viewModel.currentPreparationProgress())
                        .stroke(buttonStrokeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 42, height: 42)
                        .rotationEffect(.degrees(-90))
                }

                if viewModel.isCapturing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if viewModel.captureMode == .video && viewModel.videoRecordingState == .starting && viewModel.recordingPreparationRemaining > 0.0 {
                    Text("\(viewModel.currentPreparationCountdownValue())")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .transition(.opacity)
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
        .accessibilityLabel(buttonHelpText)
        .accessibilityIdentifier("floatingPanel.primaryCapture")
        .accessibilityValue(viewModel.isCapturing ? "capturing" : "ready")
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
            case .starting: return "stop.circle.fill"
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
            if viewModel.videoRecordingState.isActive {
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
            
            Text(statusText)
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
        .accessibilityIdentifier("floatingPanel.recordingIndicator")
    }

    private var statusText: String {
        switch viewModel.videoRecordingState {
        case .idle:
            return "00:00"
        case .starting:
            if viewModel.recordingPreparationRemaining > 0.0 {
                return "Starting in \(viewModel.currentPreparationCountdownValue())"
            }
            return "Starting..."
        case .recording:
            return viewModel.formattedRecordingDuration()
        }
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
            .accessibilityLabel("Close floating panel")
            .accessibilityIdentifier("floatingPanel.close")
            .help(LocalizationKeys.closePanelHelp.localized)
        }
    }
}

#endif
