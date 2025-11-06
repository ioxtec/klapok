//
//  DrawingCanvasView.swift
//  Fluttro
//
//  Canvas view for drawing and displaying annotations
//

import SwiftUI

#if os(macOS)
import AppKit

struct DrawingCanvasView: View {
    @ObservedObject var annotationManager: AnnotationManager
    let canvasSize: CGSize
    
    @State private var dragStart: CGPoint?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Canvas for non-text annotations
            Canvas { context, size in
                // Draw all committed non-text annotations
                for annotation in annotationManager.annotations {
                    if annotation.type != .text {
                        drawAnnotation(annotation, in: context, canvasSize: size, isSelected: annotation.id == annotationManager.selectedAnnotationId)
                    }
                }
                
                // Draw current draft annotation being drawn (if not text)
                if let draft = annotationManager.currentDraft, draft.type != .text {
                    drawAnnotation(draft, in: context, canvasSize: size, isSelected: false, opacity: 0.7)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            
            // Editable text annotations as SwiftUI views
            ForEach(annotationManager.annotations.filter { $0.type == .text }) { annotation in
                EditableTextAnnotationView(
                    annotation: annotation,
                    annotationManager: annotationManager,
                    canvasSize: canvasSize
                )
            }

            // Selection overlay: handles and delete button
            if let selectedId = annotationManager.selectedAnnotationId,
               let selected = annotationManager.annotations.first(where: { $0.id == selectedId }) {
                selectionOverlay(for: selected)
            }
        }
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
        .onTapGesture { location in
            handleTap(at: location)
        }
    }
    
    private func drawAnnotation(_ annotation: Annotation, in context: GraphicsContext, canvasSize: CGSize, isSelected: Bool, opacity: Double = 1.0) {
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
        
        // Draw selection indicator
        if isSelected {
            drawSelectionIndicator(annotation, in: context)
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
        let start = annotation.startPoint
        let end = annotation.endPoint
        
        // Draw line
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            lineWidth: annotation.strokeWidth
        )
        
        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength = annotation.arrowheadSize
        let arrowAngle: CGFloat = .pi / 6
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: end)
        arrowPath.addLine(to: point1)
        arrowPath.move(to: end)
        arrowPath.addLine(to: point2)
        
        context.stroke(
            arrowPath,
            with: .color(color.opacity(opacity)),
            lineWidth: annotation.strokeWidth
        )
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
        
        // Stroke
        context.stroke(
            Path(rect),
            with: .color(color.opacity(opacity)),
            lineWidth: annotation.strokeWidth
        )
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
    
    private func drawSelectionIndicator(_ annotation: Annotation, in context: GraphicsContext) {
        let bounds = annotation.bounds
        let expandedRect = bounds.insetBy(dx: -5, dy: -5)
        
        var path = Path()
        path.addRect(expandedRect)
        
        context.stroke(
            path,
            with: .color(.blue),
            style: StrokeStyle(lineWidth: 2, dash: [5, 3])
        )
    }
    
    // MARK: - Gesture Handlers
    
