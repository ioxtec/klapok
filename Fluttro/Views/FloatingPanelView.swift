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
            ZStack {
                // Main controls - centered
                HStack(spacing: 20) {
                    CaptureModeToggle(viewModel: viewModel)
                    CaptureTypeSelector(viewModel: viewModel)
                    CaptureButton(viewModel: viewModel)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Overlay controls
                VStack(spacing: 0) {
                    // Top controls
                    HStack {
                        // Recording indicator (top-left)
                        if viewModel.captureMode == .video && viewModel.videoRecordingState == .recording {
                            RecordingIndicator(viewModel: viewModel)
                        }
                        
                        Spacer()
                        
                        // Panel controls (top-right)
                        PanelControlButtons(viewModel: viewModel)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                }
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
    }

    #Preview {
        FloatingPanelView(viewModel: FloatingPanelViewModel(editorViewModel: EditorViewModel()))
            .padding()
    }

#endif
