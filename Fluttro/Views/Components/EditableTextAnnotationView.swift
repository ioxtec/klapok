//
//  EditableTextAnnotationView.swift
//  Fluttro
//
//  Editable text annotation with TextField and drag handles
//

import SwiftUI

#if os(macOS)
import AppKit

struct EditableTextAnnotationView: View {
    let annotation: Annotation
    @ObservedObject var annotationManager: AnnotationManager
    let canvasSize: CGSize
    let sourceImageSize: CGSize?
    @State private var editingText: String = ""
    @State private var isDragging: Bool = false
    @State private var lastDragTranslation: CGSize = .zero
    @State private var recordedDragUndo = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var isEditing: Bool {
        annotationManager.editingTextAnnotationId == annotation.id
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
        let width = max(1, annotation.bounds.width * scaleX)
        let height = max(1, annotation.bounds.height * scaleY)
        let fontSize = max(6, annotation.fontSize * displayScale)
        
        Group {
            if isEditing {
                TextField("Enter text", text: $editingText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: fontSize, weight: annotation.fontWeight.swiftUIWeight))
                    .foregroundColor(annotation.color.toColor())
                    .padding(.horizontal, 4)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        editingText = annotation.text ?? "Text"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTextFieldFocused = true
                        }
                    }
                    .onChange(of: editingText) { _, newValue in
                        annotationManager.updateSelectedAnnotationText(newValue, recordHistory: false)
                    }
            } else {
                Text(annotation.text ?? "Text")
                    .font(.system(size: fontSize, weight: annotation.fontWeight.swiftUIWeight))
                    .foregroundColor(annotation.color.toColor())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.001))
                    )
                    .onTapGesture {
                        if annotationManager.currentTool == .select {
                            annotationManager.selectAnnotation(withId: annotation.id)
                        }
                    }
                    .onTapGesture(count: 2) {
                        startEditing()
                    }
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .contentShape(Rectangle())
        .position(
            x: annotation.startPoint.x * scaleX + width / 2,
            y: annotation.startPoint.y * scaleY + height / 2
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if annotationManager.currentTool == .select && !isEditing {
                        guard value.translation != .zero else { return }
                        if !isDragging {
                            annotationManager.selectAnnotation(withId: annotation.id)
                        }
                        if !recordedDragUndo {
                            annotationManager.recordUndoSnapshot()
                            recordedDragUndo = true
                        }
                        isDragging = true

                        let displayDelta = CGSize(
                            width: value.translation.width - lastDragTranslation.width,
                            height: value.translation.height - lastDragTranslation.height
                        )
                        let sourceDelta = CGSize(
                            width: scaleX == 0 ? displayDelta.width : displayDelta.width / scaleX,
                            height: scaleY == 0 ? displayDelta.height : displayDelta.height / scaleY
                        )
                        annotationManager.moveSelectedAnnotation(by: sourceDelta, recordHistory: false)
                        lastDragTranslation = value.translation
                    }
                }
                .onEnded { value in
                    if isDragging {
                        isDragging = false
                        lastDragTranslation = .zero
                        recordedDragUndo = false
                    }
                }
        )
        .onChange (of: isTextFieldFocused){ _, focused in
            if !focused && isEditing {
                finishEditing()
            }
        }
    }
    
    private func startEditing() {
        annotationManager.startEditingText(annotationId: annotation.id)
    }
    
    private func finishEditing() {
        // Update annotation text
        annotationManager.updateSelectedAnnotationText(editingText, recordHistory: false)
        annotationManager.finishEditingText()
        // Switch back to select tool after finishing text editing
        annotationManager.selectTool(.select)
    }
}

#Preview {
    VStack {
        EditableTextAnnotationView(
            annotation: Annotation(
                type: .text,
                startPoint: CGPoint(x: 100, y: 100),
                endPoint: CGPoint(x: 200, y: 130),
                text: "Sample Text",
                color: ColorData(color: .red)
            ),
            annotationManager: AnnotationManager(),
            canvasSize: CGSize(width: 400, height: 300),
            sourceImageSize: CGSize(width: 400, height: 300)
        )
    }
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.2))
}

#endif
