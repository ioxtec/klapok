//
//  DrawingCanvasView.swift
//  Klapok
//
//  Canvas view for drawing and displaying annotations
//

import SwiftUI

#if os(macOS)
import AppKit

@MainActor
private final class DrawingCanvasViewState: ObservableObject {
    @Published var lastDragLocation: CGPoint?
    @Published var activeDragAnnotationId: UUID?
    @Published var recordedDragUndo = false
}

struct DrawingCanvasView: View {
    @ObservedObject var annotationManager: AnnotationManager
    let canvasSize: CGSize
    let sourceImageSize: CGSize?
    @StateObject private var viewState = DrawingCanvasViewState()

    private var lastDragLocation: CGPoint? {
        get { viewState.lastDragLocation }
        nonmutating set { viewState.lastDragLocation = newValue }
    }

    private var activeDragAnnotationId: UUID? {
        get { viewState.activeDragAnnotationId }
        nonmutating set { viewState.activeDragAnnotationId = newValue }
    }

    private var recordedDragUndo: Bool {
        get { viewState.recordedDragUndo }
        nonmutating set { viewState.recordedDragUndo = newValue }
    }

    private var sourceSize: CGSize {
        sourceImageSize ?? canvasSize
    }

    private var scaleX: CGFloat {
        guard sourceSize.width > 0 else { return 1 }
        return canvasSize.width / sourceSize.width
    }

    private var scaleY: CGFloat {
        guard sourceSize.height > 0 else { return 1 }
        return canvasSize.height / sourceSize.height
    }

    private var displayScale: CGFloat {
        min(scaleX, scaleY)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Canvas for non-text annotations
            Canvas { context, size in
                // Draw all committed non-text annotations
                for annotation in annotationManager.annotations {
                    if annotation.type != .text {
                        drawAnnotation(annotationForDisplay(annotation), in: context, canvasSize: size)
                    }
                }
                
                // Draw current draft annotation being drawn (if not text)
                if let draft = annotationManager.currentDraft, draft.type != .text {
                    drawAnnotation(annotationForDisplay(draft), in: context, canvasSize: size, opacity: 0.7)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            
            // Editable text annotations as SwiftUI views
            ForEach(annotationManager.annotations.filter { $0.type == .text }) { annotation in
                EditableTextAnnotationView(
                    annotation: annotation,
                    annotationManager: annotationManager,
                    canvasSize: canvasSize,
                    sourceImageSize: sourceImageSize
                )
            }

            // Selection overlay: handles and delete button
            if let selectedId = annotationManager.selectedAnnotationId,
               let selected = annotationManager.annotations.first(where: { $0.id == selectedId }) {
                selectionOverlay(for: selected)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
    }
    
    private func drawAnnotation(_ annotation: Annotation, in context: GraphicsContext, canvasSize: CGSize, opacity: Double = 1.0) {
        let color = annotation.color.toColor()
        
        switch annotation.type {
        case .text:
            // Text is handled by SwiftUI views, skip in Canvas
            break
        case .arrow:
            drawArrowAnnotation(annotation, in: context, color: color, opacity: opacity)
        case .rectangle:
            drawRectangleAnnotation(annotation, in: context, color: color, opacity: opacity)
        case .circle:
            drawCircleAnnotation(annotation, in: context, color: color, opacity: opacity)
        case .line:
            drawLineAnnotation(annotation, in: context, color: color, opacity: opacity)
        case .highlight:
            drawHighlightAnnotation(annotation, in: context, color: color, opacity: opacity)
        case .freeDraw:
            drawFreeDrawAnnotation(annotation, in: context, color: color, opacity: opacity)
        }
        
    }
    
    private func drawFreeDrawAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        guard annotation.pathPoints.count > 1 else { return }
        
        var path = Path()
        path.move(to: annotation.pathPoints[0])
        
        for point in annotation.pathPoints.dropFirst() {
            path.addLine(to: point)
        }
        
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: annotation.strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
    
    private func drawArrowAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        let geometry = ArrowGeometry(start: annotation.startPoint, end: annotation.endPoint,
            style: annotation.arrowStyle ?? .open, headSize: annotation.arrowheadSize, strokeWidth: annotation.strokeWidth)
        context.stroke(Path(geometry.stroke), with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: annotation.strokeWidth, lineCap: .round, lineJoin: .round))
        context.fill(Path(geometry.fill), with: .color(color.opacity(opacity)))
    }
    
    private func drawRectangleAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        
        // Fill
        if annotation.fillOpacity > 0 {
            context.fill(
                Path(rect),
                with: .color(color.opacity(annotation.fillOpacity * opacity))
            )
        }
        
        if annotation.strokeWidth > 0 {
            context.stroke(
                Path(rect),
                with: .color(color.opacity(opacity)),
                lineWidth: annotation.strokeWidth
            )
        }
    }
    
    private func drawCircleAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        let width = abs(annotation.endPoint.x - annotation.startPoint.x)
        let height = abs(annotation.endPoint.y - annotation.startPoint.y)
        let diameter = max(width, height)
        let centerX = (annotation.startPoint.x + annotation.endPoint.x) / 2
        let centerY = (annotation.startPoint.y + annotation.endPoint.y) / 2
        
