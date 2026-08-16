//
//  AreaSelectionOverlay.swift
//  Klapok
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

    private enum SelectionHoverTarget {
        case miniPanel
        case coordinateEditor
        case resize(handle: SelectionResizeHandle)
        case move
        case create
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

    @MainActor
    final class AreaSelectionViewState: ObservableObject {
        @Published var startPoint: CGPoint = .zero
        @Published var currentPoint: CGPoint = .zero
        @Published var selectionRect: CGRect = .zero
        @Published var moveAnchorRect: CGRect = .zero
        @Published var moveStartPoint: CGPoint = .zero
        @Published var mode: SelectionMode = .idle
        @Published var isEditingSelection = false
        @Published var draftX = ""
        @Published var draftY = ""
        @Published var draftWidth = ""
        @Published var draftHeight = ""
    }

    // MARK: - Area Selection View

    struct AreaSelectionView: View {
        let screenID: CGDirectDisplayID
        let screenFrame: CGRect
        let onSelection: (NSRect?) -> Void
        @ObservedObject var coordinator: AreaSelectionCoordinator
        @StateObject private var viewState = AreaSelectionViewState()
        
        // MARK: - Computed Properties
        
        private var instructionText: String {
            selectionRect.isEmpty 
                ? "Drag to select area"
                : "Press Enter to confirm or ESC to cancel"
        }
        
        private var screenBounds: CGRect {
            CGRect(origin: .zero, size: screenFrame.size)
        }

        private var startPoint: CGPoint {
            get { viewState.startPoint }
            nonmutating set { viewState.startPoint = newValue }
        }

        private var currentPoint: CGPoint {
            get { viewState.currentPoint }
            nonmutating set { viewState.currentPoint = newValue }
        }

        private var selectionRect: CGRect {
            get { viewState.selectionRect }
            nonmutating set { viewState.selectionRect = newValue }
        }

        private var moveAnchorRect: CGRect {
            get { viewState.moveAnchorRect }
            nonmutating set { viewState.moveAnchorRect = newValue }
        }

        private var moveStartPoint: CGPoint {
            get { viewState.moveStartPoint }
            nonmutating set { viewState.moveStartPoint = newValue }
        }

        private var mode: SelectionMode {
            get { viewState.mode }
            nonmutating set { viewState.mode = newValue }
        }

        private var isEditingSelection: Bool {
            get { viewState.isEditingSelection }
            nonmutating set { viewState.isEditingSelection = newValue }
        }

        private var draftX: String {
            get { viewState.draftX }
            nonmutating set { viewState.draftX = newValue }
        }

        private var draftY: String {
            get { viewState.draftY }
            nonmutating set { viewState.draftY = newValue }
        }

        private var draftWidth: String {
            get { viewState.draftWidth }
            nonmutating set { viewState.draftWidth = newValue }
        }

        private var draftHeight: String {
            get { viewState.draftHeight }
            nonmutating set { viewState.draftHeight = newValue }
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
                            x: Binding(get: { draftX }, set: { draftX = $0 }),
                            y: Binding(get: { draftY }, set: { draftY = $0 }),
                            width: Binding(get: { draftWidth }, set: { draftWidth = $0 }),
                            height: Binding(get: { draftHeight }, set: { draftHeight = $0 }),
                            onApply: applySelectionEdit,
                            onCancel: cancelSelectionEdit
                        )
                        .position(selectionEditorPosition)
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard !coordinator.isRecording else { return }

                switch phase {
                case .active(let location):
                    updateCursor(at: location)
                case .ended:
                    NSCursor.crosshair.set()
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
            .onAppear {
                restoreSelectionIfNeeded()
            }
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

        private func restoreSelectionIfNeeded() {
            guard coordinator.activeScreenID == screenID, !coordinator.currentSelection.isEmpty else {
                return
            }

            let restoredRect = constrainRectToScreen(
                convertFromScreenCoordinates(coordinator.currentSelection)
            )
            guard restoredRect.width > 10, restoredRect.height > 10 else { return }

            selectionRect = restoredRect
            mode = .idle
            updateSelectionDraft(from: restoredRect)
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
            switch hoverTarget(at: location) {
            case .miniPanel, .coordinateEditor:
                NSCursor.arrow.set()
            case .resize(let handle):
                cursorForHandle(handle).set()
            case .move:
                Self.moveCursor.set()
            case .create:
                NSCursor.crosshair.set()
            }
        }

        private func hoverTarget(at location: CGPoint) -> SelectionHoverTarget {
            if selectionRect.isEmpty {
                return .create
            }

            if selectionControlsFrame.contains(location) {
                return .miniPanel
            }

            if isEditingSelection, selectionEditorFrame.contains(location) {
                return .coordinateEditor
            }

            if let handle = getResizeHandle(at: location) {
                return .resize(handle: handle)
            }

            if selectionRect.contains(location) {
                return .move
            }

            return .create
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

        private func cursorForHandle(_ handle: SelectionResizeHandle) -> NSCursor {
            switch handle {
            case .topLeft, .bottomRight:
                return Self.diagonalResizeCursorNWSE
            case .topRight, .bottomLeft:
                return Self.diagonalResizeCursorNESW
            case .top, .bottom:
                return NSCursor.resizeUpDown
            case .left, .right:
                return NSCursor.resizeLeftRight
            }
        }

        private var selectionControlsFrame: CGRect {
            guard !selectionRect.isEmpty else { return .zero }

            let digits = max(
                coordinateDigitCount(selectionRect.minX),
                coordinateDigitCount(selectionRect.minY),
                coordinateDigitCount(selectionRect.width),
                coordinateDigitCount(selectionRect.height)
            )
            let text = "x:\(String(repeating: "8", count: digits)), y:\(String(repeating: "8", count: digits)), w:\(String(repeating: "8", count: digits)), h:\(String(repeating: "8", count: digits))"
            let textSize = (text as NSString).size(withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ])
            let buttonCount = 3
            let buttonWidth = CGFloat(buttonCount * 18)
            let spacingWidth = CGFloat(buttonCount * 8)
            let width = textSize.width + buttonWidth + spacingWidth + 16
            let height: CGFloat = 28
            let center = CGPoint(x: selectionRect.midX, y: max(selectionRect.minY - 15, 15))

            return CGRect(
                x: center.x - (width / 2),
                y: center.y - (height / 2),
                width: width,
                height: height
            ).insetBy(dx: -6, dy: -4)
        }

        private var selectionEditorFrame: CGRect {
            guard isEditingSelection else { return .zero }

            let fieldWidth: CGFloat = 48
            let fieldStackWidth: CGFloat = 4 + 8 + fieldWidth
            let fieldsWidth = fieldStackWidth * 4
            let buttonsWidth: CGFloat = 20 + 8 + 20
            let width = fieldsWidth + buttonsWidth + 20
            let height: CGFloat = 38
            let center = selectionEditorPosition

            return CGRect(
                x: center.x - (width / 2),
                y: center.y - (height / 2),
                width: width,
                height: height
            ).insetBy(dx: -6, dy: -4)
        }

        private func coordinateDigitCount(_ value: CGFloat) -> Int {
            max(1, String(Int(abs(value).rounded())).count)
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

        private func convertFromScreenCoordinates(_ rect: CGRect) -> CGRect {
            let screenHeight = screenFrame.height

            return CGRect(
                x: rect.minX - screenFrame.minX,
                y: screenHeight - (rect.minY - screenFrame.minY) - rect.height,
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

        private static let diagonalResizeCursorNWSE = makeSymbolCursor(
            systemName: "arrow.up.left.and.arrow.down.right",
            fallback: .resizeUpDown
        )
        private static let diagonalResizeCursorNESW = makeSymbolCursor(
            systemName: "arrow.down.left.and.arrow.up.right",
            fallback: .resizeLeftRight
        )
        private static let moveCursor = makeSymbolCursor(
            systemName: "arrow.up.and.down.and.arrow.left.and.right",
            fallback: .openHand
        )

        private static func makeSymbolCursor(systemName: String, fallback: NSCursor) -> NSCursor {
            let configuration = NSImage.SymbolConfiguration(
                pointSize: 18,
                weight: .bold,
                scale: .medium
            )
            let canvasSize = CGSize(width: 24, height: 24)

            guard
                let baseSymbol = NSImage(
                    systemSymbolName: systemName,
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(configuration)
            else {
                return fallback
            }

            let outlinedImage = NSImage(size: canvasSize)
            outlinedImage.lockFocus()

            let drawRect = CGRect(
                x: (canvasSize.width - baseSymbol.size.width) / 2,
                y: (canvasSize.height - baseSymbol.size.height) / 2,
                width: baseSymbol.size.width,
                height: baseSymbol.size.height
            )
            let outlineOffsets = [
                CGPoint(x: -1, y: -1), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: -1),
                CGPoint(x: -1, y: 0),                           CGPoint(x: 1, y: 0),
                CGPoint(x: -1, y: 1),  CGPoint(x: 0, y: 1),  CGPoint(x: 1, y: 1),
            ]

            outlineOffsets.forEach { offset in
                renderSymbol(
                    baseSymbol,
                    color: .white,
                    in: drawRect.offsetBy(dx: offset.x, dy: offset.y)
                )
            }

            renderSymbol(baseSymbol, color: .black, in: drawRect)
            outlinedImage.unlockFocus()

            return NSCursor(
                image: outlinedImage,
                hotSpot: NSPoint(x: outlinedImage.size.width / 2, y: outlinedImage.size.height / 2)
            )
        }

        private static func renderSymbol(_ symbol: NSImage, color: NSColor, in rect: CGRect) {
            let tinted = NSImage(size: rect.size)
            tinted.lockFocus()
            symbol.draw(in: CGRect(origin: .zero, size: rect.size))
            color.set()
            CGRect(origin: .zero, size: rect.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.draw(in: rect)
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
        @StateObject private var settings = AppSettings.shared
        
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

                    Button {
                        settings.areaSelectionLockEnabled.toggle()
                    } label: {
                        Image(systemName: settings.areaSelectionLockEnabled ? "lock.fill" : "lock.open")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remember selected area")
                    .accessibilityIdentifier("areaSelection.lock")
                    .accessibilityValue(settings.areaSelectionLockEnabled ? "locked" : "unlocked")
                    .help(
                        settings.areaSelectionLockEnabled
                            ? "Reuse the last selected area the next time area capture opens"
                            : "Remember and reuse the last selected area"
                    )
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

        var body: some View {
            HStack(spacing: 8) {
                coordinateField("x", text: $x)
                coordinateField("y", text: $y)
                coordinateField("w", text: $width)
                coordinateField("h", text: $height)

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
        }

        private func coordinateField(
            _ label: String,
            text: Binding<String>
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

#endif
