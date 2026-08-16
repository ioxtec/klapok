//
//  AnnotationPropertiesView.swift
//  Fluttro
//
//  Properties panel for annotation editing
//

import SwiftUI

#if os(macOS)
import AppKit

struct AnnotationPropertiesView: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Annotations")
                .font(.headline)
            
            if let selected = annotationManager.selectedAnnotation {
                // Selected annotation properties
                SelectedAnnotationProperties(
                    annotation: selected,
                    annotationManager: annotationManager
                )
            } else {
                // Default tool properties
                DefaultToolProperties(annotationManager: annotationManager)
            }
        }
    }
}

// MARK: - Selected Annotation Properties

struct SelectedAnnotationProperties: View {
    let annotation: Annotation
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Annotation type indicator
            HStack {
                Image(systemName: annotation.type.icon)
                Text(annotation.type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    annotationManager.deleteSelectedAnnotation()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete annotation")
            }
            
            Divider()
            
            // Text content (for text annotations)
            if annotation.type == .text, let text = annotation.text {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Text", text: Binding(
                        get: { text },
                        set: { annotationManager.updateSelectedAnnotationText($0) }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            
            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ColorPicker("", selection: Binding(
                    get: { annotation.color.toColor() },
                    set: { annotationManager.updateSelectedAnnotationColor($0) }
                ))
                .labelsHidden()
            }
            
            // Stroke width (for non-highlight annotations)
            if annotation.type != .highlight {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stroke Width")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(annotation.strokeWidth))px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { annotation.strokeWidth },
                            set: { annotationManager.updateSelectedAnnotationStrokeWidth($0) }
                        ),
                        in: 1...10,
                        step: 1
                    )
                }
            }
            
            // Font size (for text annotations)
            if annotation.type == .text {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Font Size")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(annotation.fontSize))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { annotation.fontSize },
                            set: { annotationManager.updateSelectedAnnotationFontSize($0) }
                        ),
                        in: 10...48,
                        step: 2
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Default Tool Properties

struct DefaultToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tool selector
            Text("Drawing Tool")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ToolButton(
                    tool: .select,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.select) }
                )
                
                ToolButton(
                    tool: .text,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.text) }
                )
                
                ToolButton(
                    tool: .arrow,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.arrow) }
                )
                
                ToolButton(
                    tool: .rectangle,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.rectangle) }
                )
                
                ToolButton(
                    tool: .circle,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.circle) }
                )
                
                ToolButton(
                    tool: .line,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.line) }
                )
                
                ToolButton(
                    tool: .highlight,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.highlight) }
                )
                
                ToolButton(
                    tool: .freeDraw,
                    currentTool: annotationManager.currentTool,
                    action: { annotationManager.selectTool(.freeDraw) }
                )
            }
            
            Divider()
            
            // Default color
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
            }
            
            // Default stroke width
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Stroke Width")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $annotationManager.defaultStrokeWidth,
                    in: 1...10,
                    step: 1
                )
            }
            
            // Default font size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Font Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(annotationManager.defaultFontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $annotationManager.defaultFontSize,
                    in: 10...48,
                    step: 2
                )
            }
            
            // Clear all button
            if annotationManager.hasAnnotations {
                Divider()
                
                Button(action: {
                    annotationManager.clearAllAnnotations()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear All Annotations")
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: DrawingTool
    let currentTool: DrawingTool
    let selectedAnnotationType: AnnotationType?
    let action: () -> Void

    init(
        tool: DrawingTool,
        currentTool: DrawingTool,
        selectedAnnotationType: AnnotationType? = nil,
        action: @escaping () -> Void
    ) {
        self.tool = tool
        self.currentTool = currentTool
        self.selectedAnnotationType = selectedAnnotationType
        self.action = action
    }
    
    var isSelected: Bool {
        if let selectedAnnotationType {
            return tool.annotationType == selectedAnnotationType
        }
        return tool == currentTool
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor.opacity(0.95) : Color(NSColor.controlBackgroundColor).opacity(0.01))

                Image(systemName: tool.icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: 32, height: 32)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(tool.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#endif
