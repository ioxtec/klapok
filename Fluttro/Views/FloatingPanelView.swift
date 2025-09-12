//
//  FloatingPanelView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 11/09/2025.
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
                // 1. Przełącznik obraz/video (po lewej)
                captureModeToggle

                // 2. Grupa przełączników rodzaju zrzutu
                screenshotTypeSelector

                // 3. Duży przycisk migawki (po prawej)
                captureButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
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
            // Overlay będzie pokazany jako osobne okno
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
                .help("Przełącz między trybem zdjęć i video (V)")

                Text(viewModel.captureMode.title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

                            Text(type.title)
                                .font(.caption2)
                                .foregroundColor(
                                    viewModel.screenshotType == type ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("\(type.title) (\(ScreenshotType.allCases.firstIndex(of: type)! + 1))")
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
            .help("Zrób \(viewModel.screenshotType.title.lowercased()) (Spacja)")
        }
    }

    #Preview {
        FloatingPanelView(editorViewModel: EditorViewModel())
            .padding()
    }

#endif
