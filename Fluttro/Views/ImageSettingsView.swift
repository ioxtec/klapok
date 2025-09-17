//
//  ImageSettingsView.swift
//  Fluttro
//
//  Image capture settings view
//

import SwiftUI

#if os(macOS)

struct ImageSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Image Quality Section
                GroupBox(LocalizationKeys.imageQualityTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsPickerOption(
                            title: LocalizationKeys.formatTitle.localized,
                            description: LocalizationKeys.formatDescription.localized,
                            selection: .constant("PNG"),
                            options: [("PNG", "PNG"), ("JPEG", "JPEG")]
                        )
                        
                        SettingsSliderOption(
                            title: LocalizationKeys.qualityTitle.localized,
                            description: LocalizationKeys.qualityDescription.localized,
                            isLast: true,
                            value: .constant(0.9),
                            in: 0.1...1.0,
                            step: 0.1,
                            formatter: { "\(Int($0 * 100))%" }
                        )
                    }
                }
                
                // Editor Settings Section
                GroupBox(LocalizationKeys.editorTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsPickerOption(
                            title: LocalizationKeys.defaultGradientTitle.localized,
                            description: LocalizationKeys.defaultGradientDescription.localized,
                            selection: .constant("Cool"),
                            options: [("Cool", "Cool"), ("Warm", "Warm"), ("Violet", "Violet"), ("None", "None")]
                        )
                        
                        SettingsSliderOption(
                            title: LocalizationKeys.defaultPaddingTitle.localized,
                            description: LocalizationKeys.defaultPaddingDescription.localized,
                            isLast: false,
                            value: .constant(30.0),
                            in: 10...100,
                            step: 5,
                            formatter: { "\(Int($0))px" }
                        )
                        
                        SettingsPickerOption(
                            title: "Domyślny aspect ratio",
                            description: "Proporcje tła dla nowych zrzutów",
                            isLast: true,
                            selection: .constant("Auto"),
                            options: [("Auto", "Auto"), ("16:9", "16:9"), ("4:3", "4:3"), ("1:1", "1:1")]
                        )
                    }
                }
                
                // Capture Behavior Section
                GroupBox(LocalizationKeys.captureBehaviorTitle.localized) {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: "Pokaż kursor myszy",
                            description: "Dołącz kursor myszy do zrzutów",
                            isOn: $viewModel.showMouseCursor
                        )
                        
                        SettingsToggleOption(
                            title: "Automatycznie otwórz edytor",
                            description: "Otwórz edytor po zrobieniu zrzutu",
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: "Kopiuj do schowka po zapisie",
                            description: "Automatycznie kopiuj zrzut do schowka",
                            isOn: .constant(false)
                        )
                        
                        SettingsToggleOption(
                            title: "Pokaż powiadomienie po zapisie",
                            description: "Wyświetl powiadomienie po zapisaniu zrzutu",
                            isLast: true,
                            isOn: .constant(true)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24) // Add bottom spacing
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
}

#Preview {
    ImageSettingsView()
}

#endif
