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
            ZStack(alignment: .bottom) {
                HStack(spacing: 12) {
                    CaptureModeToggle(viewModel: viewModel)

                    Divider()
                        .frame(height: 34)
                        .opacity(0.35)

                    CaptureTypeSelector(viewModel: viewModel)
                    CaptureButton(viewModel: viewModel)

                    if viewModel.captureMode == .video && viewModel.videoRecordingState.isActive {
                        RecordingIndicator(viewModel: viewModel)
                    }

                    PanelControlButtons(viewModel: viewModel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
                }

                if viewModel.isDisplayPickerPresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.cancelDisplayPicker()
                        }
                        .zIndex(1)

                    DisplayPickerView(viewModel: viewModel)
                        .offset(y: -86)
                        .transition(.scale(scale: 0.94, anchor: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(minWidth: 450, minHeight: viewModel.isDisplayPickerPresented ? 248 : 88)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.easeInOut(duration: 0.18), value: viewModel.isDisplayPickerPresented)
            .onKeyPress(.space) {
                viewModel.performPrimaryCaptureAction()
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
            .onKeyPress(.escape) {
                if viewModel.isDisplayPickerPresented {
                    viewModel.cancelDisplayPicker()
                    return .handled
                }
                return .ignored
            }
        }
    }

    private struct DisplayPickerView: View {
        @ObservedObject var viewModel: FloatingPanelViewModel

        var body: some View {
            HStack(spacing: 10) {
                ForEach(viewModel.availableDisplays) { display in
                    Button {
                        viewModel.selectDisplay(display)
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(display.isMain ? Color.blue.opacity(0.32) : Color.primary.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(display.isMain ? Color.blue : Color.primary.opacity(0.22), lineWidth: display.isMain ? 1.4 : 0.9)
                                )
                                .aspectRatio(display.aspectRatio, contentMode: .fit)
                                .frame(width: displayTileWidth(for: display), height: 38)
                                .overlay(
                                    Text("\(display.index)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                )

                            VStack(spacing: 1) {
                                Text(display.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(display.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 96)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .help(display.subtitle)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("floatingPanel.displayPicker")
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
            }
        }

        private func displayTileWidth(for display: CaptureDisplay) -> CGFloat {
            max(44, min(76, 38 * display.aspectRatio))
        }
    }

    #Preview {
        FloatingPanelView(viewModel: FloatingPanelViewModel(editorViewModel: EditorViewModel()))
            .padding()
    }

#endif
