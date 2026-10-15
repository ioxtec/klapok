//
//  AnnotationToolbarPropertiesView.swift
//  Klapok
//
//  Context-sensitive toolbar properties for annotation tools
//

import SwiftUI

#if os(macOS)
import AppKit

struct AnnotationToolbarPropertiesView: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let selectedAnnotation = annotationManager.selectedAnnotation,
                   annotationManager.currentTool == .select {
                    SelectedAnnotationPropertiesView(
                        annotation: selectedAnnotation,
                        annotationManager: annotationManager
                    )
                } else {
                    switch annotationManager.currentTool {
                    case .text:
                        TextToolProperties(annotationManager: annotationManager)
                    case .arrow:
                        ArrowToolProperties(annotationManager: annotationManager)
                    case .rectangle:
                        RectangleToolProperties(annotationManager: annotationManager)
                    case .circle:
                        CircleToolProperties(annotationManager: annotationManager)
                    case .line:
                        LineToolProperties(annotationManager: annotationManager)
                    case .highlight:
                        HighlightToolProperties(annotationManager: annotationManager)
                    case .freeDraw:
                        FreeDrawToolProperties(annotationManager: annotationManager)
                    case .select, .none:
                        EmptyView()
                    }
                }
            }
            .frame(height: 32)
        }
        .frame(width: 420, height: 32, alignment: .leading)
        .clipped()
    }
}

// MARK: - Selected Annotation Properties

struct SelectedAnnotationPropertiesView: View {
    let annotation: Annotation
    @ObservedObject var annotationManager: AnnotationManager

