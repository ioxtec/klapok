//
//  AnnotationManager.swift
//  Klapok
//
//  Manages annotations on screenshots
//

import Foundation
import SwiftUI
import Combine

#if os(macOS)
import AppKit

final class AnnotationManager: ObservableObject {
    private struct AnnotationHistoryState: Equatable {
        var annotations: [Annotation]
        var selectedAnnotationId: UUID?
        var editedImage: NSImage?
    }

    // MARK: - Published Properties
    
    @Published var annotations: [Annotation] = []
    @Published var editedImage: NSImage?
    @Published var selectedAnnotationId: UUID?
    @Published var currentTool: DrawingTool = .none
    @Published private var undoStack: [AnnotationHistoryState] = []
    @Published private var redoStack: [AnnotationHistoryState] = []
    
    // Drawing state
    @Published var isDrawing: Bool = false
    @Published var currentDraft: Annotation?
    
    // Text editing state
    @Published var editingTextAnnotationId: UUID?
    @Published var isEditingText: Bool = false
    
    // Style settings
    @Published var defaultColor: Color = .red
    @Published var defaultStrokeWidth: CGFloat = 3
    @Published var defaultFontSize: CGFloat = 18
    @Published var defaultFontWeight: FontWeight = .semibold
    @Published var defaultFillOpacity: Double = 0.3

    private let maximumHistoryDepth = 50
    private var isRestoringHistory = false
    
    // MARK: - Computed Properties
    
    var selectedAnnotation: Annotation? {
        guard let id = selectedAnnotationId else { return nil }
        return annotations.first(where: { $0.id == id })
    }
    
    var hasAnnotations: Bool {
        return !annotations.isEmpty
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // MARK: - Public Methods
    
    // MARK: Tool Selection
    
    func selectTool(_ tool: DrawingTool) {
        currentTool = tool
        // Deselect any annotation when changing tools
        if tool != .select {
            selectedAnnotationId = nil
        }
    }
    
    // MARK: Annotation Management
    
    func addAnnotation(_ annotation: Annotation, recordHistory: Bool = true) {
        recordUndoSnapshotIfNeeded(recordHistory)
        annotations.append(annotation)
    }
    
    func updateAnnotation(_ annotation: Annotation, recordHistory: Bool = true) {
        if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
            recordUndoSnapshotIfNeeded(recordHistory)
            var updated = annotation
            updated.modifiedAt = Date()
            annotations[index] = updated
        }
    }
    
    func deleteAnnotation(withId id: UUID, recordHistory: Bool = true) {
        recordUndoSnapshotIfNeeded(recordHistory)
        annotations.removeAll(where: { $0.id == id })
        if selectedAnnotationId == id {
            selectedAnnotationId = nil
        }
    }
    
    func deleteSelectedAnnotation() {
        if let id = selectedAnnotationId {
            deleteAnnotation(withId: id)
        }
    }
    
    func clearAllAnnotations() {
        recordUndoSnapshotIfNeeded(!annotations.isEmpty)
        annotations.removeAll()
        selectedAnnotationId = nil
        currentDraft = nil
        isDrawing = false
        editingTextAnnotationId = nil
        isEditingText = false
    }

