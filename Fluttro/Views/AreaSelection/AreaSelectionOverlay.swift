//
//  AreaSelectionOverlay.swift
//  Fluttro
//
//  Modern SwiftUI-based area selection overlay
//

import SwiftUI

#if os(macOS)
    import AppKit

    // MARK: - Area Selection View

    struct AreaSelectionView: View {
        let backgroundImage: NSImage
        let onSelection: (NSRect?) -> Void
        @Binding var currentSelection: NSRect

        @State private var startPoint: CGPoint = .zero
        @State private var currentPoint: CGPoint = .zero
        @State private var mousePosition: CGPoint = .zero
        @State private var isDragging = false
        @State private var selectionRect: CGRect = .zero

        var body: some View {
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea(.all)

                // Instructions
                VStack {
                    if selectionRect.isEmpty {
                        Text("Przeciągnij, aby wybrać obszar")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    } else {
                        Text("Naciśnij Enter aby potwierdzić lub ESC aby anulować")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.top, 50)

                // Mouse position indicator (top-left corner)
                VStack {
                    HStack {
                        Text("x:\(Int(mousePosition.x)), y:\(Int(mousePosition.y))")
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.leading, 10)

                // Selection rectangle
                if isDragging || !selectionRect.isEmpty {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.clear)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                }

                // Selection dimensions (positioned above selection rectangle)
                if isDragging || !selectionRect.isEmpty {
                    Text(
                        "x:\(Int(selectionRect.minX)), y:\(Int(selectionRect.minY)), w:\(Int(selectionRect.width)), h:\(Int(selectionRect.height))"
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(4)
                    .font(.system(size: 12, design: .monospaced))
                    .position(
                        x: selectionRect.midX,
                        y: max(selectionRect.minY - 15, 15)  // Above selection or at top if too close to edge
                    )
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mousePosition = location
                case .ended:
                    break
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                        mousePosition = value.location
                        updateSelectionRect()
                    }
                    .onEnded { _ in
                        isDragging = false
                        if selectionRect.width > 10 && selectionRect.height > 10 {
                            Logger.s("AreaSelectionView: Selection completed: \(selectionRect)")

                            // Convert local coordinates to screen coordinates
                            guard let screen = NSScreen.main else {
                                Logger.e("AreaSelectionView: No main screen found")
                                return
                            }

                            // Convert SwiftUI coordinates (top-left origin) to macOS screen coordinates (bottom-left origin)
                            let screenFrame = screen.frame
                            let screenHeight = screenFrame.height
                            let backingScaleFactor = screen.backingScaleFactor

                            // Overlay now covers the full screen including menu bar
                            // SwiftUI uses top-left origin, ScreenCaptureKit uses bottom-left origin
                            let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 0

                            // Since overlay covers full screen including menu bar,
                            // SwiftUI y=0 is at the top of menu bar, not top of visible screen
                            // We need to convert: SwiftUI coordinates -> Screen coordinates
                            let nsRect = NSRect(
                                x: screenFrame.minX + selectionRect.minX,
                                y: screenFrame.minY + (screenHeight - selectionRect.maxY),  // Direct conversion without menu bar offset
                                width: selectionRect.width,
                                height: selectionRect.height
                            )

                            Logger.d("AreaSelectionView: Local selection rect: \(selectionRect)")
                            Logger.d("AreaSelectionView: Screen frame: \(screenFrame)")
                            Logger.d("AreaSelectionView: Screen height: \(screenHeight)")
                            Logger.d("AreaSelectionView: Menu bar height: \(menuBarHeight)")
                            Logger.d(
                                "AreaSelectionView: Backing scale factor: \(backingScaleFactor)")
                            Logger.d("AreaSelectionView: Converted NSRect: \(nsRect)")
                            Logger.d(
                                "AreaSelectionView: Y calculation: \(screenFrame.minY) + (\(screenHeight) - \(selectionRect.maxY)) = \(screenFrame.minY + (screenHeight - selectionRect.maxY))"
                            )

                            currentSelection = nsRect
                        } else {
                            // Selection too small - clear
                            selectionRect = .zero
                        }
                    }
            )
            .onKeyPress(.escape) {
                onSelection(nil)
                return .handled
            }
            .onKeyPress(.return) {
                if !selectionRect.isEmpty {
                    // Convert SwiftUI coordinates (top-left origin) to macOS screen coordinates (bottom-left origin)
                    guard let screen = NSScreen.main else {
                        Logger.e("AreaSelectionView: No main screen found")
                        return .handled
                    }

                    let screenFrame = screen.frame
                    let screenHeight = screenFrame.height

                    let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 0

                    let nsRect = NSRect(
                        x: screenFrame.minX + selectionRect.minX,
                        y: screenFrame.minY + (screenHeight - selectionRect.maxY),  // Direct conversion without menu bar offset
                        width: selectionRect.width,
                        height: selectionRect.height
                    )

                    Logger.d(
                        "AreaSelectionView: Return key - Local selection rect: \(selectionRect)")
                    Logger.d("AreaSelectionView: Return key - Converted NSRect: \(nsRect)")

                    onSelection(nsRect)
                }
                return .handled
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private func updateSelectionRect() {
            let minX = min(startPoint.x, currentPoint.x)
            let minY = min(startPoint.y, currentPoint.y)
            let maxX = max(startPoint.x, currentPoint.x)
            let maxY = max(startPoint.y, currentPoint.y)

            selectionRect = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )
        }
    }

    #Preview {
        AreaSelectionView(
            backgroundImage: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                ?? NSImage(),
            onSelection: { rect in
                print("Selected: \(String(describing: rect))")
            },
            currentSelection: .constant(.zero)
        )
    }

#endif