    var body: some View {
        HStack(spacing: 12) {
            Label(annotation.type.displayName, systemImage: annotation.type.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 20)

            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                ColorPicker("", selection: selectedColor)
                    .labelsHidden()
                    .frame(width: 50)
            }

            if showsStrokeWidth {
                Divider()
                    .frame(height: 20)

                strokeWidthMenu
            }

            if annotation.type == .text {
                Divider()
                    .frame(height: 20)

                fontSizeMenu

                Divider()
                    .frame(height: 20)

                fontWeightMenu

                Button("Edit Text") {
                    annotationManager.startEditingText(annotationId: annotation.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if annotation.type == .arrow {
                ArrowStylePicker(selection: Binding(
                    get: { annotationManager.selectedAnnotation?.arrowStyle ?? .open },
                    set: { annotationManager.updateSelectedAnnotationArrowStyle($0) }
                ))
            }

            if showsFillOpacity {
                Divider()
                    .frame(height: 20)

                fillOpacityMenu
            }

            Divider()
                .frame(height: 20)

            Button(role: .destructive) {
                annotationManager.deleteSelectedAnnotation()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Delete selected annotation")
        }
    }

    private var showsStrokeWidth: Bool {
        switch annotation.type {
        case .text, .highlight:
            return false
        case .arrow, .rectangle, .circle, .line, .freeDraw:
            return true
        }
    }

    private var showsFillOpacity: Bool {
        switch annotation.type {
        case .rectangle, .circle, .highlight:
            return true
        case .text, .arrow, .line, .freeDraw:
            return false
        }
    }

    private var selectedColor: Binding<Color> {
        Binding(
            get: {
                annotationManager.selectedAnnotation?.color.toColor() ?? annotation.color.toColor()
            },
            set: { color in
                annotationManager.updateSelectedAnnotationColor(color)
            }
        )
    }

    private var strokeWidthMenu: some View {
        HStack(spacing: 6) {
            Image(systemName: "lineweight")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Menu {
                ForEach(strokeWidthOptions, id: \.self) { width in
                    Button("\(width)px") {
                        annotationManager.updateSelectedAnnotationStrokeWidth(CGFloat(width))
                    }
                }
            } label: {
                Text("\(Int(annotationManager.selectedAnnotation?.strokeWidth ?? annotation.strokeWidth))px")
                    .font(.system(size: 13))
                    .frame(minWidth: 50)
            }
            .buttonStyle(.bordered)
            .frame(height: 28)
        }
    }

    private var strokeWidthOptions: [Int] {
        switch annotation.type {
        case .rectangle:
            return [0, 1, 2, 3, 4, 5, 6, 8, 10, 12, 15]
        case .text, .arrow, .circle, .line, .highlight, .freeDraw:
            return [1, 2, 3, 4, 5, 6, 8, 10, 12, 15]
        }
    }

    private var fontSizeMenu: some View {
        HStack(spacing: 6) {
            Image(systemName: "textformat.size")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Menu {
                ForEach([12, 14, 16, 18, 20, 24, 28, 32, 36, 48], id: \.self) { size in
                    Button("\(size)pt") {
                        annotationManager.updateSelectedAnnotationFontSize(CGFloat(size))
                    }
                }
            } label: {
                Text("\(Int(annotationManager.selectedAnnotation?.fontSize ?? annotation.fontSize))pt")
                    .font(.system(size: 13))
                    .frame(minWidth: 44)
            }
            .buttonStyle(.bordered)
            .frame(height: 28)
        }
    }

    private var fontWeightMenu: some View {
        HStack(spacing: 6) {
            Image(systemName: "bold")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Menu {
                ForEach(FontWeight.allCases, id: \.self) { weight in
                    Button(weight.rawValue) {
                        annotationManager.updateSelectedAnnotationFontWeight(weight)
                    }
                }
            } label: {
                Text((annotationManager.selectedAnnotation?.fontWeight ?? annotation.fontWeight).rawValue)
                    .font(.system(size: 13))
                    .frame(minWidth: 70)
            }
            .buttonStyle(.bordered)
            .frame(height: 28)
        }
    }

    private var fillOpacityMenu: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(annotation.type == .highlight ? "Opacity" : "Fill")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Menu {
                ForEach([0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100], id: \.self) { opacity in
                    Button("\(opacity)%") {
                        annotationManager.updateSelectedAnnotationFillOpacity(Double(opacity) / 100.0)
                    }
                }
            } label: {
                let fillOpacity = annotationManager.selectedAnnotation?.fillOpacity ?? annotation.fillOpacity
                Text("\(Int(fillOpacity * 100))%")
                    .font(.system(size: 13))
                    .frame(minWidth: 50)
            }
            .buttonStyle(.bordered)
            .frame(height: 28)
        }
    }
}

// MARK: - Text Tool Properties

struct TextToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Color
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Font size
            HStack(spacing: 6) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([12, 14, 16, 18, 20, 24, 28, 32, 36, 48], id: \.self) { size in
                        Button("\(size)pt") {
                            annotationManager.defaultFontSize = CGFloat(size)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultFontSize))pt")
                        .font(.system(size: 13))
                        .frame(minWidth: 40)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
            
            Divider()
                .frame(height: 20)
            
