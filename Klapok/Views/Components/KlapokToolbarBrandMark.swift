//
//  KlapokToolbarBrandMark.swift
//  Klapok
//

import SwiftUI

#if os(macOS)

struct KlapokToolbarBrandMark: View {
    @Environment(\.colorScheme) private var colorScheme
    
    enum Variant {
        case automatic
        case template
    }
    
    var variant: Variant = .automatic
    var size: CGFloat = 18
    var tint: Color? = nil

    private var assetName: String {
        switch variant {
        case .automatic:
            return colorScheme == .dark ? "KlapokToolbarLight" : "KlapokToolbarDark"
        case .template:
            return "KlapokToolbarDark"
        }
    }

    var body: some View {
        Group {
            if let tint {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(tint)
            } else {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Klapok")
        .help("Klapok")
    }
}

#endif
