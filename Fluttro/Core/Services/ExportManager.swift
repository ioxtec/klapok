//
//  ExportManager.swift
//  Fluttro
//
//  Manager for video and GIF export settings
//

import Foundation
import SwiftUI
import Combine

class ExportManager: ObservableObject {
    static let shared = ExportManager()
    
    @Published var settings = ExportSettings()
    
    private let documentsPath: URL
    
    private init() {
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        loadSettings()
    }
    
    // Public initializer for previews
    init(forPreview: Bool) {
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if !forPreview {
            loadSettings()
        }
    }
    
    // MARK: - Persistence
    
    func saveSettings() {
        let url = documentsPath.appendingPathComponent("export_settings.json")
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url)
        } catch {
            Logger.e("ExportManager: Failed to save settings: \(error)")
        }
    }
    
    private func loadSettings() {
        let url = documentsPath.appendingPathComponent("export_settings.json")
        do {
            let data = try Data(contentsOf: url)
            settings = try JSONDecoder().decode(ExportSettings.self, from: data)
        } catch {
            Logger.w("ExportManager: Failed to load settings, using defaults: \(error)")
            settings = ExportSettings()
        }
    }
    
    // MARK: - Export Type Management
    
    func setExportType(_ type: ExportType) {
        settings.exportType = type
        saveSettings()
    }
    
    // MARK: - Video Settings
    
    func updateVideoQuality(_ quality: VideoQuality) {
        settings.videoSettings.quality = quality
        saveSettings()
    }
    
    func updateVideoScaling(_ scaling: VideoScaling) {
        settings.videoSettings.scaling = scaling
        saveSettings()
    }
    
    func updateCustomScaleFactor(_ factor: Double) {
        settings.videoSettings.customScaleFactor = factor
        saveSettings()
    }
    
    func updateAudioOption(_ option: AudioExportOption) {
        settings.videoSettings.audioOption = option
        saveSettings()
    }

    func effectiveVideoSettings(appSettings: AppSettings = .shared) -> VideoExportSettings {
        var resolvedSettings = settings.videoSettings
        resolvedSettings.quality = appSettings.normalizedVideoQuality
        return resolvedSettings
    }
    
    // MARK: - GIF Settings
    
    func updateGIFColorDepth(_ depth: GIFColorDepth) {
        settings.gifSettings.colorDepth = depth
        saveSettings()
    }
    
    func updateGIFFrameRate(_ fps: Int) {
        settings.gifSettings.frameRate = fps
        saveSettings()
    }
    
    func updateGIFMaxSize(width: Int, height: Int) {
        settings.gifSettings.maxWidth = width
        settings.gifSettings.maxHeight = height
        saveSettings()
    }

    func updateGIFMaintainAspectRatio(_ maintainAspectRatio: Bool) {
        settings.gifSettings.maintainAspectRatio = maintainAspectRatio
        saveSettings()
    }
    
    func updateGIFQuality(_ quality: Double) {
        settings.gifSettings.quality = quality
        saveSettings()
    }
}