    func resetForNewImage() {
        editedImage = nil
        annotations.removeAll()
        selectedAnnotationId = nil
        currentDraft = nil
        isDrawing = false
        editingTextAnnotationId = nil
        isEditingText = false
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func cropImage(_ normalizedRect: CGRect) {
        guard let image = editedImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let crop = QuickEditGeometry.normalizedCrop(normalizedRect)
        let rect = CGRect(x: crop.minX * Double(cgImage.width), y: crop.minY * Double(cgImage.height),
                          width: crop.width * Double(cgImage.width), height: crop.height * Double(cgImage.height)).integral
        guard let cropped = cgImage.cropping(to: rect) else { return }
        recordUndoSnapshotIfNeeded(true)
        editedImage = NSImage(cgImage: cropped, size: CGSize(width: cropped.width, height: cropped.height))
        annotations = annotations.map { annotation in
            var shifted = annotation
            shifted.startPoint.x -= rect.minX; shifted.startPoint.y -= rect.minY
            shifted.endPoint.x -= rect.minX; shifted.endPoint.y -= rect.minY
            shifted.pathPoints = annotation.pathPoints.map { CGPoint(x: $0.x - rect.minX, y: $0.y - rect.minY) }
            return shifted
        }
        selectedAnnotationId = nil
    }
    
    // MARK: Selection
    
    func selectAnnotation(at point: CGPoint) -> Bool {
        // Find annotation at point (reverse order to select top-most)
        for annotation in annotations.reversed() {
            if annotation.contains(point) {
                selectedAnnotationId = annotation.id
                return true
            }
        }
        selectedAnnotationId = nil
        return false
    }
    
    func deselectAnnotation() {
        selectedAnnotationId = nil
    }

    func selectAnnotation(withId id: UUID) {
        if annotations.contains(where: { $0.id == id }) {
            selectedAnnotationId = id
        }
    }
    
    // MARK: Drawing
    
    func startDrawing(at point: CGPoint) {
        guard let type = currentTool.annotationType else { return }
        
        isDrawing = true
        
        if type == .freeDraw {
            currentDraft = Annotation(
                type: type,
                startPoint: point,
                endPoint: point,
                color: ColorData(color: defaultColor),
                strokeWidth: defaultStrokeWidth,
                pathPoints: [point] // Start with first point
            )
        } else {
            currentDraft = Annotation(
                type: type,
                startPoint: point,
                endPoint: point,
                text: type == .text ? "Text" : nil,
                fontSize: defaultFontSize,
                fontWeight: defaultFontWeight,
                color: ColorData(color: defaultColor),
                strokeWidth: defaultStrokeWidth,
                fillOpacity: defaultFillOpacity
            )
        }
    }
    
    func updateDrawing(to point: CGPoint) {
        guard isDrawing, var draft = currentDraft else { return }
        
        if draft.type == .freeDraw {
            // Add point to path
            draft.pathPoints.append(point)
            draft.endPoint = point // Update bounds
        } else {
            draft.endPoint = point
        }
        
        currentDraft = draft
    }
    
    func finishDrawing() {
        guard isDrawing, let draft = currentDraft else { return }
        
        // Only add if the annotation has some size
        let minSize: CGFloat = 5
        let hasSize = abs(draft.endPoint.x - draft.startPoint.x) > minSize ||
                      abs(draft.endPoint.y - draft.startPoint.y) > minSize
        let hasFreeDrawPath = draft.type == .freeDraw && draft.pathPoints.count > 1
        
        if hasSize || hasFreeDrawPath || draft.type == .text {
            addAnnotation(draft)
            selectedAnnotationId = draft.id

            if draft.type != .text {
                currentTool = .select
            }
        }
        
        isDrawing = false
        currentDraft = nil
    }
    
    func cancelDrawing() {
        isDrawing = false
        currentDraft = nil
    }
    
    // MARK: Annotation Modification
    
    func moveSelectedAnnotation(by delta: CGSize, recordHistory: Bool = true) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        recordUndoSnapshotIfNeeded(recordHistory)
        var annotation = annotations[index]
        annotation.startPoint.x += delta.width
        annotation.startPoint.y += delta.height
        annotation.endPoint.x += delta.width
        annotation.endPoint.y += delta.height
        if annotation.type == .freeDraw {
            annotation.pathPoints = annotation.pathPoints.map {
                CGPoint(x: $0.x + delta.width, y: $0.y + delta.height)
            }
        }
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    // Resize selected annotation using corner handle and delta movement
    func resizeSelectedAnnotation(by delta: CGSize, handle: ResizeHandle) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        let originalHeight = annotation.endPoint.y - annotation.startPoint.y
        
        switch handle {
        case .topLeft:
            annotation.startPoint.x += delta.width
            annotation.startPoint.y += delta.height
        case .topRight:
            annotation.endPoint.x += delta.width
            annotation.startPoint.y += delta.height
        case .bottomLeft:
            annotation.startPoint.x += delta.width
            annotation.endPoint.y += delta.height
        case .bottomRight:
            annotation.endPoint.x += delta.width
            annotation.endPoint.y += delta.height
        case .top:
            annotation.startPoint.y += delta.height
        case .bottom:
            annotation.endPoint.y += delta.height
        case .left:
            annotation.startPoint.x += delta.width
        case .right:
            annotation.endPoint.x += delta.width
        }
        
        // Normalize so startPoint is top-left and endPoint is bottom-right-like for bounds consistency
        let minX = min(annotation.startPoint.x, annotation.endPoint.x)
        let maxX = max(annotation.startPoint.x, annotation.endPoint.x)
        let minY = min(annotation.startPoint.y, annotation.endPoint.y)
        let maxY = max(annotation.startPoint.y, annotation.endPoint.y)
        annotation.startPoint = CGPoint(x: minX, y: minY)
        annotation.endPoint = CGPoint(x: maxX, y: maxY)
        
        // For text, scale font size proportionally to height change (if meaningful)
        if annotation.type == .text {
            let newHeight = max(1, annotation.endPoint.y - annotation.startPoint.y)
            let oldHeight = max(1, abs(originalHeight))
            let scaleFactor = CGFloat(newHeight) / CGFloat(oldHeight)
            annotation.fontSize = max(6, annotation.fontSize * scaleFactor)
        }
        
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    func updateSelectedAnnotationText(_ text: String, recordHistory: Bool = true) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        guard annotations[index].text != text else { return }
        recordUndoSnapshotIfNeeded(recordHistory)
        var annotation = annotations[index]
        annotation.text = text
        fitTextAnnotation(&annotation)
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    func updateSelectedAnnotationColor(_ color: Color) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.color = ColorData(color: color)
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    func updateSelectedAnnotationStrokeWidth(_ width: CGFloat) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        guard annotations[index].strokeWidth != width else { return }
        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.strokeWidth = width
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    func updateSelectedAnnotationFontSize(_ size: CGFloat) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        guard annotations[index].fontSize != size else { return }
        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.fontSize = size
        fitTextAnnotation(&annotation)
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }

