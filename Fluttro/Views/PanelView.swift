//
//  ContentView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 08/09/2025.
//

import SwiftUI

struct PanelView: View {
    @State private var text: String = ""

        var body: some View {
            HStack(spacing: 16) {
                // Ikony po lewej (przykładowo)
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.pink)
                        .frame(width: 32, height: 32)
                }


                // Ikony po prawej (przykładowo)
                HStack(spacing: 20) {
                    Image(systemName: "cpu")
                    Image(systemName: "globe")
                    Image(systemName: "link")
                    Image(systemName: "waveform")
                    Image(systemName: "rectangle.on.rectangle")
                    Image(systemName: "mic")
                }
                .foregroundColor(.gray)
                .font(.system(size: 21, weight: .regular))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.sRGB, white: 0.1, opacity: 0.96))
                    .shadow(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.sRGB, white: 0.35, opacity: 0.23), lineWidth: 1)
            )
            .padding(.horizontal)
        }
}

#Preview {
    PanelView()
}
