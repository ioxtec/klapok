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
            HStack(spacing: 20) {
                captureModeToggle
                screenshotTypeSelector
                captureButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(height: 80)
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
                viewModel.captureMode = viewModel.captureMode == .image ? .video : .image
                return .handled
            }
        }

        // MARK: - Capture Mode Toggle

        private var captureModeToggle: some View {
            VStack(spacing: 4) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.captureMode = viewModel.captureMode == .image ? .video : .image
                    }
                }) {
                    Image(systemName: viewModel.captureMode.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(viewModel.captureMode == .image ? .blue : .red)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(
                                    viewModel.captureMode == .image
                                        ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Switch between photo and video mode (V)")
            }
        }

        // MARK: - Screenshot Type Selector

        private var screenshotTypeSelector: some View {
            HStack(spacing: 8) {
                ForEach(ScreenshotType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.setScreenshotType(type)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(
                                    viewModel.screenshotType == type ? .white : .primary
                                )
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            viewModel.screenshotType == type
                                                ? Color.accentColor : Color.clear)
                                )

                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(tooltipForType(type))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
            )
        }

        // MARK: - Capture Button

        private var captureButton: some View {
            Button(action: {
                Task {
                    await viewModel.captureScreenshot()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(viewModel.isCapturing ? Color.gray : Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Circle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 3)
                        .frame(width: 70, height: 70)

                    if viewModel.isCapturing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(
                            systemName: viewModel.captureMode == .image
                                ? "camera.fill" : "video.fill"
                        )
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

        // MARK: - Helper Methods

        private func tooltipForType(_ type: ScreenshotType) -> String {
            let keyNumber = ScreenshotType.allCases.firstIndex(of: type)! + 1
            switch type {
            case .fullScreen: return "Full Screen (\(keyNumber))"
            case .area: return "Area Selection (\(keyNumber))"
            case .window: return "Window Capture (\(keyNumber))"
            }
        }
    }

    #Preview {
        FloatingPanelView(viewModel: FloatingPanelViewModel(editorViewModel: EditorViewModel()))
            .padding()
    }

#endif
