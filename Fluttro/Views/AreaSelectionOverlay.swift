//
//  AreaSelectionOverlay.swift
//  Fluttro
//
//  Advanced area selection overlay with resize handles and drag support
//

import SwiftUI

#if os(macOS)
    import AppKit

    // MARK: - Selection Mode Enum

    enum SelectionMode {
        case creating
        case resizing(handle: ResizeHandle)
        case moving
        case idle
    }

    // Uses global ResizeHandle from Core/Models/AnnotationModels.swift

    // MARK: - Area Selection View

    struct AreaSelectionView: View {
        let backgroundImage: NSImage
        let onSelection: (NSRect?) -> Void
        @Binding var currentSelection: NSRect
        @Binding var isRecording: Bool

        @State private var startPoint: CGPoint = .zero
        @State private var currentPoint: CGPoint = .zero
        @State private var mousePosition: CGPoint = .zero
        @State private var selectionRect: CGRect = .zero
        @State private var mode: SelectionMode = .idle
        @State private var dragOffset: CGPoint = .zero
        
        // MARK: - Computed Properties
        
        private var instructionText: String {
            selectionRect.isEmpty 
                ? "Drag to select area"
                : "Press Enter to confirm or ESC to cancel"
        }
        
        private var screenBounds: CGRect {
            guard let screen = NSScreen.main else { return .zero }
            return CGRect(origin: .zero, size: screen.frame.size)
        }

        var body: some View {
            ZStack {
                // Semi-transparent background with cut-out selection area
                if !selectionRect.isEmpty {
                    // Create a darker overlay with a transparent cutout
                    ZStack {
                        // Dark overlay covering everything
                        Color.black.opacity(0.6)
                            .ignoresSafeArea(.all)
                        
                        // Clear rectangle in the selection area (creates the "hole")
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: selectionRect.width, height: selectionRect.height)
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                } else {
                    // When no selection, show full semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea(.all)
                }

                // Instructions
                VStack {
                    Text(instructionText)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 50)

                // Mouse position indicator
                MousePositionIndicator(position: mousePosition)

                // Selection rectangle with dashed border (hidden during recording)
                if !selectionRect.isEmpty && !isRecording {
                    SelectionRectangleView(
                        rect: selectionRect,
                        mousePosition: mousePosition,
                        onModeChange: { newMode in
                            mode = newMode
                        },
                        onRectChange: { newRect in
                            selectionRect = newRect
                        }
                    )
                }

                // Selection dimensions
                if !selectionRect.isEmpty {
                    SelectionDimensionsView(rect: selectionRect)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if !isRecording {
                    switch phase {
                    case .active(let location):
                        mousePosition = location
                        updateCursor(at: location)
                    case .ended:
                        break
                    }
                }
            }
            .gesture(isRecording ? nil : mainDragGesture)
            .onKeyPress(.escape) {
                onSelection(nil)
                return .handled
            }
            .onKeyPress(.return) {
                if !selectionRect.isEmpty {
                    let nsRect = convertToScreenCoordinates(selectionRect)
                    onSelection(nsRect)
                }
                return .handled
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        // MARK: - Gesture Handling

        private var mainDragGesture: some Gesture {
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        }

        private func handleDragChanged(_ value: DragGesture.Value) {
            // On first drag, determine what we're doing based on start location
            if case .idle = mode {
                let startLocation = value.startLocation

                if selectionRect.isEmpty {
                    // No selection - start creating new one
                    startPoint = startLocation
                    mode = .creating
                } else {
                    // Check what user clicked on
                    if let handle = getResizeHandle(at: startLocation) {
                        mode = .resizing(handle: handle)
                        startPoint = startLocation
                    } else if selectionRect.contains(startLocation) {
                        mode = .moving
                        startPoint = startLocation
                    } else {
                        // Clicked outside - start new selection
                        selectionRect = .zero
                        startPoint = startLocation
                        mode = .creating
                    }
                }
            }

            // Handle the drag based on current mode
            switch mode {
            case .creating:
                currentPoint = value.location
                updateSelectionRect()

            case .moving:
                let deltaX = value.location.x - startPoint.x
                let deltaY = value.location.y - startPoint.y
                let proposedRect = CGRect(
                    x: selectionRect.minX + deltaX,
                    y: selectionRect.minY + deltaY,
                    width: selectionRect.width,
                    height: selectionRect.height
                )
                // Constrain the rectangle to screen bounds
                let constrainedRect = constrainRectToScreen(proposedRect)
                selectionRect = constrainedRect
                // Update currentSelection immediately during move
                currentSelection = convertToScreenCoordinates(constrainedRect)
                startPoint = value.location  // Update for next delta calculation

            case .resizing(let handle):
                resizeSelection(handle: handle, to: value.location)
                // Update currentSelection immediately during resize
                currentSelection = convertToScreenCoordinates(selectionRect)

            case .idle:
                break
            }
        }

        private func handleDragEnded(_ value: DragGesture.Value) {
            if case .creating = mode {
                if selectionRect.width > 10 && selectionRect.height > 10 {
                    mode = .idle
                    // Update currentSelection with final coordinates
                    currentSelection = convertToScreenCoordinates(selectionRect)
                } else {
                    selectionRect = .zero
                    mode = .idle
                }
            } else {
                // For moving and resizing, ensure final coordinates are set
                if !selectionRect.isEmpty {
                    currentSelection = convertToScreenCoordinates(selectionRect)
                }
                mode = .idle
            }
        }

        private func updateSelectionRect() {
            let minX = min(startPoint.x, currentPoint.x)
            let minY = min(startPoint.y, currentPoint.y)
            let maxX = max(startPoint.x, currentPoint.x)
            let maxY = max(startPoint.y, currentPoint.y)

            let proposedRect = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )

            // Constrain to screen bounds
            selectionRect = constrainRectToScreen(proposedRect)

            // Update currentSelection during creation as well
            if selectionRect.width > 0 && selectionRect.height > 0 {
                currentSelection = convertToScreenCoordinates(selectionRect)
            }
        }

        private func resizeSelection(handle: ResizeHandle, to point: CGPoint) {
            let newRect = calculateResizedRect(handle: handle, to: point)
            
            // Ensure minimum size and constrain to screen bounds
            if newRect.width > 10 && newRect.height > 10 {
                selectionRect = constrainRectToScreen(newRect)
            }
        }
        
        private func calculateResizedRect(handle: ResizeHandle, to point: CGPoint) -> CGRect {
            let rect = selectionRect
            
            switch handle {
            case .topLeft:
                return CGRect(
                    x: point.x,
                    y: point.y,
                    width: rect.maxX - point.x,
                    height: rect.maxY - point.y
                )
            case .topRight:
                return CGRect(
                    x: rect.minX,
                    y: point.y,
                    width: point.x - rect.minX,
                    height: rect.maxY - point.y
                )
            case .bottomLeft:
                return CGRect(
                    x: point.x,
                    y: rect.minY,
                    width: rect.maxX - point.x,
                    height: point.y - rect.minY
                )
            case .bottomRight:
                return CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: point.x - rect.minX,
                    height: point.y - rect.minY
                )
            case .top:
                return CGRect(
                    x: rect.minX,
                    y: point.y,
                    width: rect.width,
                    height: rect.maxY - point.y
                )
            case .bottom:
                return CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: point.y - rect.minY
                )
            case .left:
                return CGRect(
                    x: point.x,
                    y: rect.minY,
                    width: rect.maxX - point.x,
                    height: rect.height
                )
            case .right:
                return CGRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: point.x - rect.minX,
                    height: rect.height
                )
            }
        }

        private func updateCursor(at location: CGPoint) {
            if selectionRect.isEmpty {
                NSCursor.crosshair.set()
                return
            }

            let handle = getResizeHandle(at: location)

            if let handle = handle {
                setCursorForHandle(handle)
            } else if selectionRect.contains(location) {
                NSCursor.openHand.set()
            } else {
                NSCursor.crosshair.set()
            }
        }

        private func createSimpleDiagonalCursor(isNWSE: Bool) {
            // Create custom diagonal resize cursor using Core Graphics
            let size = CGSize(width: 16, height: 16)
            let image = NSImage(size: size)

            image.lockFocus()

            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                // Fallback to standard cursors
                if isNWSE {
                    NSCursor.resizeUpDown.set()
                } else {
                    NSCursor.resizeLeftRight.set()
                }
                return
            }

            // Clear background
            context.clear(CGRect(origin: .zero, size: size))

            // Set drawing properties
            context.setStrokeColor(NSColor.black.cgColor)
            context.setFillColor(NSColor.black.cgColor)
            context.setLineWidth(1.5)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            if isNWSE {
                // NW-SE diagonal (top-left ↔ bottom-right)
                // Main diagonal line
                context.move(to: CGPoint(x: 2, y: 14))
                context.addLine(to: CGPoint(x: 14, y: 2))
                context.strokePath()

                // Arrow in top-left corner (NW)
                context.move(to: CGPoint(x: 2, y: 14))
                context.addLine(to: CGPoint(x: 2, y: 10))
                context.addLine(to: CGPoint(x: 6, y: 14))
                context.addLine(to: CGPoint(x: 2, y: 14))
                context.fillPath()

                // Arrow in bottom-right corner (SE)
                context.move(to: CGPoint(x: 14, y: 2))
                context.addLine(to: CGPoint(x: 14, y: 6))
                context.addLine(to: CGPoint(x: 10, y: 2))
                context.addLine(to: CGPoint(x: 14, y: 2))
                context.fillPath()

            } else {
                // NE-SW diagonal (top-right ↔ bottom-left)
                // Main diagonal line
                context.move(to: CGPoint(x: 14, y: 14))
                context.addLine(to: CGPoint(x: 2, y: 2))
                context.strokePath()

                // Arrow in top-right corner (NE)
                context.move(to: CGPoint(x: 14, y: 14))
                context.addLine(to: CGPoint(x: 10, y: 14))
                context.addLine(to: CGPoint(x: 14, y: 10))
                context.addLine(to: CGPoint(x: 14, y: 14))
                context.fillPath()

                // Arrow in bottom-left corner (SW)
                context.move(to: CGPoint(x: 2, y: 2))
                context.addLine(to: CGPoint(x: 6, y: 2))
                context.addLine(to: CGPoint(x: 2, y: 6))
                context.addLine(to: CGPoint(x: 2, y: 2))
                context.fillPath()
            }

            image.unlockFocus()

            let cursor = NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
            cursor.set()
        }

        private func getResizeHandle(at point: CGPoint) -> ResizeHandle? {
            let handleSize: CGFloat = 24  // Increased for much easier clicking
            let rect = selectionRect

            // Corner handles - larger hit areas for easier targeting
            if CGRect(
                x: rect.minX - handleSize / 2, y: rect.minY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .topLeft
            }
            if CGRect(
                x: rect.maxX - handleSize / 2, y: rect.minY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .topRight
            }
            if CGRect(
                x: rect.minX - handleSize / 2, y: rect.maxY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .bottomLeft
            }
            if CGRect(
                x: rect.maxX - handleSize / 2, y: rect.maxY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .bottomRight
            }

            // Edge handles - larger hit areas
            if CGRect(
                x: rect.midX - handleSize / 2, y: rect.minY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .top
            }
            if CGRect(
                x: rect.midX - handleSize / 2, y: rect.maxY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .bottom
            }
            if CGRect(
                x: rect.minX - handleSize / 2, y: rect.midY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .left
            }
            if CGRect(
                x: rect.maxX - handleSize / 2, y: rect.midY - handleSize / 2, width: handleSize,
                height: handleSize
            ).contains(point) {
                return .right
            }

            return nil
        }

        private func setCursorForHandle(_ handle: ResizeHandle) {
            let cursor = cursorForHandle(handle)
            cursor.set()
        }
        
        private func cursorForHandle(_ handle: ResizeHandle) -> NSCursor {
            switch handle {
            case .topLeft, .bottomRight:
                if #available(macOS 10.13, *) {
                    return NSCursor.resizeUpDown
                } else {
                    return NSCursor.arrow
                }
            case .topRight, .bottomLeft:
                if #available(macOS 10.13, *) {
                    return NSCursor.resizeLeftRight
                } else {
                    return NSCursor.arrow
                }
            case .top, .bottom:
                return NSCursor.resizeUpDown
            case .left, .right:
                return NSCursor.resizeLeftRight
            }
        }

        private func createDiagonalCursor(angle: CGFloat) {
            // Create a simple diagonal resize cursor using Core Graphics
            let size = CGSize(width: 16, height: 16)
            let image = NSImage(size: size)

            image.lockFocus()

            // Set up the graphics context
            guard let context = NSGraphicsContext.current?.cgContext else {
                NSCursor.arrow.set()
                image.unlockFocus()
                return
            }

            // Clear the background
            context.clear(CGRect(origin: .zero, size: size))

            // Set line properties
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.5)
            context.setLineCap(.round)

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let length: CGFloat = 6

            if angle == 0 {  // NW-SE diagonal
                // Draw NW-SE arrow
                context.move(to: CGPoint(x: center.x - length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x + length, y: center.y + length))

                // Arrow heads
                context.move(to: CGPoint(x: center.x - length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x - length + 3, y: center.y - length))
                context.move(to: CGPoint(x: center.x - length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x - length, y: center.y - length + 3))

                context.move(to: CGPoint(x: center.x + length, y: center.y + length))
                context.addLine(to: CGPoint(x: center.x + length - 3, y: center.y + length))
                context.move(to: CGPoint(x: center.x + length, y: center.y + length))
                context.addLine(to: CGPoint(x: center.x + length, y: center.y + length - 3))
            } else {  // NE-SW diagonal
                // Draw NE-SW arrow
                context.move(to: CGPoint(x: center.x + length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x - length, y: center.y + length))

                // Arrow heads
                context.move(to: CGPoint(x: center.x + length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x + length - 3, y: center.y - length))
                context.move(to: CGPoint(x: center.x + length, y: center.y - length))
                context.addLine(to: CGPoint(x: center.x + length, y: center.y - length + 3))

                context.move(to: CGPoint(x: center.x - length, y: center.y + length))
                context.addLine(to: CGPoint(x: center.x - length + 3, y: center.y + length))
                context.move(to: CGPoint(x: center.x - length, y: center.y + length))
                context.addLine(to: CGPoint(x: center.x - length, y: center.y + length - 3))
            }

            context.strokePath()
            image.unlockFocus()

            let cursor = NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
            cursor.set()
        }

        private func convertToScreenCoordinates(_ rect: CGRect) -> NSRect {
            guard let screen = NSScreen.main else { return NSRect.zero }

            let screenFrame = screen.frame
            let screenHeight = screenFrame.height

            return NSRect(
                x: screenFrame.minX + rect.minX,
                y: screenFrame.minY + (screenHeight - rect.minY - rect.height),
                width: rect.width,
                height: rect.height
            )
        }

        private func constrainRectToScreen(_ rect: CGRect) -> CGRect {
            let bounds = screenBounds
            var constrainedRect = rect

            // Ensure the rectangle doesn't go outside screen bounds
            constrainedRect.origin.x = max(bounds.minX, min(constrainedRect.origin.x, bounds.maxX - constrainedRect.width))
            constrainedRect.origin.y = max(bounds.minY, min(constrainedRect.origin.y, bounds.maxY - constrainedRect.height))

            // If the rectangle is larger than screen, resize it
            if constrainedRect.width > bounds.width {
                constrainedRect.size.width = bounds.width
                constrainedRect.origin.x = bounds.minX
            }
            if constrainedRect.height > bounds.height {
                constrainedRect.size.height = bounds.height
                constrainedRect.origin.y = bounds.minY
            }

            return constrainedRect
        }
    }

    // MARK: - Selection Rectangle View

    struct SelectionRectangleView: View {
        let rect: CGRect
        let mousePosition: CGPoint
        let onModeChange: (SelectionMode) -> Void
        let onRectChange: (CGRect) -> Void

        var body: some View {
            ZStack {
                // Dashed border rectangle
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundColor(.blue)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Resize handles - corners (visible)
                ResizeHandleView(position: CGPoint(x: rect.minX, y: rect.minY))
                ResizeHandleView(position: CGPoint(x: rect.maxX, y: rect.minY))
                ResizeHandleView(position: CGPoint(x: rect.minX, y: rect.maxY))
                ResizeHandleView(position: CGPoint(x: rect.maxX, y: rect.maxY))

                // Resize handles - edges (visible)
                ResizeHandleView(position: CGPoint(x: rect.midX, y: rect.minY))
                ResizeHandleView(position: CGPoint(x: rect.midX, y: rect.maxY))
                ResizeHandleView(position: CGPoint(x: rect.minX, y: rect.midY))
                ResizeHandleView(position: CGPoint(x: rect.maxX, y: rect.midY))

                // Invisible larger hit areas for easier targeting
                // Corner hit areas
                InvisibleHitArea(position: CGPoint(x: rect.minX, y: rect.minY))
                InvisibleHitArea(position: CGPoint(x: rect.maxX, y: rect.minY))
                InvisibleHitArea(position: CGPoint(x: rect.minX, y: rect.maxY))
                InvisibleHitArea(position: CGPoint(x: rect.maxX, y: rect.maxY))

                // Edge hit areas
                InvisibleHitArea(position: CGPoint(x: rect.midX, y: rect.minY))
                InvisibleHitArea(position: CGPoint(x: rect.midX, y: rect.maxY))
                InvisibleHitArea(position: CGPoint(x: rect.minX, y: rect.midY))
                InvisibleHitArea(position: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }

    // MARK: - Resize Handle View

    struct ResizeHandleView: View {
        let position: CGPoint

        var body: some View {
            Rectangle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .position(position)
        }
    }

    // MARK: - Invisible Hit Area for Easier Targeting

    struct InvisibleHitArea: View {
        let position: CGPoint

        var body: some View {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 24, height: 24)  // Large invisible hit area
                .position(position)
        }
    }
    
    // MARK: - Helper Components
    
    struct MousePositionIndicator: View {
        let position: CGPoint
        
        var body: some View {
            VStack {
                HStack {
                    Text("x:\(Int(position.x)), y:\(Int(position.y))")
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
        }
    }
    
    struct SelectionDimensionsView: View {
        let rect: CGRect
        
        var body: some View {
            Text("x:\(Int(rect.minX)), y:\(Int(rect.minY)), w:\(Int(rect.width)), h:\(Int(rect.height))")
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.8))
                .cornerRadius(4)
                .font(.system(size: 12, design: .monospaced))
                .position(
                    x: rect.midX,
                    y: max(rect.minY - 15, 15)
                )
        }
    }
    
    // MARK: - View Modifiers
    
    struct InstructionTextStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
        }
    }
    
    extension View {
        func instructionTextStyle() -> some View {
            modifier(InstructionTextStyle())
        }
    }

    #Preview {
        AreaSelectionView(
            backgroundImage: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
                ?? NSImage(),
            onSelection: { rect in
                print("Selected: \(String(describing: rect))")
            },
            currentSelection: .constant(.zero),
            isRecording: .constant(false)
        )
    }

#endif
