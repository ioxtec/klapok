//
//  AreaSelectionOverlay.swift
//  Fluttro
//
//  Advanced area selection overlay with resize handles and drag support
//

import SwiftUI

#if os(macOS)
    import AppKit

    // MARK: - Resize Handle (local to Area Selection overlay target)

    enum SelectionResizeHandle {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
        case top
        case bottom
        case left
        case right
    }

    // MARK: - Selection Mode Enum

    enum SelectionMode {
        case creating
        case resizing(handle: SelectionResizeHandle)
        case moving
        case idle
    }

    // MARK: - Shared Selection State

    final class AreaSelectionCoordinator: ObservableObject {
        @Published var activeScreenID: CGDirectDisplayID?
        @Published var currentSelection: NSRect = .zero
        @Published var isRecording = false

        func reset() {
            activeScreenID = nil
            currentSelection = .zero
            isRecording = false
        }
    }

    // MARK: - Area Selection View

    struct AreaSelectionView: View {
        let screenID: CGDirectDisplayID
        let screenFrame: CGRect
        let onSelection: (NSRect?) -> Void
        @ObservedObject var coordinator: AreaSelectionCoordinator

        @State private var startPoint: CGPoint = .zero
        @State private var currentPoint: CGPoint = .zero
        @State private var selectionRect: CGRect = .zero
        @State private var moveAnchorRect: CGRect = .zero
        @State private var moveStartPoint: CGPoint = .zero
        @State private var mode: SelectionMode = .idle
        @State private var dragOffset: CGPoint = .zero
        @State private var isEditingSelection = false
        @State private var draftX = ""
        @State private var draftY = ""
        @State private var draftWidth = ""
        @State private var draftHeight = ""
        
        // MARK: - Computed Properties
        
        private var instructionText: String {
            selectionRect.isEmpty 
                ? "Drag to select area"
                : "Press Enter to confirm or ESC to cancel"
        }
        
        private var screenBounds: CGRect {
            CGRect(origin: .zero, size: screenFrame.size)
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

                // Selection rectangle with dashed border (hidden during recording)
                if !selectionRect.isEmpty && !coordinator.isRecording {
                    SelectionRectangleView(
                        rect: selectionRect,
                        onModeChange: { newMode in
                            mode = newMode
                        },
                        onRectChange: { newRect in
                            selectionRect = newRect
                        }
                    )
                }

                // Selection controls
                if !selectionRect.isEmpty {
                    SelectionDimensionsView(
                        rect: selectionRect,
                        isEditing: isEditingSelection,
                        showActions: !coordinator.isRecording,
                        onCapture: captureSelection,
                        onEdit: startSelectionEdit
                    )

                    if isEditingSelection && !coordinator.isRecording {
                        SelectionCoordinateEditorView(
                            x: $draftX,
                            y: $draftY,
                            width: $draftWidth,
                            height: $draftHeight,
                            onApply: applySelectionEdit,
                            onCancel: cancelSelectionEdit
                        )
                        .position(selectionEditorPosition)
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                if !coordinator.isRecording && !isEditingSelection {
                    switch phase {
                    case .active(let location):
                        updateCursor(at: location)
                    case .ended:
                        break
                    }
                }
            }
            .gesture((coordinator.isRecording || isEditingSelection) ? nil : mainDragGesture)
            .onChange(of: coordinator.activeScreenID) { _, activeScreenID in
                guard activeScreenID != nil, activeScreenID != screenID else { return }
                clearLocalSelection()
            }
            .onKeyPress(.escape) {
                cancelSelection()
                return .handled
            }
            .onExitCommand(perform: cancelSelection)
            .onKeyPress(.return) {
                if isEditingSelection {
                    applySelectionEdit()
                    return .handled
                }
                if !selectionRect.isEmpty {
                    captureSelection()
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

        private var selectionEditorPosition: CGPoint {
            let x = min(max(selectionRect.midX, 150), max(screenBounds.width - 150, 150))

            if selectionRect.minY > 96 {
                return CGPoint(x: x, y: selectionRect.minY - 56)
            }

            let y = min(selectionRect.maxY + 56, max(screenBounds.height - 56, 56))
            return CGPoint(x: x, y: y)
        }

        private func handleDragChanged(_ value: DragGesture.Value) {
            // On first drag, determine what we're doing based on start location
            if case .idle = mode {
                activateCurrentScreen()
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
                        moveStartPoint = startLocation
                        moveAnchorRect = selectionRect
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
                let deltaX = value.location.x - moveStartPoint.x
                let deltaY = value.location.y - moveStartPoint.y
                let constrainedDelta = constrainedMoveDelta(x: deltaX, y: deltaY)
                let proposedRect = CGRect(
                    x: moveAnchorRect.minX + constrainedDelta.x,
                    y: moveAnchorRect.minY + constrainedDelta.y,
                    width: moveAnchorRect.width,
                    height: moveAnchorRect.height
                )
                // Constrain the rectangle to screen bounds
                let constrainedRect = constrainRectToScreen(proposedRect)
                selectionRect = constrainedRect
                // Update currentSelection immediately during move
                coordinator.currentSelection = convertToScreenCoordinates(constrainedRect)
                updateSelectionDraft(from: constrainedRect)

            case .resizing(let handle):
                resizeSelection(handle: handle, to: value.location)
                // Update currentSelection immediately during resize
                coordinator.currentSelection = convertToScreenCoordinates(selectionRect)

            case .idle:
                break
            }
        }

        private func handleDragEnded(_ value: DragGesture.Value) {
            if case .creating = mode {
                if selectionRect.width > 10 && selectionRect.height > 10 {
                    mode = .idle
                    // Update currentSelection with final coordinates
                    coordinator.currentSelection = convertToScreenCoordinates(selectionRect)
                    updateSelectionDraft(from: selectionRect)
                } else {
                    selectionRect = .zero
                    mode = .idle
                }
            } else {
                // For moving and resizing, ensure final coordinates are set
                if !selectionRect.isEmpty {
                    coordinator.currentSelection = convertToScreenCoordinates(selectionRect)
                    updateSelectionDraft(from: selectionRect)
                }
                mode = .idle
                moveAnchorRect = .zero
                moveStartPoint = .zero
            }
        }

        private func constrainedMoveDelta(x: CGFloat, y: CGFloat) -> CGPoint {
            guard NSEvent.modifierFlags.contains(.shift) else {
                return CGPoint(x: x, y: y)
            }

            if abs(x) >= abs(y) {
                return CGPoint(x: x, y: 0)
            }

            return CGPoint(x: 0, y: y)
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
                coordinator.currentSelection = convertToScreenCoordinates(selectionRect)
                updateSelectionDraft(from: selectionRect)
            }
        }

        private func activateCurrentScreen() {
            guard coordinator.activeScreenID != screenID else { return }

            coordinator.activeScreenID = screenID
            coordinator.currentSelection = .zero
        }

        private func clearLocalSelection() {
            selectionRect = .zero
            startPoint = .zero
            currentPoint = .zero
            moveAnchorRect = .zero
            moveStartPoint = .zero
            mode = .idle
            isEditingSelection = false
            updateSelectionDraft(from: .zero)
        }

        private func resizeSelection(handle: SelectionResizeHandle, to point: CGPoint) {
            let newRect = calculateResizedRect(handle: handle, to: point)
            
            // Ensure minimum size and constrain to screen bounds
            if newRect.width > 10 && newRect.height > 10 {
                selectionRect = constrainRectToScreen(newRect)
                updateSelectionDraft(from: selectionRect)
            }
        }
        
        private func calculateResizedRect(handle: SelectionResizeHandle, to point: CGPoint) -> CGRect {
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

        private func getResizeHandle(at point: CGPoint) -> SelectionResizeHandle? {
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

        private func setCursorForHandle(_ handle: SelectionResizeHandle) {
            let cursor = cursorForHandle(handle)
            cursor.set()
        }
        
        private func cursorForHandle(_ handle: SelectionResizeHandle) -> NSCursor {
            switch handle {
            case .topLeft, .bottomRight:
                return diagonalResizeCursor(isNWSE: true)
            case .topRight, .bottomLeft:
                return diagonalResizeCursor(isNWSE: false)
            case .top, .bottom:
                return NSCursor.resizeUpDown
            case .left, .right:
                return NSCursor.resizeLeftRight
            }
        }

        private func diagonalResizeCursor(isNWSE: Bool) -> NSCursor {
            let size = CGSize(width: 18, height: 18)
            let image = NSImage(size: size)

            image.lockFocus()
            guard let context = NSGraphicsContext.current?.cgContext else {
                image.unlockFocus()
                return NSCursor.arrow
            }

            context.clear(CGRect(origin: .zero, size: size))
            context.setLineCap(.round)
            context.setLineJoin(.round)

            let start = isNWSE ? CGPoint(x: 4, y: 4) : CGPoint(x: 14, y: 4)
            let end = isNWSE ? CGPoint(x: 14, y: 14) : CGPoint(x: 4, y: 14)

            drawDiagonalResizeCursorLine(from: start, to: end, in: context, color: .white, width: 4)
            drawDiagonalResizeCursorLine(from: start, to: end, in: context, color: .black, width: 2)

            image.unlockFocus()

            return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
        }

        private func drawDiagonalResizeCursorLine(
            from start: CGPoint,
            to end: CGPoint,
            in context: CGContext,
            color: NSColor,
            width: CGFloat
        ) {
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(width)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            drawArrowHead(tip: start, toward: CGPoint(x: start.x - end.x, y: start.y - end.y), in: context)
            drawArrowHead(tip: end, toward: CGPoint(x: end.x - start.x, y: end.y - start.y), in: context)
        }

        private func drawArrowHead(tip: CGPoint, toward direction: CGPoint, in context: CGContext) {
            let length = max(sqrt(direction.x * direction.x + direction.y * direction.y), 1)
            let unit = CGPoint(x: direction.x / length, y: direction.y / length)
            let perpendicular = CGPoint(x: -unit.y, y: unit.x)
            let base = CGPoint(x: tip.x - unit.x * 5, y: tip.y - unit.y * 5)

            context.beginPath()
            context.move(to: tip)
            context.addLine(to: CGPoint(x: base.x + perpendicular.x * 3, y: base.y + perpendicular.y * 3))
            context.addLine(to: CGPoint(x: base.x - perpendicular.x * 3, y: base.y - perpendicular.y * 3))
            context.closePath()
            context.fillPath()
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
            let screenHeight = screenFrame.height

            return NSRect(
                x: screenFrame.minX + rect.minX,
                y: screenFrame.minY + (screenHeight - rect.minY - rect.height),
                width: rect.width,
                height: rect.height
            )
        }

        private func captureSelection() {
            guard !selectionRect.isEmpty else { return }
            onSelection(convertToScreenCoordinates(selectionRect))
        }

        private func cancelSelection() {
            onSelection(nil)
        }

        private func startSelectionEdit() {
            updateSelectionDraft(from: selectionRect)
            isEditingSelection = true
        }

        private func cancelSelectionEdit() {
            isEditingSelection = false
            updateSelectionDraft(from: selectionRect)
        }

        private func applySelectionEdit() {
            guard
                let x = parseCoordinate(draftX),
                let y = parseCoordinate(draftY),
                let width = parseCoordinate(draftWidth),
                let height = parseCoordinate(draftHeight),
                width > 10,
                height > 10
            else {
                return
            }

            let proposedRect = CGRect(x: x, y: y, width: width, height: height)
            selectionRect = constrainRectToScreen(proposedRect)
            activateCurrentScreen()
            coordinator.currentSelection = convertToScreenCoordinates(selectionRect)
            updateSelectionDraft(from: selectionRect)
            isEditingSelection = false
        }

        private func updateSelectionDraft(from rect: CGRect) {
            guard !isEditingSelection else { return }

            draftX = formattedCoordinate(rect.minX)
            draftY = formattedCoordinate(rect.minY)
            draftWidth = formattedCoordinate(rect.width)
            draftHeight = formattedCoordinate(rect.height)
        }

        private func formattedCoordinate(_ value: CGFloat) -> String {
            String(Int(value.rounded()))
        }

        private func parseCoordinate(_ value: String) -> CGFloat? {
            let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            guard let doubleValue = Double(normalizedValue) else { return nil }
            return CGFloat(doubleValue)
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
    
    struct SelectionDimensionsView: View {
        let rect: CGRect
        let isEditing: Bool
        let showActions: Bool
        let onCapture: () -> Void
        let onEdit: () -> Void
        
        var body: some View {
            HStack(spacing: 8) {
                Text("x:\(Int(rect.minX)), y:\(Int(rect.minY)), w:\(Int(rect.width)), h:\(Int(rect.height))")
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)

                if showActions {
                    Button(action: onCapture) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Capture selected area")

                    Button(action: onEdit) {
                        Image(systemName: isEditing ? "pencil.circle.fill" : "pencil")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Edit selection coordinates")
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.85))
            .cornerRadius(4)
            .position(
                x: rect.midX,
                y: max(rect.minY - 15, 15)
            )
        }
    }

    struct SelectionCoordinateEditorView: View {
        @Binding var x: String
        @Binding var y: String
        @Binding var width: String
        @Binding var height: String

        let onApply: () -> Void
        let onCancel: () -> Void

        @FocusState private var focusedField: CoordinateField?

        private enum CoordinateField {
            case x
            case y
            case width
            case height
        }

        var body: some View {
            HStack(spacing: 8) {
                coordinateField("x", text: $x, field: .x)
                coordinateField("y", text: $y, field: .y)
                coordinateField("w", text: $width, field: .width)
                coordinateField("h", text: $height, field: .height)

                Button(action: onApply) {
                    Image(systemName: "checkmark")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Apply coordinates")

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.78))
            .cornerRadius(6)
            .onAppear {
                DispatchQueue.main.async {
                    focusedField = .x
                }
            }
        }

        private func coordinateField(
            _ label: String,
            text: Binding<String>,
            field: CoordinateField
        ) -> some View {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                TextField(label, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: field)
                    .onSubmit(onApply)
                    .frame(width: 48)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.14))
                    .cornerRadius(4)
            }
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
            screenID: NSScreen.main.map(ScreenPixelGeometry.displayID(for:)) ?? CGMainDisplayID(),
            screenFrame: NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900),
            onSelection: { rect in
                print("Selected: \(String(describing: rect))")
            },
            coordinator: AreaSelectionCoordinator()
        )
    }

#endif
