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
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let defaultSaveDirectory = documentsPath.appendingPathComponent("Fluttro Screenshots")

            self.saveDirectory = URL(
                fileURLWithPath: UserDefaults.standard.string(forKey: "saveDirectory")
                    ?? defaultSaveDirectory.path)
            self.fileNameTemplate =
                UserDefaults.standard.string(forKey: "fileNameTemplate") ?? "Screenshot-{datetime}"
            self.hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UserDefaults.standard.object(forKey: "hotkeyModifiers") as? UInt
                    ?? (NSEvent.ModifierFlags.command.rawValue
                        | NSEvent.ModifierFlags.shift.rawValue))
            self.hotkeyKeyCode = UInt16(
                UserDefaults.standard.integer(forKey: "hotkeyKeyCode") != 0
                    ? UserDefaults.standard.integer(forKey: "hotkeyKeyCode") : 0x1A)  // Default: Cmd+Shift+]
            self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
            self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

            // Create save directory if it doesn't exist
            createSaveDirectoryIfNeeded()
        }

        // MARK: - Public Methods

        func resetToDefaults() {
            let documentsPath = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            let defaultSaveDirectory = documentsPath.appendingPathComponent("Fluttro Screenshots")

            saveDirectory = defaultSaveDirectory
            fileNameTemplate = "Screenshot-{datetime}"
            hotkeyModifiers = [.command, .shift]
            hotkeyKeyCode = 0x1A
            showInDock = true
            launchAtLogin = false
        }

        func saveScreenshot(_ image: NSImage) -> URL? {
            createSaveDirectoryIfNeeded()

            let fileName = formattedFileName + ".png"
            let fileURL = saveDirectory.appendingPathComponent(fileName)

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
                print("AppSettings: Failed to save screenshot: \(error)")
                return nil
            }
        }

        // MARK: - Private Methods

        private func createSaveDirectoryIfNeeded() {
            if !FileManager.default.fileExists(atPath: saveDirectory.path) {
                do {
                    try FileManager.default.createDirectory(
                        at: saveDirectory, withIntermediateDirectories: true)
                    print("AppSettings: Created save directory: \(saveDirectory.path)")
                } catch {
                    print("AppSettings: Failed to create save directory: \(error)")
                }
            }
        }

        private func updateDockVisibility() {
            DispatchQueue.main.async {
                if self.showInDock {
                    NSApp.setActivationPolicy(.regular)
                } else {
                    NSApp.setActivationPolicy(.accessory)
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
