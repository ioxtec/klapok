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
    @State private var editingText: String = ""
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @FocusState private var isTextFieldFocused: Bool
    
    private var isEditing: Bool {
        annotationManager.editingTextAnnotationId == annotation.id
    }
    
    private var isSelected: Bool {
        annotationManager.selectedAnnotationId == annotation.id
    }
    
    var body: some View {
        let width = max(80, annotation.bounds.width)
        let height = max(30, annotation.bounds.height)
        
        // Use same positioning approach as overlay - frame on entire canvas with topLeading alignment
        Color.clear
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
            .overlay(
                Group {
                    if isEditing {
                        // Editing mode - TextField
                        TextField("Enter text", text: $editingText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: annotation.fontSize, weight: annotation.fontWeight.swiftUIWeight))
                            .foregroundColor(annotation.color.toColor())
                            .focused($isTextFieldFocused)
                            .frame(width: width, height: height, alignment: .topLeading)
                            .position(
                                x: annotation.startPoint.x + width / 2,
                                y: annotation.startPoint.y + height / 2
                            )
                            .onSubmit {
                                finishEditing()
                            }
                            .onAppear {
                                editingText = annotation.text ?? "Text"
                                print("EditableTextAnnotationView: Starting editing for annotation \(annotation.id)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                    print("EditableTextAnnotationView: Focus set for text field")
                                }
                            }
                    } else {
                        // Display mode - Text
                        Text(annotation.text ?? "Text")
                            .font(.system(size: annotation.fontSize, weight: annotation.fontWeight.swiftUIWeight))
                            .foregroundColor(annotation.color.toColor())
                            .frame(width: width, height: height, alignment: .topLeading)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.001))
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isSelected ? 2 : 0)
                            )
                            .position(
                                x: annotation.startPoint.x + width / 2,
                                y: annotation.startPoint.y + height / 2
                            )
                            .onTapGesture {
                                if annotationManager.currentTool == .select {
                                    startEditing()
                                }
                            }
                            .onTapGesture(count: 2) {
                                // Double-click to edit
                                startEditing()
                            }
                    }
                }
                .zIndex(10)
                .offset(dragOffset)
            )
        .onAppear {
            let centerX = annotation.startPoint.x + width / 2
            let centerY = annotation.startPoint.y + height / 2
            let textFieldFrame = CGRect(
                x: annotation.startPoint.x,
                y: annotation.startPoint.y,
                width: width,
                height: height
            )
            print("📝 EditableTextAnnotationView [\(annotation.id.uuidString.prefix(8))]:")
            print("   Annotation model:")
            print("     startPoint: \(annotation.startPoint)")
            print("     endPoint: \(annotation.endPoint)")
            print("     bounds: \(annotation.bounds)")
            print("   Text field position:")
            print("     frame size: width=\(width), height=\(height)")
            print("     position center: x=\(centerX), y=\(centerY)")
            print("     calculated top-left from center: x=\(centerX - width/2), y=\(centerY - height/2)")
            print("     expected top-left: x=\(annotation.startPoint.x), y=\(annotation.startPoint.y)")
            print("     frame rect: \(textFieldFrame)")
        }
        .onChange(of: annotation.startPoint) { _, newPoint in
            print("📝 EditableTextAnnotationView: startPoint changed to \(newPoint), bounds now: \(annotation.bounds)")
        }
        .onChange(of: annotation.endPoint) { _, newPoint in
            print("📝 EditableTextAnnotationView: endPoint changed to \(newPoint), bounds now: \(annotation.bounds)")
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if annotationManager.currentTool == .select && !isEditing {
                        isDragging = true
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if isDragging {
                        // Apply the drag offset to the annotation position
                        annotationManager.moveSelectedAnnotation(by: value.translation)
                        dragOffset = .zero
                        isDragging = false
                    }
                }
        )
        .onChange (of: isTextFieldFocused){ _, focused in
            if !focused && isEditing {
                finishEditing()
            }
        }
    }
    
    private var dragHandle: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 8, height: 8)
            .position(
                x: annotation.center.x + abs(annotation.endPoint.x - annotation.startPoint.x) / 2,
                y: annotation.center.y + abs(annotation.endPoint.y - annotation.startPoint.y) / 2
            )
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Handle resize gesture
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // Apply resize
                        resizeAnnotation(by: value.translation)
                        dragOffset = .zero
                    }
            )
    }
    
    private func startEditing() {
        annotationManager.startEditingText(annotationId: annotation.id)
    }
    
    private func finishEditing() {
        // Update annotation text
        annotationManager.updateSelectedAnnotationText(editingText)
        annotationManager.finishEditingText()
        // Switch back to select tool after finishing text editing
        annotationManager.selectTool(.select)
    }
    
    private func resizeAnnotation(by translation: CGSize) {
        // Update annotation size based on drag
        guard let index = annotationManager.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        
        var updatedAnnotation = annotationManager.annotations[index]
        updatedAnnotation.endPoint.x += translation.width
        updatedAnnotation.endPoint.y += translation.height
        updatedAnnotation.modifiedAt = Date()
        
        annotationManager.annotations[index] = updatedAnnotation
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
            canvasSize: CGSize(width: 400, height: 300)
        )
    }
    .frame(width: 400, height: 300)
    .background(Color.gray.opacity(0.2))
}

#endif
