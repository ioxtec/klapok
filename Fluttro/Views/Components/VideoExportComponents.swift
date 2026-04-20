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
        SidebarControlRow(title: "Format", systemImage: "rectangle.stack") {
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
            .labelsHidden()
            .frame(width: 146)
        }
    }
}

// MARK: - Video Export Settings View

struct VideoExportSettingsView: View {
    @ObservedObject var exportManager: ExportManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SidebarDivider()

            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Video quality")

                SidebarControlRow(title: "Quality", systemImage: "sparkles") {
                    Picker("Quality", selection: Binding(
                        get: { exportManager.settings.videoSettings.quality },
                        set: { exportManager.updateVideoQuality($0) }
                    )) {
                        ForEach(VideoQuality.allCases) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }
                
                SidebarValueRow(
                    title: "Bitrate",
                    value: formatBitrate(exportManager.settings.videoSettings.quality.bitrate),
                    systemImage: "speedometer"
                )
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Scaling")

                SidebarControlRow(title: "Scaling", systemImage: "arrow.up.left.and.arrow.down.right") {
                    Picker("Scaling", selection: Binding(
                        get: { exportManager.settings.videoSettings.scaling },
                        set: { exportManager.updateVideoScaling($0) }
                    )) {
                        ForEach(VideoScaling.allCases) { scaling in
                            Text(scaling.displayName).tag(scaling)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }
                
                if exportManager.settings.videoSettings.scaling == .custom {
                    SidebarSliderControl(
                        title: "Scale factor",
                        valueText: String(format: "%.2fx", exportManager.settings.videoSettings.customScaleFactor),
                        systemImage: "plus.magnifyingglass",
                        value: Binding(
                            get: { exportManager.settings.videoSettings.customScaleFactor },
                            set: { exportManager.updateCustomScaleFactor($0) }
                        ),
                        range: 0.25...3.0,
                        step: 0.25
                    )
                }
                
                SidebarControlRow(title: "Keep proportions", systemImage: "lock") {
                    Toggle("", isOn: Binding(
                        get: { exportManager.settings.videoSettings.maintainAspectRatio },
                        set: { newValue in
                            exportManager.settings.videoSettings.maintainAspectRatio = newValue
                            exportManager.saveSettings()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Audio")

                SidebarControlRow(title: "Audio", systemImage: "speaker.wave.2") {
                    Picker("Audio", selection: Binding(
                        get: { exportManager.settings.videoSettings.audioOption },
                        set: { exportManager.updateAudioOption($0) }
                    )) {
                        ForEach(AudioExportOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }
                
                if exportManager.settings.videoSettings.audioOption == .include {
                    SidebarDivider()

                    SidebarControlRow(title: "System audio", systemImage: "speaker") {
                        Toggle("", isOn: Binding(
                            get: { exportManager.settings.videoSettings.includeSystemAudio },
                            set: { newValue in
                                exportManager.settings.videoSettings.includeSystemAudio = newValue
                                exportManager.saveSettings()
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }

                    SidebarDivider()

                    SidebarControlRow(title: "Microphone", systemImage: "mic") {
                        Toggle("", isOn: Binding(
                            get: { exportManager.settings.videoSettings.includeMicrophone },
                            set: { newValue in
                                exportManager.settings.videoSettings.includeMicrophone = newValue
                                exportManager.saveSettings()
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
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
    let sourceSize: CGSize?

    init(exportManager: ExportManager, sourceSize: CGSize? = nil) {
        self.exportManager = exportManager
        self.sourceSize = sourceSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SidebarDivider()

            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Color")

                SidebarControlRow(title: "Colors", systemImage: "paintpalette") {
                    Picker("Colors", selection: Binding(
                        get: { exportManager.settings.gifSettings.colorDepth },
                        set: { exportManager.updateGIFColorDepth($0) }
                    )) {
                        ForEach(GIFColorDepth.allCases) { depth in
                            Text(depth.displayName).tag(depth)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }

                SidebarDivider()

                SidebarControlRow(title: "Dithering", systemImage: "circle.grid.cross") {
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
                    .labelsHidden()
                    .frame(width: 118)
                }
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Frames")

                SidebarControlRow(title: "Frame format", systemImage: "film.stack") {
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
                    .labelsHidden()
                    .frame(width: 118)
                }

                SidebarDivider()

                SidebarSliderControl(
                    title: "Frame rate",
                    valueText: "\(exportManager.settings.gifSettings.frameRate) FPS",
                    systemImage: "gauge.with.dots.needle.67percent",
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.frameRate) },
                        set: { exportManager.updateGIFFrameRate(Int($0)) }
                    ),
                    range: 5...30,
                    step: 5
                )
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    SidebarSubheading("Size")

                    Spacer()

                    Button("Reset") {
                        resetGIFSize()
                    }
                    .controlSize(.small)
                    .disabled(sourceSize == nil)
                    .help("Restore original video size")
                }

                if let sourceSize {
                    SidebarValueRow(
                        title: "Original",
                        value: "\(Int(sourceSize.width.rounded())) x \(Int(sourceSize.height.rounded())) px",
                        systemImage: "video"
                    )
                }

                SidebarControlRow(title: "Keep proportions", systemImage: "lock") {
                    Toggle("", isOn: Binding(
                        get: { exportManager.settings.gifSettings.maintainAspectRatio },
                        set: { newValue in
                            exportManager.updateGIFMaintainAspectRatio(newValue)

                            if newValue {
                                updateGIFWidth(exportManager.settings.gifSettings.maxWidth)
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                SidebarDivider()

                SidebarSliderControl(
                    title: "Max width",
                    valueText: "\(exportManager.settings.gifSettings.maxWidth) px",
                    systemImage: "arrow.left.and.right",
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.maxWidth) },
                        set: { updateGIFWidth(Int($0.rounded())) }
                    ),
                    range: widthRange,
                    step: 10
                )

                SidebarDivider()

                SidebarSliderControl(
                    title: "Max height",
                    valueText: "\(exportManager.settings.gifSettings.maxHeight) px",
                    systemImage: "arrow.up.and.down",
                    value: Binding(
                        get: { Double(exportManager.settings.gifSettings.maxHeight) },
                        set: { updateGIFHeight(Int($0.rounded())) }
                    ),
                    range: heightRange,
                    step: 10
                )
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Quality & loop")

                SidebarSliderControl(
                    title: "Quality",
                    valueText: "\(Int(exportManager.settings.gifSettings.quality * 100))%",
                    systemImage: "sparkles",
                    value: Binding(
                        get: { exportManager.settings.gifSettings.quality },
                        set: { exportManager.updateGIFQuality($0) }
                    ),
                    range: 0.1...1.0,
                    step: 0.1
                )

                SidebarDivider()

                SidebarControlRow(title: "Loop mode", systemImage: "repeat") {
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
                    .labelsHidden()
                    .frame(width: 118)
                }
                
                if exportManager.settings.gifSettings.loopMode == .count {
                    SidebarDivider()

                    SidebarSliderControl(
                        title: "Loop count",
                        valueText: "\(exportManager.settings.gifSettings.loopCount)",
                        systemImage: "number",
                        value: Binding(
                            get: { Double(exportManager.settings.gifSettings.loopCount) },
                            set: { newValue in
                                exportManager.settings.gifSettings.loopCount = Int(newValue)
                                exportManager.saveSettings()
                            }
                        ),
                        range: 1...10,
                        step: 1
                    )
                }
                
                SidebarDivider()

                SidebarControlRow(title: "Optimize for web", systemImage: "globe") {
                    Toggle("", isOn: Binding(
                        get: { exportManager.settings.gifSettings.optimizeForWeb },
                        set: { newValue in
                            exportManager.settings.gifSettings.optimizeForWeb = newValue
                            exportManager.saveSettings()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
        }
    }

    private var widthRange: ClosedRange<Double> {
        Double(min(200, sourceWidth))...Double(max(1920, sourceWidth))
    }

    private var heightRange: ClosedRange<Double> {
        Double(min(200, sourceHeight))...Double(max(1080, sourceHeight))
    }

    private var sourceWidth: Int {
        guard let sourceSize else { return 800 }
        return max(1, Int(sourceSize.width.rounded()))
    }

    private var sourceHeight: Int {
        guard let sourceSize else { return 600 }
        return max(1, Int(sourceSize.height.rounded()))
    }

    private var aspectRatio: Double? {
        if sourceWidth > 0, sourceHeight > 0 {
            return Double(sourceWidth) / Double(sourceHeight)
        }

        let settings = exportManager.settings.gifSettings
        guard settings.maxHeight > 0 else { return nil }
        return Double(settings.maxWidth) / Double(settings.maxHeight)
    }

    private func updateGIFWidth(_ width: Int) {
        let clampedWidth = clamped(width, in: widthRange)
        guard exportManager.settings.gifSettings.maintainAspectRatio, let aspectRatio else {
            exportManager.updateGIFMaxSize(
                width: clampedWidth,
                height: exportManager.settings.gifSettings.maxHeight
            )
            return
        }

        let targetHeight = Int((Double(clampedWidth) / aspectRatio).rounded())
        let pairedHeight = clamped(targetHeight, in: heightRange)
        let pairedWidth = targetHeight == pairedHeight
            ? clampedWidth
            : clamped(Int((Double(pairedHeight) * aspectRatio).rounded()), in: widthRange)

        exportManager.updateGIFMaxSize(width: pairedWidth, height: pairedHeight)
    }

    private func updateGIFHeight(_ height: Int) {
        let clampedHeight = clamped(height, in: heightRange)
        guard exportManager.settings.gifSettings.maintainAspectRatio, let aspectRatio else {
            exportManager.updateGIFMaxSize(
                width: exportManager.settings.gifSettings.maxWidth,
                height: clampedHeight
            )
            return
        }

        let targetWidth = Int((Double(clampedHeight) * aspectRatio).rounded())
        let pairedWidth = clamped(targetWidth, in: widthRange)
        let pairedHeight = targetWidth == pairedWidth
            ? clampedHeight
            : clamped(Int((Double(pairedWidth) / aspectRatio).rounded()), in: heightRange)

        exportManager.updateGIFMaxSize(width: pairedWidth, height: pairedHeight)
    }

    private func resetGIFSize() {
        exportManager.updateGIFMaxSize(width: sourceWidth, height: sourceHeight)
    }

    private func clamped(_ value: Int, in range: ClosedRange<Double>) -> Int {
        min(max(value, Int(range.lowerBound)), Int(range.upperBound))
    }
}

#endif
