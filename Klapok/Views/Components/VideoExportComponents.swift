//
//  VideoExportComponents.swift
//  Klapok
//
//  Components for video and GIF export settings
//

import SwiftUI

#if os(macOS)

// MARK: - Export Type Selector

struct ExportTypeSelector: View {
    @ObservedObject var exportManager: ExportManager
    
    var body: some View {
        SidebarControlRow(title: "Format".localized, systemImage: "rectangle.stack") {
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
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SidebarDivider()

            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Trimmed video export".localized)

                SidebarValueRow(
                    title: "Format".localized,
                    value: settings.videoFormat == "MOV" ? "QuickTime MOV" : "MP4",
                    systemImage: "film"
                )

                SidebarDivider()

                SidebarValueRow(
                    title: "Codec".localized,
                    value: settings.videoCodec == "H.265" ? "HEVC (H.265)" : "H.264",
                    systemImage: "cpu"
                )

                SidebarDivider()

                SidebarControlRow(title: "Quality".localized, systemImage: "sparkles") {
                    Picker("Quality".localized, selection: Binding(
                        get: { settings.normalizedVideoQuality },
                        set: { settings.applyVideoQuality($0) }
                    )) {
                        ForEach(VideoQuality.allCases) { quality in
                            Text(quality.displayName.localized).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 132)
                }

                SidebarValueRow(
                    title: "Export preset".localized,
                    value: settings.normalizedVideoQuality.exportPresetDescription.localized,
                    systemImage: "speedometer"
                )

                SidebarDivider()

                SidebarValueRow(
                    title: "Source".localized,
                    value: "Shared with the main video settings.".localized,
                    systemImage: "link"
                )
            }

            SidebarDivider()

            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Scaling".localized)

                SidebarControlRow(title: "Scaling".localized, systemImage: "arrow.up.left.and.arrow.down.right") {
                    Picker("Scaling".localized, selection: Binding(
                        get: { exportManager.settings.videoSettings.scaling },
                        set: { exportManager.updateVideoScaling($0) }
                    )) {
                        ForEach(VideoScaling.allCases) { scaling in
                            Text(scaling.displayName.localized).tag(scaling)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 132)
                }

                if exportManager.settings.videoSettings.scaling == .custom {
                    SidebarSliderControl(
                        title: "Scale factor".localized,
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
            }

            SidebarDivider()

            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Audio".localized)

                SidebarControlRow(title: "Audio".localized, systemImage: "speaker.wave.2") {
                    Picker("Audio".localized, selection: Binding(
                        get: { exportManager.settings.videoSettings.audioOption },
                        set: { exportManager.updateAudioOption($0) }
                    )) {
                        ForEach(AudioExportOption.allCases) { option in
                            Text(option.displayName.localized).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 132)
                }

                SidebarValueRow(
                    title: "Source".localized,
                    value: "Uses the edited timeline from this recording.".localized,
                    systemImage: "timeline.selection"
                )

                SidebarDivider()

                SidebarValueRow(
                    title: "Location".localized,
                    value: "Saved next to the source recording as a new exported video file.".localized,
                    systemImage: "folder"
                )

                SidebarDivider()

                Text("Keeps the source audio, removes it, or mutes it in the exported video file.".localized)
                    .font(SidebarStyle.bodyFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                SidebarSubheading("Color".localized)

                SidebarControlRow(title: "Colors".localized, systemImage: "paintpalette") {
                    Picker("Colors".localized, selection: Binding(
                        get: { exportManager.settings.gifSettings.colorDepth },
                        set: { exportManager.updateGIFColorDepth($0) }
                    )) {
                        ForEach(GIFColorDepth.allCases) { depth in
                            Text(depth.displayName.localized).tag(depth)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }

                SidebarDivider()

                SidebarControlRow(title: "Dithering".localized, systemImage: "circle.grid.cross") {
                    Picker("Dithering".localized, selection: Binding(
                        get: { exportManager.settings.gifSettings.dithering },
                        set: { newValue in
                            exportManager.settings.gifSettings.dithering = newValue
                            exportManager.saveSettings()
                        }
                    )) {
                        ForEach(GIFDithering.allCases) { dithering in
                            Text(dithering.displayName.localized).tag(dithering)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }
            }
            
            SidebarDivider()
            
            VStack(alignment: .leading, spacing: 9) {
                SidebarSubheading("Frames".localized)

                SidebarControlRow(title: "Frame format".localized, systemImage: "film.stack") {
                    Picker("Frame format".localized, selection: Binding(
                        get: { exportManager.settings.gifSettings.frameFormat },
                        set: { newValue in
                            exportManager.settings.gifSettings.frameFormat = newValue
                            exportManager.saveSettings()
                        }
                    )) {
                        ForEach(GIFFrameFormat.allCases) { format in
                            Text(format.displayName.localized).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }

                SidebarDivider()

                SidebarSliderControl(
                    title: "Frame rate".localized,
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
                    SidebarSubheading("Size".localized)

                    Spacer()

                    Button("Reset".localized) {
                        resetGIFSize()
                    }
                    .controlSize(.small)
                    .disabled(sourceSize == nil)
                    .help("Restore original video size".localized)
                }

                if let sourceSize {
                    SidebarValueRow(
                        title: "Original".localized,
                        value: "\(Int(sourceSize.width.rounded())) x \(Int(sourceSize.height.rounded())) px",
                        systemImage: "video"
                    )
                }

                SidebarControlRow(title: "Keep proportions".localized, systemImage: "lock") {
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
                    title: "Max width".localized,
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
                    title: "Max height".localized,
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
                SidebarSubheading("Quality & loop".localized)

                SidebarSliderControl(
                    title: "Quality".localized,
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

                SidebarControlRow(title: "Loop mode".localized, systemImage: "repeat") {
                    Picker("Loop mode".localized, selection: Binding(
                        get: { exportManager.settings.gifSettings.loopMode },
                        set: { newValue in
                            exportManager.settings.gifSettings.loopMode = newValue
                            exportManager.saveSettings()
                        }
                    )) {
                        ForEach(GIFLoopMode.allCases) { mode in
                            Text(mode.displayName.localized).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 118)
                }
                
                if exportManager.settings.gifSettings.loopMode == .count {
                    SidebarDivider()

                    SidebarSliderControl(
                        title: "Loop count".localized,
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

                SidebarControlRow(title: "Optimize for web".localized, systemImage: "globe") {
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
