//
//  VideoSettingsView.swift
//  Fluttro
//
//  Video capture settings view
//

import SwiftUI

#if os(macOS)

struct VideoSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Video Quality Section
                GroupBox("Jakość nagrywania") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsPickerOption(
                            title: "Rozdzielczość",
                            description: "Rozdzielczość nagrywania",
                            selection: .constant("Source"),
                            options: [("Source", "Źródło"), ("1080p", "1080p"), ("720p", "720p"), ("480p", "480p")]
                        )
                        
                        SettingsPickerOption(
                            title: "FPS",
                            description: "Liczba klatek na sekundę",
                            selection: .constant("30"),
                            options: [("60", "60 FPS"), ("30", "30 FPS"), ("24", "24 FPS")]
                        )
                        
                        SettingsPickerOption(
                            title: "Bitrate",
                            description: "Jakość kompresji wideo",
                            isLast: true,
                            selection: .constant("Auto"),
                            options: [("Auto", "Auto"), ("High", "Wysoki"), ("Medium", "Średni"), ("Low", "Niski")]
                        )
                    }
                }
                
                // Audio Settings Section
                GroupBox("Audio") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: "Nagrywaj audio systemu",
                            description: "Dołącz dźwięk z systemu do nagrań",
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: "Nagrywaj mikrofon",
                            description: "Dołącz dźwięk z mikrofonu do nagrań",
                            isOn: .constant(false)
                        )
                        
                        SettingsPickerOption(
                            title: "Jakość audio",
                            description: "Jakość nagrywania dźwięku",
                            isLast: true,
                            selection: .constant("High"),
                            options: [("High", "Wysoka"), ("Medium", "Średnia"), ("Low", "Niska")]
                        )
                    }
                }
                
                // Recording Behavior Section
                GroupBox("Zachowanie podczas nagrywania") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsToggleOption(
                            title: "Pokaż timer nagrywania",
                            description: "Wyświetl licznik czasu podczas nagrywania",
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: "Pokaż kursor myszy",
                            description: "Dołącz kursor myszy do nagrań",
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: "Automatycznie zatrzymaj po czasie",
                            description: "Zatrzymaj nagrywanie po określonym czasie",
                            isOn: .constant(false)
                        )
                        
                        SettingsPickerOption(
                            title: "Maksymalny czas",
                            description: "Limit czasu nagrywania",
                            isLast: true,
                            selection: .constant("10min"),
                            options: [("5min", "5 min"), ("10min", "10 min"), ("30min", "30 min"), ("unlimited", "Bez limitu")]
                        )
                    }
                }
                
                // File Settings Section
                GroupBox("Pliki") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingsOptionView(isLast: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Format")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Picker("Format", selection: .constant("MP4")) {
                                    Text("MP4").tag("MP4")
                                    Text("MOV").tag("MOV")
                                    Text("WebM").tag("WebM")
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        SettingsToggleOption(
                            title: "Kompresuj po nagraniu",
                            description: "Automatycznie kompresuj pliki wideo",
                            isOn: .constant(true)
                        )
                        
                        SettingsToggleOption(
                            title: "Usuń po nagraniu (jeśli nie zapisano)",
                            description: "Usuń pliki tymczasowe po nagraniu",
                            isLast: true,
                            isOn: .constant(false)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }
}

#Preview {
    VideoSettingsView()
}

#endif
