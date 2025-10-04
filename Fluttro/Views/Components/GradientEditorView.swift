//
//  GradientEditorView.swift
//  Fluttro
//
//  Gradient editor for creating custom gradients
//

import SwiftUI

struct GradientEditorView: View {
    @ObservedObject var backgroundManager: BackgroundManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var gradientName = ""
    @State private var color1 = Color.blue
    @State private var color2 = Color.purple
    @State private var opacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Custom Gradient")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Gradient Preview
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [
                        color1.opacity(opacity),
                        color2.opacity(opacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Name Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Gradient Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter gradient name", text: $gradientName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Color Pickers
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color 1")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ColorPicker("", selection: $color1, supportsOpacity: false)
                            .frame(width: 60, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color1)
                            )
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color 2")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ColorPicker("", selection: $color2, supportsOpacity: false)
                            .frame(width: 60, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color2)
                            )
                    }
                }
                
                // Opacity Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Opacity")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(opacity * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $opacity, in: 0.1...1.0, step: 0.1)
                }
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Create Gradient") {
                    createGradient()
                }
                .buttonStyle(.borderedProminent)
                .disabled(gradientName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 500)
    }
    
    private func createGradient() {
        let customGradient = CustomGradient(
            name: gradientName,
            color1: ColorData(color: color1),
            color2: ColorData(color: color2),
            opacity: opacity
        )
        
        backgroundManager.addCustomGradient(customGradient)
        backgroundManager.selectGradient(withId: customGradient.id)
        dismiss()
    }
}

#Preview {
    GradientEditorView(backgroundManager: BackgroundManager(forPreview: true))
}
