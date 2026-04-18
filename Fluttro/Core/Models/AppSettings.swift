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
        
        @Published var recordMicrophone: Bool {
            didSet {
                UserDefaults.standard.set(recordMicrophone, forKey: "recordMicrophone")
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
            // Load saved settings or use defaults
            // Use container's Documents directory for sandboxed apps
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            
            print("AppSettings: Documents path: \(documentsPath.path)")
            
            let defaultSaveDirectory = documentsPath.appendingPathComponent("Fluttro Screenshots")
            let defaultVideoSaveDirectory = documentsPath.appendingPathComponent("Fluttro Videos")

            // For sandboxed apps, always use paths within the container
            // Check if we have a saved path and if it's within the container
            if let savedPath = UserDefaults.standard.string(forKey: "saveDirectory"),
               let savedURL = URL(string: savedPath),
               savedURL.path.contains("/Library/Containers/") {
                self.saveDirectory = savedURL
            } else {
                // Use default path within container
                self.saveDirectory = defaultSaveDirectory
                // Clear old invalid path
                UserDefaults.standard.removeObject(forKey: "saveDirectory")
            }
            
            if let savedPath = UserDefaults.standard.string(forKey: "videoSaveDirectory"),
               let savedURL = URL(string: savedPath),
               savedURL.path.contains("/Library/Containers/") {
                self.videoSaveDirectory = savedURL
            } else {
                // Use default path within container
                self.videoSaveDirectory = defaultVideoSaveDirectory
                // Clear old invalid path
                UserDefaults.standard.removeObject(forKey: "videoSaveDirectory")
            }
            
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
            self.recordMicrophone = UserDefaults.standard.object(forKey: "recordMicrophone") as? Bool ?? false
            self.hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt
                    ?? (NSEvent.ModifierFlags.command.rawValue
                        | NSEvent.ModifierFlags.shift.rawValue))
            self.hotkeyKeyCode = UInt16(
                UserDefaults.standard.integer(forKey: "hotkeyKeyCode") != 0
                    ? UserDefaults.standard.integer(forKey: "hotkeyKeyCode") : 0x1A)  // Default: Cmd+Shift+]
            self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
            self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

            // Create save directories if they don't exist
            createSaveDirectoryIfNeeded()
            createVideoSaveDirectoryIfNeeded()
        }

        // MARK: - Public Methods

        func resetToDefaults() {
            // Use container's Documents directory for sandboxed apps
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let defaultSaveDirectory = documentsPath.appendingPathComponent("Fluttro Screenshots")
            let defaultVideoSaveDirectory = documentsPath.appendingPathComponent("Fluttro Videos")

            saveDirectory = defaultSaveDirectory
            fileNameTemplate = "Screenshot-{datetime}"
            screenshotReviewPosition = .bottomRight
            capturePixelMode = .realPixels
            defaultCaptureType = .fullScreen
            videoSaveDirectory = defaultVideoSaveDirectory
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
            recordMicrophone = false
            
            hotkeyModifiers = [.command, .shift]
            hotkeyKeyCode = 0x1A
            showInDock = true
            launchAtLogin = false
        }

        func applyDockVisibility() {
            updateDockVisibility()
        }

        func saveScreenshot(_ image: NSImage) -> URL? {
            print("AppSettings: Current saveDirectory: \(saveDirectory.path)")
            
            // Try to save to the current directory first
            if let result = trySaveScreenshot(to: saveDirectory, image: image) {
                return result
            }
            
            // If that fails, try to save to the default directory inside sandbox
            print("AppSettings: Failed to save to current directory, trying default directory...")
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let defaultSaveDirectory = documentsPath.appendingPathComponent("Fluttro Screenshots")
            
            if let result = trySaveScreenshot(to: defaultSaveDirectory, image: image) {
                // Update the saved directory to the working one
                saveDirectory = defaultSaveDirectory
                print("AppSettings: Updated saveDirectory to default: \(defaultSaveDirectory.path)")
                return result
            }
            
            print("AppSettings: Failed to save screenshot to both directories")
            return nil
        }
        
        private func trySaveScreenshot(to directory: URL, image: NSImage) -> URL? {
            createSaveDirectoryIfNeeded(for: directory)
            
            let fileName = formattedFileName + ".png"
            let fileURL = directory.appendingPathComponent(fileName)
            print("AppSettings: Trying to save to: \(fileURL.path)")

            guard let tiffData = image.tiffRepresentation,
                let bitmapRep = NSBitmapImageRep(data: tiffData),
                let pngData = bitmapRep.representation(using: .png, properties: [:])
            else {
                print("AppSettings: Failed to convert image to PNG")
                return nil
            }

            do {
                try pngData.write(to: fileURL)
                print("AppSettings: Screenshot saved to: \(fileURL.path)")
                return fileURL
            } catch {
                print("AppSettings: Failed to save screenshot to \(directory.path): \(error)")
                return nil
            }
        }

        func saveVideo(_ videoURL: URL) -> URL? {
            print("AppSettings: Current videoSaveDirectory: \(videoSaveDirectory.path)")
            
            // Try to save to the current directory first
            if let result = trySaveVideo(to: videoSaveDirectory, videoURL: videoURL) {
                return result
            }
            
            // If that fails, try to save to the default directory inside sandbox
            print("AppSettings: Failed to save to current directory, trying default directory...")
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let defaultVideoSaveDirectory = documentsPath.appendingPathComponent("Fluttro Videos")
            
            if let result = trySaveVideo(to: defaultVideoSaveDirectory, videoURL: videoURL) {
                // Update the saved directory to the working one
                videoSaveDirectory = defaultVideoSaveDirectory
                print("AppSettings: Updated videoSaveDirectory to default: \(defaultVideoSaveDirectory.path)")
                return result
            }
            
            print("AppSettings: Failed to save video to both directories")
            return nil
        }
        
        private func trySaveVideo(to directory: URL, videoURL: URL) -> URL? {
            createVideoSaveDirectoryIfNeeded(for: directory)
            
            // Get file extension based on video format
            let fileExtension = videoFormat.lowercased()
            let fileName = formattedVideoFileName + ".\(fileExtension)"
            let destinationURL = directory.appendingPathComponent(fileName)
            print("AppSettings: Trying to save video to: \(destinationURL.path)")
            
            do {
                // If destination exists, remove it first
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Check if we need to access security-scoped resource
                let needsSecurityScopedAccess = !directory.startAccessingSecurityScopedResource()
                
                // Copy the video file to the destination
                try FileManager.default.copyItem(at: videoURL, to: destinationURL)
                
                // Stop accessing security-scoped resource if we started it
                if !needsSecurityScopedAccess {
                    directory.stopAccessingSecurityScopedResource()
                }
                
                print("AppSettings: Video saved to: \(destinationURL.path)")
                return destinationURL
            } catch {
                // Stop accessing security-scoped resource on error
                if directory.startAccessingSecurityScopedResource() {
                    directory.stopAccessingSecurityScopedResource()
                }
                
                print("AppSettings: Failed to save video to \(directory.path): \(error)")
                return nil
            }
        }

        // MARK: - Private Methods

        private func createSaveDirectoryIfNeeded() {
            createSaveDirectoryIfNeeded(for: saveDirectory)
        }
        
        private func createSaveDirectoryIfNeeded(for directory: URL) {
            print("AppSettings: Checking if directory exists: \(directory.path)")
            if !FileManager.default.fileExists(atPath: directory.path) {
                print("AppSettings: Directory does not exist, creating...")
                do {
                    try FileManager.default.createDirectory(
                        at: directory, withIntermediateDirectories: true)
                    print("AppSettings: Successfully created save directory: \(directory.path)")
                } catch {
                    print("AppSettings: Failed to create save directory: \(error)")
                }
            } else {
                print("AppSettings: Directory already exists: \(directory.path)")
            }
        }

        private func createVideoSaveDirectoryIfNeeded() {
            createVideoSaveDirectoryIfNeeded(for: videoSaveDirectory)
        }
        
        private func createVideoSaveDirectoryIfNeeded(for directory: URL) {
            print("AppSettings: Checking if video directory exists: \(directory.path)")
            
            // Check if we need to access security-scoped resource
            let needsSecurityScopedAccess = !directory.startAccessingSecurityScopedResource()
            
            defer {
                // Stop accessing security-scoped resource if we started it
                if !needsSecurityScopedAccess {
                    directory.stopAccessingSecurityScopedResource()
                }
            }
            
            if !FileManager.default.fileExists(atPath: directory.path) {
                print("AppSettings: Video directory does not exist, creating...")
                do {
                    try FileManager.default.createDirectory(
                        at: directory, withIntermediateDirectories: true)
                    print("AppSettings: Successfully created video save directory: \(directory.path)")
                } catch {
                    print("AppSettings: Failed to create video save directory: \(error)")
                }
            } else {
                print("AppSettings: Video directory already exists: \(directory.path)")
            }
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
            // Implementation for launch at login
            // This would typically use LaunchServices or LoginItems
            print("AppSettings: Launch at login set to: \(launchAtLogin)")
            // TODO: Implement actual launch at login functionality
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
