//
//  EditableTextAnnotationView.swift
//  Klapok
//
//  Editable text annotation with TextField and drag handles
//

import SwiftUI

#if os(macOS)
import AppKit

@MainActor
private final class EditableTextAnnotationViewState: ObservableObject {
    @Published var editingText = ""
    @Published var isDragging = false
    @Published var lastDragTranslation: CGSize = .zero
    @Published var recordedDragUndo = false
}

struct EditableTextAnnotationView: View {
    let annotation: Annotation
    @ObservedObject var annotationManager: AnnotationManager
    let canvasSize: CGSize
    let sourceImageSize: CGSize?
    @StateObject private var viewState = EditableTextAnnotationViewState()

    private var editingText: String {
        get { viewState.editingText }
        nonmutating set { viewState.editingText = newValue }
    }

    private var isDragging: Bool {
        get { viewState.isDragging }
        nonmutating set { viewState.isDragging = newValue }
    }

    private var lastDragTranslation: CGSize {
        get { viewState.lastDragTranslation }
        nonmutating set { viewState.lastDragTranslation = newValue }
    }

    private var recordedDragUndo: Bool {
        get { viewState.recordedDragUndo }
        nonmutating set { viewState.recordedDragUndo = newValue }
    }

    private var editingTextBinding: Binding<String> {
        Binding(get: { editingText }, set: { editingText = $0 })
    }
    
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
                TextField("Enter text", text: editingTextBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: fontSize, weight: annotation.fontWeight.swiftUIWeight))
                    .foregroundColor(annotation.color.toColor())
                    .padding(.horizontal, 4)
                    .onSubmit {
                        finishEditing()
                    }
                    .onAppear {
                        editingText = annotation.text ?? "Text"
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
        .onDisappear {
            if isEditing {
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

#endif