    func updateSelectedAnnotationFontWeight(_ weight: FontWeight) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        guard annotations[index].fontWeight != weight else { return }
        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.fontWeight = weight
        fitTextAnnotation(&annotation)
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }

    func updateSelectedAnnotationFillOpacity(_ opacity: Double) {
        guard let id = selectedAnnotationId,
              let index = annotations.firstIndex(where: { $0.id == id }) else { return }

        guard annotations[index].fillOpacity != opacity else { return }
        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.fillOpacity = opacity
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    // Update size (endPoint) using provided size, anchoring at startPoint (top-left)
    func updateAnnotationSize(annotationId: UUID, to size: CGSize) {
        guard let index = annotations.firstIndex(where: { $0.id == annotationId }) else { return }
        recordUndoSnapshotIfNeeded(true)
        var annotation = annotations[index]
        annotation.endPoint = CGPoint(x: annotation.startPoint.x + size.width,
                                      y: annotation.startPoint.y + size.height)
        annotation.modifiedAt = Date()
        annotations[index] = annotation
    }
    
    // MARK: Text Editing
    
    func startEditingText(annotationId: UUID) {
        editingTextAnnotationId = annotationId
        isEditingText = true
        selectedAnnotationId = annotationId
    }
    
    func finishEditingText() {
        editingTextAnnotationId = nil
        isEditingText = false
    }
    
    func createTextAnnotation(at point: CGPoint) {
        var annotation = Annotation(
            type: .text,
            startPoint: point, // This will be the top-left corner of the text field
            endPoint: CGPoint(x: point.x + 200, y: point.y + 30), // Fixed size text box
            text: "Text",
            fontSize: defaultFontSize,
            fontWeight: defaultFontWeight,
            color: ColorData(color: defaultColor),
            strokeWidth: defaultStrokeWidth,
            fillOpacity: defaultFillOpacity
        )
        fitTextAnnotation(&annotation)

        addAnnotation(annotation)
        startEditingText(annotationId: annotation.id)
    }

    private func fitTextAnnotation(_ annotation: inout Annotation) {
        guard annotation.type == .text else { return }

        let text = annotation.text?.isEmpty == false ? annotation.text ?? "" : "Text"
        let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: annotation.fontWeight.nsWeight)
        let measuredSize = (text as NSString).size(withAttributes: [.font: font])
        let width = max(112, ceil(measuredSize.width) + 64)
        let height = max(36, ceil(measuredSize.height) + 18)

        annotation.endPoint = CGPoint(
            x: annotation.startPoint.x + width,
            y: annotation.startPoint.y + height
        )
    }
    
    // MARK: Export
    
    func exportAnnotations() -> Data? {
        return try? JSONEncoder().encode(annotations)
    }
    
    func importAnnotations(from data: Data) {
        if let imported = try? JSONDecoder().decode([Annotation].self, from: data) {
            recordUndoSnapshotIfNeeded(annotations != imported)
            annotations = imported
        }
    }

    // MARK: - History

    func recordUndoSnapshot() {
        recordUndoSnapshotIfNeeded(true)
    }

    func undo() {
        guard let previousState = undoStack.popLast() else { return }

        let currentState = historyState
        isRestoringHistory = true
        redoStack.append(currentState)
        annotations = previousState.annotations
        editedImage = previousState.editedImage
        selectedAnnotationId = previousState.selectedAnnotationId
        currentDraft = nil
        isDrawing = false
        editingTextAnnotationId = nil
        isEditingText = false
        isRestoringHistory = false
    }

    func redo() {
        guard let nextState = redoStack.popLast() else { return }

        let currentState = historyState
        isRestoringHistory = true
        undoStack.append(currentState)
        annotations = nextState.annotations
        editedImage = nextState.editedImage
        selectedAnnotationId = nextState.selectedAnnotationId
        currentDraft = nil
        isDrawing = false
        editingTextAnnotationId = nil
        isEditingText = false
        isRestoringHistory = false
    }

    private var historyState: AnnotationHistoryState {
        AnnotationHistoryState(
            annotations: annotations,
            selectedAnnotationId: selectedAnnotationId,
            editedImage: editedImage
        )
    }

    private func recordUndoSnapshotIfNeeded(_ shouldRecord: Bool) {
        guard shouldRecord, !isRestoringHistory else { return }

        let state = historyState
        guard undoStack.last != state else { return }

        undoStack.append(state)
        if undoStack.count > maximumHistoryDepth {
            undoStack.removeFirst(undoStack.count - maximumHistoryDepth)
        }
        redoStack.removeAll()
    }
}

#endif
