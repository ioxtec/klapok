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

                // Selection rectangle
                if isDragging || !selectionRect.isEmpty {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .background(Color.clear)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                        updateSelectionRect()
                    }
                    .onEnded { _ in
                        isDragging = false
                        if selectionRect.width > 10 && selectionRect.height > 10 {
                            Logger.s("AreaSelectionView: Selection completed: \(selectionRect)")

                            // Update current selection binding
                            let nsRect = NSRect(
                                x: selectionRect.minX,
                                y: selectionRect.minY,
                                width: selectionRect.width,
                                height: selectionRect.height
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
                    let nsRect = NSRect(
                        x: selectionRect.minX,
                        y: selectionRect.minY,
                        width: selectionRect.width,
                        height: selectionRect.height
                    )
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

#endif
