//
//  AppSettings.swift
//  Fluttro
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
        private static let screenshotsDirectoryName = "Fluttro Screenshots"
        private static let videosDirectoryName = "Fluttro Videos"

        // MARK: - Published Properties

        @Published var saveDirectory: URL {
            didSet {
                UserDefaults.standard.set(saveDirectory.path, forKey: "saveDirectory")
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

        @Published var hotkeyModifiers: NSEvent.ModifierFlags {
            didSet {
                UserDefaults.standard.set(hotkeyModifiers.rawValue, forKey: "hotkeyModifiers")
            }
        }

        @Published var hotkeyKeyCode: UInt16 {
            didSet {
                UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
            }
        }

        @Published var showInDock: Bool {
            didSet {
                UserDefaults.standard.set(showInDock, forKey: "showInDock")
                updateDockVisibility()
            }
        }

        @Published var launchAtLogin: Bool {
            didSet {
                UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
                updateLaunchAtLogin()
            }
        }

        @Published var videoSaveDirectory: URL {
            didSet {
                UserDefaults.standard.set(videoSaveDirectory.path, forKey: "videoSaveDirectory")
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
                UserDefaults.standard.set(videoResolution, forKey: "videoResolution")
            }
        }
        
        @Published var videoFrameRate: Int {
            didSet {
                UserDefaults.standard.set(videoFrameRate, forKey: "videoFrameRate")
            }
        }
        
        @Published var videoBitrate: Int {
            didSet {
                UserDefaults.standard.set(videoBitrate, forKey: "videoBitrate")
            }
        }
        
        @Published var videoCodec: String {
            didSet {
                UserDefaults.standard.set(videoCodec, forKey: "videoCodec")
            }
        }
        
        @Published var videoFormat: String {
            didSet {
                UserDefaults.standard.set(videoFormat, forKey: "videoFormat")
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

        var hotkeyDisplayString: String {
            var components: [String] = []

            if hotkeyModifiers.contains(.command) { components.append("⌘") }
            if hotkeyModifiers.contains(.option) { components.append("⌥") }
            if hotkeyModifiers.contains(.control) { components.append("⌃") }
            if hotkeyModifiers.contains(.shift) { components.append("⇧") }

            // Convert key code to character
            let keyString = keyCodeToString(hotkeyKeyCode)
            components.append(keyString)

            return components.joined()
        }

        // MARK: - Initialization

        private init() {
            self.saveDirectory = Self.storedDirectory(
                forKey: "saveDirectory",
                fallback: Self.defaultSaveDirectory
            )
            self.videoSaveDirectory = Self.storedDirectory(
                forKey: "videoSaveDirectory",
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
            self.hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt
                    ?? (NSEvent.ModifierFlags.command.rawValue
                        | NSEvent.ModifierFlags.shift.rawValue))
            self.hotkeyKeyCode = UInt16(
                UserDefaults.standard.integer(forKey: "hotkeyKeyCode") != 0
                    ? UserDefaults.standard.integer(forKey: "hotkeyKeyCode") : 0x1A)  // Default: Cmd+Shift+]
            self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
            self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

            try? CaptureFileStore.ensureDirectory(saveDirectory)
            try? CaptureFileStore.ensureDirectory(videoSaveDirectory, securityScoped: true)
        }

        // MARK: - Public Methods

        func resetToDefaults() {
            saveDirectory = Self.defaultSaveDirectory
            fileNameTemplate = "Screenshot-{datetime}"
            screenshotReviewPosition = .bottomRight
            capturePixelMode = .realPixels
            defaultCaptureType = .fullScreen
            videoSaveDirectory = Self.defaultVideoSaveDirectory
            videoFileNameTemplate = "Video-{datetime}"
            
            // Clear any saved paths from UserDefaults
            UserDefaults.standard.removeObject(forKey: "saveDirectory")
            UserDefaults.standard.removeObject(forKey: "videoSaveDirectory")
            UserDefaults.standard.removeObject(forKey: "screenshotReviewPosition")
            
            // Reset video settings to defaults
            videoResolution = "Source"
            videoFrameRate = 30
            videoBitrate = 5000000 // 5 Mbps
            videoCodec = "H.264"
            videoFormat = "MP4"
            
            // Reset video behavior settings
            showMouseCursor = false
            recordSystemAudio = false
            
            hotkeyModifiers = [.command, .shift]
            hotkeyKeyCode = 0x1A
            showInDock = true
            launchAtLogin = false
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
                fallbackDirectory: Self.defaultSaveDirectory
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

        private static func storedDirectory(forKey key: String, fallback: URL) -> URL {
            guard let savedPath = UserDefaults.standard.string(forKey: key) else {
                return fallback
            }

            let savedURL = URL(fileURLWithPath: savedPath)
            guard savedURL.path.contains("/Library/Containers/") else {
                UserDefaults.standard.removeObject(forKey: key)
                return fallback
            }

            return savedURL
        }

        private func updateDockVisibility() {
            DispatchQueue.main.async {
                let visibleWindows = NSApp.windows.filter { $0.isVisible }

                if self.showInDock {
                    NSApp.setActivationPolicy(.regular)
                } else {
                    NSApp.setActivationPolicy(.accessory)
                }

                visibleWindows.forEach { window in
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        }

        private func updateLaunchAtLogin() {
            // Stored for the settings UI; login item registration is not wired yet.
        }

        private func keyCodeToString(_ keyCode: UInt16) -> String {
            switch keyCode {
            case 0x1A: return "]"
            case 0x1B: return "-"
            case 0x18: return "="
            case 0x0C: return "Q"
            case 0x0D: return "W"
            case 0x0E: return "E"
            case 0x0F: return "R"
            case 0x11: return "T"
            case 0x10: return "Y"
            case 0x20: return "U"
            case 0x22: return "I"
            case 0x1F: return "O"
            case 0x23: return "P"
            case 0x00: return "A"
            case 0x01: return "S"
            case 0x02: return "D"
            case 0x03: return "F"
            case 0x05: return "G"
            case 0x04: return "H"
            case 0x26: return "J"
            case 0x28: return "K"
            case 0x25: return "L"
            case 0x06: return "Z"
            case 0x07: return "X"
            case 0x08: return "C"
            case 0x09: return "V"
            case 0x0B: return "B"
            case 0x2D: return "N"
            case 0x2E: return "M"
            case 0x31: return "Space"
            case 0x35: return "Esc"
            default: return "Key\(keyCode)"
            }
        }
    }

#endif