        let rect = CGRect(
            x: centerX - diameter / 2,
            y: centerY - diameter / 2,
            width: diameter,
            height: diameter
        )
        
        let path = Path(ellipseIn: rect)
        
        // Fill
        if annotation.fillOpacity > 0 {
            context.fill(
                path,
                with: .color(color.opacity(annotation.fillOpacity * opacity))
            )
        }
        
        // Stroke
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: annotation.strokeWidth
        )
    }
    
    private func drawLineAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        var path = Path()
        path.move(to: annotation.startPoint)
        path.addLine(to: annotation.endPoint)
        
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: annotation.strokeWidth
        )
    }
    
    private func drawHighlightAnnotation(_ annotation: Annotation, in context: GraphicsContext, color: Color, opacity: Double) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        
        context.fill(
            Path(rect),
            with: .color(color.opacity(annotation.fillOpacity * opacity))
        )
    }
    
    // MARK: - Gesture Handlers
    
    private func handleTap(at location: CGPoint) {
        if annotationManager.isEditingText {
            annotationManager.finishEditingText()
            annotationManager.selectTool(.select)
            _ = annotationManager.selectAnnotation(at: location)
            return
        }

        if annotationManager.currentTool != .text,
           annotationManager.selectAnnotation(at: location) {
            annotationManager.selectTool(.select)
            return
        }
        
        if annotationManager.currentTool == .select {
            if annotationManager.selectAnnotation(at: location) {
                annotationManager.selectTool(.select)
            }
        } else if annotationManager.currentTool == .text {
            annotationManager.createTextAnnotation(at: location)
        } else {
            annotationManager.deselectAnnotation()
        }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let location = sourcePoint(fromDisplayPoint: value.location)
        let startLocation = sourcePoint(fromDisplayPoint: value.startLocation)
        
        if annotationManager.currentTool == .select {
            if annotationManager.isEditingText {
                return
            }

            if activeDragAnnotationId == nil {
                guard annotationManager.selectAnnotation(at: startLocation),
                      let selectedId = annotationManager.selectedAnnotationId
                else { return }

                activeDragAnnotationId = selectedId
                lastDragLocation = startLocation
            }

            guard activeDragAnnotationId != nil,
                  let lastDragLocation else { return }

            let delta = CGSize(
                width: location.x - lastDragLocation.x,
                height: location.y - lastDragLocation.y
            )
            if delta != .zero {
                if !recordedDragUndo {
                    annotationManager.recordUndoSnapshot()
                    recordedDragUndo = true
                }
                annotationManager.moveSelectedAnnotation(by: delta, recordHistory: false)
                self.lastDragLocation = location
            }
        } else if let toolType = annotationManager.currentTool.annotationType, toolType != .text {
            // Draw new annotation (except text, which is handled by tap)
            if !annotationManager.isDrawing {
                if annotationManager.selectAnnotation(at: startLocation),
                   let selectedId = annotationManager.selectedAnnotationId {
                    annotationManager.selectTool(.select)
                    activeDragAnnotationId = selectedId
                    lastDragLocation = startLocation
                    return
                }

                annotationManager.startDrawing(at: startLocation)
            }
            annotationManager.updateDrawing(to: location)
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        let isTap = dragDistance < 5 // Consider it a tap if drag distance is less than 5 points
        
        if annotationManager.currentTool == .select {
            if isTap {
                handleTap(at: sourcePoint(fromDisplayPoint: value.startLocation))
            }
            resetDragState()
        } else if annotationManager.currentTool == .text && isTap {
            handleTap(at: sourcePoint(fromDisplayPoint: value.startLocation))
        } else if annotationManager.isDrawing {
            // Finish drawing
            annotationManager.finishDrawing()
        }
    }

    private func resetDragState() {
        lastDragLocation = nil
        activeDragAnnotationId = nil
        recordedDragUndo = false
    }

    private func sourcePoint(fromDisplayPoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: scaleX == 0 ? point.x : point.x / scaleX,
            y: scaleY == 0 ? point.y : point.y / scaleY
        )
    }

    private func displayPoint(fromSourcePoint point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scaleX, y: point.y * scaleY)
    }

    private func annotationForDisplay(_ annotation: Annotation) -> Annotation {
        var displayed = annotation
        displayed.startPoint = displayPoint(fromSourcePoint: annotation.startPoint)
        displayed.endPoint = displayPoint(fromSourcePoint: annotation.endPoint)
        displayed.strokeWidth = annotation.strokeWidth * displayScale
        displayed.fontSize = annotation.fontSize * displayScale
        displayed.arrowheadSize = annotation.arrowheadSize * displayScale
        displayed.pathPoints = annotation.pathPoints.map(displayPoint(fromSourcePoint:))
        return displayed
    }
}

// MARK: - Selection Overlay & Handles

extension DrawingCanvasView {
    @ViewBuilder
    private func selectionOverlay(for annotation: Annotation) -> some View {
        let bounds = annotationForDisplay(annotation).bounds
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .frame(width: max(1, bounds.width + 10), height: max(1, bounds.height + 10))
                .position(x: bounds.midX, y: bounds.midY)
                .allowsHitTesting(false)

            Button(action: { annotationManager.deleteSelectedAnnotation() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .background(Color.white.opacity(0.9).clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .position(x: bounds.maxX + 10, y: bounds.minY - 10)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }
}

#endif