    private func handleTap(at location: CGPoint) {
        print("DrawingCanvasView: Tap at location: \(location)")
        print("DrawingCanvasView: Current tool: \(annotationManager.currentTool)")
        print("DrawingCanvasView: Is editing text: \(annotationManager.isEditingText)")
        
        // If editing text, finish editing and return (don't create new annotation)
        if annotationManager.isEditingText {
            print("DrawingCanvasView: Finishing text editing")
            annotationManager.finishEditingText()
            return
        }
        
        if annotationManager.currentTool == .select {
            _ = annotationManager.selectAnnotation(at: location)
        } else if annotationManager.currentTool == .text {
            print("DrawingCanvasView: Creating text annotation at: \(location)")
            // Create text annotation at tap location
            annotationManager.createTextAnnotation(at: location)
        } else {
            print("DrawingCanvasView: Tool \(annotationManager.currentTool) not handled in tap")
        }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let location = value.location
        
        print("DrawingCanvasView: Drag changed at: \(location), start: \(value.startLocation)")
        print("DrawingCanvasView: Current tool: \(annotationManager.currentTool)")
        
        if annotationManager.currentTool == .select {
            // Move selected annotation
            if dragStart == nil {
                dragStart = value.startLocation
            }
            let delta = CGSize(
                width: location.x - (dragStart?.x ?? location.x),
                height: location.y - (dragStart?.y ?? location.y)
            )
            dragOffset = delta
        } else if let toolType = annotationManager.currentTool.annotationType, toolType != .text {
            // Draw new annotation (except text, which is handled by tap)
            if !annotationManager.isDrawing {
                annotationManager.startDrawing(at: value.startLocation)
            }
            annotationManager.updateDrawing(to: location)
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        let isTap = dragDistance < 5 // Consider it a tap if drag distance is less than 5 points
        
        print("DrawingCanvasView: Drag ended. Distance: \(dragDistance), isTap: \(isTap)")
        print("DrawingCanvasView: Current tool: \(annotationManager.currentTool)")
        print("DrawingCanvasView: Is editing text: \(annotationManager.isEditingText)")
        
        // If editing text and it's a tap, finish editing
        if annotationManager.isEditingText && isTap {
            print("DrawingCanvasView: Finishing text editing from drag")
            annotationManager.finishEditingText()
            return
        }
        
        if annotationManager.currentTool == .select {
            // Apply movement
            if dragOffset != .zero {
                annotationManager.moveSelectedAnnotation(by: dragOffset)
            }
            dragStart = nil
            dragOffset = .zero
        } else if annotationManager.currentTool == .text && isTap {
            // Handle tap for text tool
            print("DrawingCanvasView: Handling tap for text tool at: \(value.startLocation)")
            annotationManager.createTextAnnotation(at: value.startLocation)
        } else if annotationManager.isDrawing {
            // Finish drawing
            annotationManager.finishDrawing()
        }
    }
}

// MARK: - Selection Overlay & Handles

extension DrawingCanvasView {
    @ViewBuilder
    private func selectionOverlay(for annotation: Annotation) -> some View {
        let bounds = annotation.bounds
        ZStack {
            handleView(at: CGPoint(x: bounds.minX, y: bounds.minY), handle: .topLeft)
            handleView(at: CGPoint(x: bounds.maxX, y: bounds.minY), handle: .topRight)
            handleView(at: CGPoint(x: bounds.minX, y: bounds.maxY), handle: .bottomLeft)
            handleView(at: CGPoint(x: bounds.maxX, y: bounds.maxY), handle: .bottomRight)

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
        .onAppear {
            print("🎯 SelectionOverlay [\(annotation.id.uuidString.prefix(8))]:")
            print("   Annotation model:")
            print("     startPoint: \(annotation.startPoint)")
            print("     endPoint: \(annotation.endPoint)")
            print("     bounds: \(bounds)")
            print("   Overlay handles positions:")
            print("     topLeft: (\(bounds.minX), \(bounds.minY))")
            print("     topRight: (\(bounds.maxX), \(bounds.minY))")
            print("     bottomLeft: (\(bounds.minX), \(bounds.maxY))")
            print("     bottomRight: (\(bounds.maxX), \(bounds.maxY))")
            print("   Delete button position: (\(bounds.maxX + 10), \(bounds.minY - 10))")
        }
        .onChange(of: annotation.startPoint) { _, _ in
            let newBounds = annotation.bounds
            print("🎯 SelectionOverlay: startPoint changed, bounds now: \(newBounds)")
        }
        .onChange(of: annotation.endPoint) { _, _ in
            let newBounds = annotation.bounds
            print("🎯 SelectionOverlay: endPoint changed, bounds now: \(newBounds)")
        }
    }

    private struct CornerHandle: View {
        let point: CGPoint
        let handle: ResizeHandle
        @ObservedObject var annotationManager: AnnotationManager
        @State private var lastTranslation: CGSize = .zero
        
        var body: some View {
            Circle()
                .fill(Color.blue)
                .frame(width: 10, height: 10)
                .position(x: point.x, y: point.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let delta = CGSize(
                                width: value.translation.width - lastTranslation.width,
                                height: value.translation.height - lastTranslation.height
                            )
                            annotationManager.resizeSelectedAnnotation(by: delta, handle: handle)
                            lastTranslation = value.translation
                        }
                        .onEnded { _ in
                            lastTranslation = .zero
                        }
                )
        }
    }

    @ViewBuilder
    private func handleView(at point: CGPoint, handle: ResizeHandle) -> some View {
        CornerHandle(point: point, handle: handle, annotationManager: annotationManager)
    }
}

#Preview {
    VStack {
        DrawingCanvasView(
            annotationManager: {
                let manager = AnnotationManager()
                manager.annotations = [
                    Annotation(
                        type: .text,
                        startPoint: CGPoint(x: 100, y: 100),
                        endPoint: CGPoint(x: 200, y: 120),
                        text: "Sample Text",
                        color: ColorData(color: .red)
                    ),
                    Annotation(
                        type: .arrow,
                        startPoint: CGPoint(x: 50, y: 200),
                        endPoint: CGPoint(x: 250, y: 250),
                        color: ColorData(color: .blue)
                    ),
                    Annotation(
                        type: .rectangle,
                        startPoint: CGPoint(x: 300, y: 100),
                        endPoint: CGPoint(x: 450, y: 200),
                        color: ColorData(color: .green)
                    )
                ]
                return manager
            }(),
            canvasSize: CGSize(width: 500, height: 400)
        )
    }
    .frame(width: 500, height: 400)
    .background(Color.gray.opacity(0.2))
}

#endif

