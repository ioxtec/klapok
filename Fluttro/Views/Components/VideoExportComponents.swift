//
//  VideoExportComponents.swift
//  Fluttro
//
//  Components for video and GIF export settings
//

import SwiftUI

#if os(macOS)

// MARK: - Export Type Selector

struct ExportTypeSelector: View {
    @ObservedObject var exportManager: ExportManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Format")
                .font(.callout)

            Picker("", selection: Binding(
                get: { exportManager.settings.exportType },
                set: { newType in
                    DispatchQueue.main.async {
                        exportManager.setExportType(newType)
                    }
                }
            )) {
                ForEach(ExportType.allCases) { type in
                    Text(type.displayName)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - Video Export Settings View

struct VideoExportSettingsView: View {
    @ObservedObject var exportManager: ExportManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quality Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Quality")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Quality", selection: Binding(
                    get: { exportManager.settings.videoSettings.quality },
                    set: { exportManager.updateVideoQuality($0) }
                )) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                
                Text("Bitrate: \(formatBitrate(exportManager.settings.videoSettings.quality.bitrate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Scaling Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Scaling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Scaling", selection: Binding(
                    get: { exportManager.settings.videoSettings.scaling },
                    set: { exportManager.updateVideoScaling($0) }
                )) {
                    ForEach(VideoScaling.allCases) { scaling in
                        Text(scaling.displayName).tag(scaling)
                    }
                }
                .pickerStyle(.menu)
                
                if exportManager.settings.videoSettings.scaling == .custom {
                    HStack {
                        Text("Scale Factor")
                        Spacer()
                        Text(String(format: "%.2fx", exportManager.settings.videoSettings.customScaleFactor))
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    Slider(
                        value: Binding(
                            get: { exportManager.settings.videoSettings.customScaleFactor },
                            set: { exportManager.updateCustomScaleFactor($0) }
                        ),
                        in: 0.25...3.0,
                        step: 0.25
                    )
                }
                
                Toggle("Maintain Aspect Ratio", isOn: Binding(
                    get: { exportManager.settings.videoSettings.maintainAspectRatio },
                    set: { newValue in
                        exportManager.settings.videoSettings.maintainAspectRatio = newValue
                        exportManager.saveSettings()
                    }
                ))
                .toggleStyle(.switch)
            }
            
            Divider()
            
            // Audio Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Audio Options")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Audio", selection: Binding(
                    get: { exportManager.settings.videoSettings.audioOption },
                    set: { exportManager.updateAudioOption($0) }
                )) {
                    ForEach(AudioExportOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                if exportManager.settings.videoSettings.audioOption == .include {
                    Toggle("Include System Audio", isOn: Binding(
                        get: { exportManager.settings.videoSettings.includeSystemAudio },
                        set: { newValue in
                            exportManager.settings.videoSettings.includeSystemAudio = newValue
                            exportManager.saveSettings()
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    Toggle("Include Microphone", isOn: Binding(
                        get: { exportManager.settings.videoSettings.includeMicrophone },
                        set: { newValue in
                            exportManager.settings.videoSettings.includeMicrophone = newValue
                            exportManager.saveSettings()
                        }
                    ))
                    .toggleStyle(.switch)
                }
            }
        }
    }
    
    private func formatBitrate(_ bitrate: Int) -> String {
        let mbps = Double(bitrate) / 1_000_000.0
        return String(format: "%.1f Mbps", mbps)
    }
}

// MARK: - GIF Export Settings View

struct GIFExportSettingsView: View {
    @ObservedObject var exportManager: ExportManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Color Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Color Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Colors", selection: Binding(
                    get: { exportManager.settings.gifSettings.colorDepth },
                    set: { exportManager.updateGIFColorDepth($0) }
                )) {
                    ForEach(GIFColorDepth.allCases) { depth in
                        Text(depth.displayName).tag(depth)
                    }
                }
                .pickerStyle(.menu)
                
                Picker("Dithering", selection: Binding(
                    get: { exportManager.settings.gifSettings.dithering },
                    set: { newValue in
                        exportManager.settings.gifSettings.dithering = newValue
                        exportManager.saveSettings()
                    }
                )) {
                    ForEach(GIFDithering.allCases) { dithering in
                        Text(dithering.displayName).tag(dithering)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Divider()
            
            // Frame Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Frame Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("Frame Format", selection: Binding(
                    get: { exportManager.settings.gifSettings.frameFormat },
                    set: { newValue in
                        exportManager.settings.gifSettings.frameFormat = newValue
                        exportManager.saveSettings()
                    }
                )) {
                    ForEach(GIFFrameFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    Text("Frame Rate")
                    Spacer()
                    Text("\(exportManager.settings.gifSettings.frameRate) FPS")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Slider(
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.frameRate) },
                        set: { exportManager.updateGIFFrameRate(Int($0)) }
                    ),
                    in: 5...30,
                    step: 5
                )
            }
            
            Divider()
            
            // Size Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Size Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("Max Width")
                    Spacer()
                    Text("\(exportManager.settings.gifSettings.maxWidth) px")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Slider(
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.maxWidth) },
                        set: { newValue in
                            exportManager.updateGIFMaxSize(
                                width: Int(newValue),
                                height: exportManager.settings.gifSettings.maxHeight
                            )
                        }
                    ),
                    in: 200...1920,
                    step: 100
                )
                
                HStack {
                    Text("Max Height")
                    Spacer()
                    Text("\(exportManager.settings.gifSettings.maxHeight) px")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Slider(
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.maxHeight) },
                        set: { newValue in
                            exportManager.updateGIFMaxSize(
                                width: exportManager.settings.gifSettings.maxWidth,
                                height: Int(newValue)
                            )
                        }
                    ),
                    in: 200...1080,
                    step: 100
                )
            }
            
            Divider()
            
            // Quality & Loop Settings
            VStack(alignment: .leading, spacing: 12) {
                Text("Quality & Loop")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("Quality")
                    Spacer()
                    Text("\(Int(exportManager.settings.gifSettings.quality * 100))%")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, design: .monospaced))
                }
                
                Slider(
                    value: Binding(
                        get: { exportManager.settings.gifSettings.quality },
                        set: { exportManager.updateGIFQuality($0) }
                    ),
                    in: 0.1...1.0,
                    step: 0.1
                )
                
                Picker("Loop Mode", selection: Binding(
                    get: { exportManager.settings.gifSettings.loopMode },
                    set: { newValue in
                        exportManager.settings.gifSettings.loopMode = newValue
                        exportManager.saveSettings()
                    }
                )) {
                    ForEach(GIFLoopMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                
                if exportManager.settings.gifSettings.loopMode == .count {
                    HStack {
                        Text("Loop Count")
                        Spacer()
                        Text("\(exportManager.settings.gifSettings.loopCount)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(exportManager.settings.gifSettings.loopCount) },
                            set: { newValue in
                                exportManager.settings.gifSettings.loopCount = Int(newValue)
                                exportManager.saveSettings()
                            }
                        ),
                        in: 1...10,
                        step: 1
                    )
                }
                
                Toggle("Optimize for Web", isOn: Binding(
                    get: { exportManager.settings.gifSettings.optimizeForWeb },
                    set: { newValue in
                        exportManager.settings.gifSettings.optimizeForWeb = newValue
                        exportManager.saveSettings()
                    }
                ))
                .toggleStyle(.switch)
            }
        }
    }
}

#endif
