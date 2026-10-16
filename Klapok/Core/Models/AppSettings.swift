//
//  AppSettings.swift
//  Klapok
//
//  Application settings model
//

import Foundation

#if os(macOS)
    import AppKit

    // MARK: - Settings Model

    enum ScreenshotReviewPosition: String, CaseIterable, Identifiable {
        case bottomRight
        case bottomLeft
        case topRight
        case topLeft
        case bottomCenter

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .bottomRight:
                return LocalizationKeys.reviewPositionBottomRight.localized
            case .bottomLeft:
                return LocalizationKeys.reviewPositionBottomLeft.localized
            case .topRight:
                return LocalizationKeys.reviewPositionTopRight.localized
            case .topLeft:
                return LocalizationKeys.reviewPositionTopLeft.localized
            case .bottomCenter:
                return LocalizationKeys.reviewPositionBottomCenter.localized
            }
        }
    }

    enum CapturePixelMode: String, CaseIterable, Identifiable {
        case realPixels
        case scaledScreenSize

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .realPixels:
                return LocalizationKeys.capturePixelModeReal.localized
            case .scaledScreenSize:
                return LocalizationKeys.capturePixelModeScaled.localized
            }
        }
    }

    final class AppSettings: ObservableObject {
        static let shared = AppSettings()
        private static let screenshotsDirectoryName = "Klapok Screenshots"
        private static let videosDirectoryName = "Klapok Videos"
        private static let saveDirectoryPathKey = "saveDirectory"
        private static let saveDirectoryBookmarkKey = "saveDirectoryBookmark"
        private static let videoSaveDirectoryPathKey = "videoSaveDirectory"
        private static let videoSaveDirectoryBookmarkKey = "videoSaveDirectoryBookmark"
        private static let supportedVideoResolutions = ["Source", "1080p", "720p", "480p"]
        private static let supportedVideoFrameRates = [24, 25, 30, 60]
        private static let supportedVideoCodecs = ["H.264", "H.265"]
        private static let supportedVideoFormats = ["MP4", "MOV"]

        // MARK: - Published Properties

        @Published var saveDirectory: URL {
            didSet {
                Self.persistDirectory(
                    saveDirectory,
                    pathKey: Self.saveDirectoryPathKey,
                    bookmarkKey: Self.saveDirectoryBookmarkKey
                )
            }
        }

        @Published var fileNameTemplate: String {
            didSet {
                UserDefaults.standard.set(fileNameTemplate, forKey: "fileNameTemplate")
            }
        }

        @Published var screenshotReviewPosition: ScreenshotReviewPosition {
            didSet {
                UserDefaults.standard.set(screenshotReviewPosition.rawValue, forKey: "screenshotReviewPosition")
            }
        }

        @Published var capturePixelMode: CapturePixelMode {
            didSet {
                UserDefaults.standard.set(capturePixelMode.rawValue, forKey: "capturePixelMode")
            }
        }

        @Published var defaultCaptureType: CaptureType {
            didSet {
                UserDefaults.standard.set(defaultCaptureType.rawValue, forKey: "defaultCaptureType")
            }
        }

        @Published var areaSelectionLockEnabled: Bool {
            didSet {
                UserDefaults.standard.set(areaSelectionLockEnabled, forKey: "areaSelectionLockEnabled")
            }
        }

        @Published private(set) var lastAreaSelectionRect: NSRect? {
            didSet {
                guard let rect = lastAreaSelectionRect, !rect.isEmpty else {
                    UserDefaults.standard.removeObject(forKey: "lastAreaSelectionRect")
                    return
                }

                UserDefaults.standard.set(NSStringFromRect(rect), forKey: "lastAreaSelectionRect")
            }
        }

        @Published var showInDock: Bool {
            didSet {
                UserDefaults.standard.set(showInDock, forKey: "showInDock")
                updateDockVisibility()
            }
        }

        @Published var videoSaveDirectory: URL {
            didSet {
                Self.persistDirectory(
                    videoSaveDirectory,
                    pathKey: Self.videoSaveDirectoryPathKey,
                    bookmarkKey: Self.videoSaveDirectoryBookmarkKey
                )
            }
        }

        @Published var videoFileNameTemplate: String {
            didSet {
                UserDefaults.standard.set(videoFileNameTemplate, forKey: "videoFileNameTemplate")
            }
        }
        
        // Video Quality Settings
        @Published var videoResolution: String {
            didSet {
                let normalizedValue = Self.normalizedVideoResolution(videoResolution)
                if videoResolution != normalizedValue {
                    videoResolution = normalizedValue
                    return
                }
                UserDefaults.standard.set(normalizedValue, forKey: "videoResolution")
            }
        }
        
        @Published var videoFrameRate: Int {
            didSet {
                let normalizedValue = Self.normalizedVideoFrameRate(videoFrameRate)
                if videoFrameRate != normalizedValue {
                    videoFrameRate = normalizedValue
                    return
                }
                UserDefaults.standard.set(normalizedValue, forKey: "videoFrameRate")
            }
        }
        
        @Published var videoBitrate: Int {
            didSet {
                let normalizedValue = Self.normalizedVideoBitrate(videoBitrate)
                if videoBitrate != normalizedValue {
                    videoBitrate = normalizedValue
                    return
                }
                UserDefaults.standard.set(normalizedValue, forKey: "videoBitrate")
            }
        }
        
        @Published var videoCodec: String {
            didSet {
                let normalizedValue = Self.normalizedVideoCodec(videoCodec)
                if videoCodec != normalizedValue {
                    videoCodec = normalizedValue
                    return
                }
                UserDefaults.standard.set(normalizedValue, forKey: "videoCodec")
            }
        }
        
        @Published var videoFormat: String {
            didSet {
                let normalizedValue = Self.normalizedVideoFormat(videoFormat)
                if videoFormat != normalizedValue {
                    videoFormat = normalizedValue
                    return
                }
                UserDefaults.standard.set(normalizedValue, forKey: "videoFormat")
            }
        }
        
        // Video Recording Behavior
        @Published var showMouseCursor: Bool {
            didSet {
                UserDefaults.standard.set(showMouseCursor, forKey: "showMouseCursor")
            }
        }
        
        @Published var recordSystemAudio: Bool {
            didSet {
                UserDefaults.standard.set(recordSystemAudio, forKey: "recordSystemAudio")
            }
        }

        @Published var screenshotShowsMouseCursor: Bool {
            didSet {
                UserDefaults.standard.set(screenshotShowsMouseCursor, forKey: "screenshotShowsMouseCursor")
            }
        }

        @Published var enableRecordingCountdown: Bool {
            didSet {
                UserDefaults.standard.set(enableRecordingCountdown, forKey: "enableRecordingCountdown")
            }
        }

        @Published var recordingCountdownSeconds: Int {
            didSet {
                let clampedValue = min(max(recordingCountdownSeconds, 1), 30)
                if recordingCountdownSeconds != clampedValue {
                    recordingCountdownSeconds = clampedValue
                    return
                }
                UserDefaults.standard.set(clampedValue, forKey: "recordingCountdownSeconds")
            }
        }

        // MARK: - Computed Properties

        var formattedFileName: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateString = formatter.string(from: Date())

            return
                fileNameTemplate
                .replacingOccurrences(of: "{datetime}", with: dateString)
                .replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
        }

        var formattedVideoFileName: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let dateString = formatter.string(from: Date())

            return
                videoFileNameTemplate
                .replacingOccurrences(of: "{datetime}", with: dateString)
                .replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
        }
        
        // Computed properties for UI bindings
        var videoFrameRateString: String {
            get { String(videoFrameRate) }
            set { videoFrameRate = Int(newValue) ?? 30 }
        }
        
        var videoBitrateString: String {
            get { 
                if videoBitrate >= 1000000 {
                    return "\(videoBitrate / 1000000) Mbps"
                } else {
                    return "\(videoBitrate / 1000) kbps"
                }
            }
            set {
                if newValue.contains("Mbps") {
                    let value = newValue.replacingOccurrences(of: " Mbps", with: "")
                    videoBitrate = (Int(value) ?? 5) * 1000000
                } else if newValue.contains("kbps") {
                    let value = newValue.replacingOccurrences(of: " kbps", with: "")
                    videoBitrate = (Int(value) ?? 5000) * 1000
                } else {
                    videoBitrate = Int(newValue) ?? 5000000
                }
            }
        }

        var normalizedVideoQuality: VideoQuality {
            VideoQuality.fromBitrate(videoBitrate)
        }

        // MARK: - Initialization

        private init() {
            Self.removeLegacySettings()
            self.saveDirectory = Self.storedDirectory(
                pathKey: Self.saveDirectoryPathKey,
                bookmarkKey: Self.saveDirectoryBookmarkKey,
                fallback: Self.defaultSaveDirectory
            )
            self.videoSaveDirectory = Self.storedDirectory(
                pathKey: Self.videoSaveDirectoryPathKey,
                bookmarkKey: Self.videoSaveDirectoryBookmarkKey,
                fallback: Self.defaultVideoSaveDirectory
            )
            
            self.fileNameTemplate =
                UserDefaults.standard.string(forKey: "fileNameTemplate") ?? "Screenshot-{datetime}"
            self.screenshotReviewPosition = ScreenshotReviewPosition(
                rawValue: UserDefaults.standard.string(forKey: "screenshotReviewPosition") ?? ""
            ) ?? .bottomRight
            self.capturePixelMode = CapturePixelMode(
                rawValue: UserDefaults.standard.string(forKey: "capturePixelMode") ?? ""
            ) ?? .realPixels
            self.defaultCaptureType = CaptureType(
                rawValue: UserDefaults.standard.string(forKey: "defaultCaptureType") ?? ""
            ) ?? .fullScreen
            self.areaSelectionLockEnabled = UserDefaults.standard.object(forKey: "areaSelectionLockEnabled") as? Bool ?? false
            if
                let storedRect = UserDefaults.standard.string(forKey: "lastAreaSelectionRect"),
                !storedRect.isEmpty
            {
                let rect = NSRectFromString(storedRect)
                self.lastAreaSelectionRect = rect.isEmpty ? nil : rect
            } else {
                self.lastAreaSelectionRect = nil
            }
            self.videoFileNameTemplate =
                UserDefaults.standard.string(forKey: "videoFileNameTemplate") ?? "Video-{datetime}"
            
            // Initialize video settings with defaults
            self.videoResolution = UserDefaults.standard.string(forKey: "videoResolution") ?? "Source"
            self.videoFrameRate = UserDefaults.standard.object(forKey: "videoFrameRate") as? Int ?? 30
            self.videoBitrate = UserDefaults.standard.object(forKey: "videoBitrate") as? Int ?? 5000000 // 5 Mbps
            self.videoCodec = UserDefaults.standard.string(forKey: "videoCodec") ?? "H.264"
            self.videoFormat = UserDefaults.standard.string(forKey: "videoFormat") ?? "MP4"
            
            // Initialize video behavior settings
            self.showMouseCursor = UserDefaults.standard.object(forKey: "showMouseCursor") as? Bool ?? false
            self.recordSystemAudio = UserDefaults.standard.object(forKey: "recordSystemAudio") as? Bool ?? false
            self.screenshotShowsMouseCursor = UserDefaults.standard.object(forKey: "screenshotShowsMouseCursor") as? Bool ?? false
            self.enableRecordingCountdown = UserDefaults.standard.object(forKey: "enableRecordingCountdown") as? Bool ?? false
            let storedCountdownSeconds = UserDefaults.standard.object(forKey: "recordingCountdownSeconds") as? Int ?? 3
            self.recordingCountdownSeconds = min(max(storedCountdownSeconds, 1), 30)
            self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
            normalizeVideoSettingsValues()

            try? CaptureFileStore.ensureDirectory(saveDirectory, securityScoped: true)
            try? CaptureFileStore.ensureDirectory(videoSaveDirectory, securityScoped: true)
        }

        // MARK: - Public Methods

        func resetToDefaults() {
            saveDirectory = Self.defaultSaveDirectory
            fileNameTemplate = "Screenshot-{datetime}"
            screenshotReviewPosition = .bottomRight
            capturePixelMode = .realPixels
            defaultCaptureType = .fullScreen
            areaSelectionLockEnabled = false
            lastAreaSelectionRect = nil
            videoSaveDirectory = Self.defaultVideoSaveDirectory
            videoFileNameTemplate = "Video-{datetime}"
            
            // Clear any saved paths from UserDefaults
            UserDefaults.standard.removeObject(forKey: Self.saveDirectoryPathKey)
            UserDefaults.standard.removeObject(forKey: Self.saveDirectoryBookmarkKey)
            UserDefaults.standard.removeObject(forKey: Self.videoSaveDirectoryPathKey)
            UserDefaults.standard.removeObject(forKey: Self.videoSaveDirectoryBookmarkKey)
            UserDefaults.standard.removeObject(forKey: "screenshotReviewPosition")
            UserDefaults.standard.removeObject(forKey: "areaSelectionLockEnabled")
            UserDefaults.standard.removeObject(forKey: "lastAreaSelectionRect")
            
            // Reset video settings to defaults
            videoResolution = "Source"
            videoFrameRate = 30
            videoBitrate = 5000000 // 5 Mbps
            videoCodec = "H.264"
            videoFormat = "MP4"
            
            // Reset video behavior settings
            showMouseCursor = false
            recordSystemAudio = false
            screenshotShowsMouseCursor = false
            enableRecordingCountdown = false
            recordingCountdownSeconds = 3
            showInDock = true
            DispatchQueue.main.async { AppIconManager.shared.select(.roostersLight) }
        }

        func applyVideoQuality(_ quality: VideoQuality) {
            videoBitrate = quality.bitrate
        }

        func rememberAreaSelection(_ rect: NSRect) {
            let normalizedRect = rect.standardized
            guard !normalizedRect.isEmpty else { return }
            lastAreaSelectionRect = normalizedRect
        }

        func applyDockVisibility() {
            updateDockVisibility()
        }

        func saveScreenshot(_ image: NSImage) -> URL? {
            let fileName = formattedFileName + ".png"
            guard let result = CaptureFileStore.saveScreenshot(
                image,
                fileName: fileName,
                primaryDirectory: saveDirectory,
                fallbackDirectory: Self.defaultSaveDirectory,
                securityScoped: true
            ) else {
                return nil
            }

            saveDirectory = result.directory
            return result.url
        }

        func saveVideo(_ videoURL: URL) -> URL? {
            let fileName = formattedVideoFileName + ".\(videoFormat.lowercased())"
            guard let result = CaptureFileStore.saveVideo(
                videoURL,
                fileName: fileName,
                primaryDirectory: videoSaveDirectory,
                fallbackDirectory: Self.defaultVideoSaveDirectory
            ) else {
                return nil
            }

            videoSaveDirectory = result.directory
            return result.url
        }

        // MARK: - Private Methods

        private static var documentsDirectory: URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }

        private static var defaultSaveDirectory: URL {
            documentsDirectory.appendingPathComponent(screenshotsDirectoryName)
        }

        private static var defaultVideoSaveDirectory: URL {
            documentsDirectory.appendingPathComponent(videosDirectoryName)
        }

        private static func storedDirectory(pathKey: String, bookmarkKey: String, fallback: URL) -> URL {
            if
                let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey),
                let resolvedURL = resolveDirectoryBookmark(
                    bookmarkData,
                    pathKey: pathKey,
                    bookmarkKey: bookmarkKey
                )
            {
                return resolvedURL
            }

            guard
                let savedPath = UserDefaults.standard.string(forKey: pathKey),
                !savedPath.isEmpty
            else {
                return fallback
            }

            return URL(fileURLWithPath: savedPath)
        }

        private static func persistDirectory(_ directory: URL, pathKey: String, bookmarkKey: String) {
            UserDefaults.standard.set(directory.path, forKey: pathKey)
            try? CaptureFileStore.ensureDirectory(directory, securityScoped: true)

            let bookmarkData =
                (try? directory.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ))
                ?? (try? directory.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ))

            guard let bookmarkData else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return
            }

            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        }

        private static func resolveDirectoryBookmark(
            _ bookmarkData: Data,
            pathKey: String,
            bookmarkKey: String
        ) -> URL? {
            var isStale = false
            guard let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return nil
            }

            if isStale {
                persistDirectory(resolvedURL, pathKey: pathKey, bookmarkKey: bookmarkKey)
            }

            return resolvedURL
        }

        private func normalizeVideoSettingsValues() {
            videoResolution = Self.normalizedVideoResolution(videoResolution)
            videoFrameRate = Self.normalizedVideoFrameRate(videoFrameRate)
            videoBitrate = Self.normalizedVideoBitrate(videoBitrate)
            videoCodec = Self.normalizedVideoCodec(videoCodec)
            videoFormat = Self.normalizedVideoFormat(videoFormat)
        }

        private static func normalizedVideoResolution(_ value: String) -> String {
            supportedVideoResolutions.contains(value) ? value : "Source"
        }

        private static func normalizedVideoFrameRate(_ value: Int) -> Int {
            supportedVideoFrameRates.min { lhs, rhs in
                abs(lhs - value) < abs(rhs - value)
            } ?? 30
        }

        private static func normalizedVideoBitrate(_ value: Int) -> Int {
            max(100_000, min(50_000_000, value))
        }

        private static func normalizedVideoCodec(_ value: String) -> String {
            supportedVideoCodecs.contains(value) ? value : "H.264"
        }

        private static func normalizedVideoFormat(_ value: String) -> String {
            supportedVideoFormats.contains(value) ? value : "MP4"
        }

        private static func removeLegacySettings() {
            UserDefaults.standard.removeObject(forKey: "hotkeyModifiers")
            UserDefaults.standard.removeObject(forKey: "hotkeyKeyCode")
            UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        }

        private func updateDockVisibility() {
            DispatchQueue.main.async {
                let visibleWindows = NSApp.windows.filter { $0.isVisible }

                if self.showInDock {
                    NSApp.setActivationPolicy(.regular)
                } else {
                    NSApp.setActivationPolicy(.accessory)
                }

                AppIconManager.shared.applySavedIcon()

                visibleWindows.forEach { window in
                    if window.canBecomeKey { window.makeKeyAndOrderFront(nil) }
                    window.orderFrontRegardless()
                }
            }
        }
    }

#endif
