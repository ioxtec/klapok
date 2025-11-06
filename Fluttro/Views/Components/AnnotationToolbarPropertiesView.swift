//
//  AnnotationToolbarPropertiesView.swift
//  Fluttro
//
//  Context-sensitive toolbar properties for annotation tools
//

import SwiftUI

#if os(macOS)
import AppKit

struct AnnotationToolbarPropertiesView: View {
    @ObservedObject var annotationManager: AnnotationManager
    
    var body: some View {
        HStack(spacing: 12) {
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
    @State private var hasFill: Bool = true
    
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
                Toggle(isOn: $hasFill) {
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
                .onChange(of: hasFill) {
                    annotationManager.defaultFillOpacity = hasFill ? 0.3 : 0.0
                }
                
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
        .onAppear {
            hasFill = annotationManager.defaultFillOpacity > 0
        }
    }
}

// MARK: - Circle Tool Properties

struct CircleToolProperties: View {
    @ObservedObject var annotationManager: AnnotationManager
    @State private var hasFill: Bool = true
    
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
                Toggle(isOn: $hasFill) {
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
                .onChange(of: hasFill) {
                    annotationManager.defaultFillOpacity = hasFill ? 0.3 : 0.0
                }
                
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
        .onAppear {
            hasFill = annotationManager.defaultFillOpacity > 0
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

#Preview {
    VStack(spacing: 20) {
        Text("Text Tool")
        TextToolProperties(annotationManager: AnnotationManager())
        
        Divider()
        
        Text("Arrow Tool")
        ArrowToolProperties(annotationManager: AnnotationManager())
        
        Divider()
        
        Text("Rectangle Tool")
        RectangleToolProperties(annotationManager: AnnotationManager())
        
        Divider()
        
        Text("Line Tool")
        LineToolProperties(annotationManager: AnnotationManager())
        
        Divider()
        
        Text("Highlight Tool")
        HighlightToolProperties(annotationManager: AnnotationManager())
    }
    .padding()
    .frame(width: 800)
}

#endif