            // Font weight
            HStack(spacing: 6) {
                Image(systemName: "bold")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(FontWeight.allCases, id: \.self) { weight in
                        Button(weight.rawValue) {
                            annotationManager.defaultFontWeight = weight
                        }
                    }
                } label: {
                    Text(annotationManager.defaultFontWeight.rawValue)
                        .font(.system(size: 13))
                        .frame(minWidth: 70)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Arrow Tool Properties

struct ArrowToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
            ArrowStylePicker(selection: $annotationManager.defaultArrowStyle)
            // Color
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Stroke width
            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([1, 2, 3, 4, 5, 6, 8, 10], id: \.self) { width in
                        Button("\(width)px") {
                            annotationManager.defaultStrokeWidth = CGFloat(width)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Rectangle Tool Properties

struct RectangleToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager

    private var hasFill: Bool {
        annotationManager.defaultFillOpacity > 0
    }

    private var hasFillBinding: Binding<Bool> {
        Binding(
            get: { hasFill },
            set: { shouldFill in
                if shouldFill {
                    annotationManager.defaultFillOpacity = hasFill
                        ? annotationManager.defaultFillOpacity
                        : 0.3
                } else {
                    annotationManager.defaultFillOpacity = 0
                }
            }
        )
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Stroke color
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Stroke")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Stroke width
            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([0, 1, 2, 3, 4, 5, 6, 8, 10], id: \.self) { width in
                        Button("\(width)px") {
                            annotationManager.defaultStrokeWidth = CGFloat(width)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
            
            Divider()
                .frame(height: 20)
            
            // Fill toggle and opacity
            HStack(spacing: 6) {
                Toggle(isOn: hasFillBinding) {
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                if hasFill {
                    Menu {
                        ForEach([10, 20, 30, 40, 50, 60, 70, 80, 90, 100], id: \.self) { opacity in
                            Button("\(opacity)%") {
                                annotationManager.defaultFillOpacity = Double(opacity) / 100.0
                            }
                        }
                    } label: {
                        Text("\(Int(annotationManager.defaultFillOpacity * 100))%")
                            .font(.system(size: 13))
                            .frame(minWidth: 50)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 28)
                }
            }
        }
    }
}

// MARK: - Circle Tool Properties

struct CircleToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager

    private var hasFill: Bool {
        annotationManager.defaultFillOpacity > 0
    }

    private var hasFillBinding: Binding<Bool> {
        Binding(
            get: { hasFill },
            set: { shouldFill in
                if shouldFill {
                    annotationManager.defaultFillOpacity = hasFill
                        ? annotationManager.defaultFillOpacity
                        : 0.3
                } else {
                    annotationManager.defaultFillOpacity = 0
                }
            }
        )
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Stroke color
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Stroke")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Stroke width
            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([1, 2, 3, 4, 5, 6, 8, 10], id: \.self) { width in
                        Button("\(width)px") {
                            annotationManager.defaultStrokeWidth = CGFloat(width)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
            
            Divider()
                .frame(height: 20)
            
            // Fill toggle and opacity
            HStack(spacing: 6) {
                Toggle(isOn: hasFillBinding) {
                    HStack(spacing: 4) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                
                if hasFill {
                    Menu {
                        ForEach([10, 20, 30, 40, 50, 60, 70, 80, 90, 100], id: \.self) { opacity in
                            Button("\(opacity)%") {
                                annotationManager.defaultFillOpacity = Double(opacity) / 100.0
                            }
                        }
                    } label: {
                        Text("\(Int(annotationManager.defaultFillOpacity * 100))%")
                            .font(.system(size: 13))
                            .frame(minWidth: 50)
                    }
                    .buttonStyle(.bordered)
                    .frame(height: 28)
                }
            }
        }
    }
}

// MARK: - Line Tool Properties

struct LineToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Color
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Stroke width
            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([1, 2, 3, 4, 5, 6, 8, 10], id: \.self) { width in
                        Button("\(width)px") {
                            annotationManager.defaultStrokeWidth = CGFloat(width)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Highlight Tool Properties

struct HighlightToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Color
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Opacity
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Opacity")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([10, 20, 30, 40, 50, 60, 70, 80], id: \.self) { opacity in
                        Button("\(opacity)%") {
                            annotationManager.defaultFillOpacity = Double(opacity) / 100.0
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultFillOpacity * 100))%")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
        }
    }
}

// MARK: - Free Draw Tool Properties

struct FreeDrawToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Color
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                ColorPicker("", selection: $annotationManager.defaultColor)
                    .labelsHidden()
                    .frame(width: 50)
            }
            
            Divider()
                .frame(height: 20)
            
            // Stroke width
            HStack(spacing: 6) {
                Image(systemName: "lineweight")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach([1, 2, 3, 4, 5, 6, 8, 10, 12, 15], id: \.self) { width in
                        Button("\(width)px") {
                            annotationManager.defaultStrokeWidth = CGFloat(width)
                        }
                    }
                } label: {
                    Text("\(Int(annotationManager.defaultStrokeWidth))px")
                        .font(.system(size: 13))
                        .frame(minWidth: 50)
                }
                .buttonStyle(.bordered)
                .frame(height: 28)
            }
        }
    }
}

#endif
