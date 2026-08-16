//
//  KeyboardShortcutAction.swift
//  Klapok
//
//  Shared definitions for global capture shortcuts.
//

import Foundation

#if os(macOS)
import AppKit
import Carbon.HIToolbox

struct KeyboardShortcutDefinition: Equatable {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        return result
    }

    var displayString: String {
        "\(modifierDisplayString)\(keyDisplayString)"
    }

    var keyEquivalent: String {
        keyDisplayString.lowercased()
    }

    var keyEquivalentModifierMask: NSEvent.ModifierFlags {
        modifiers.intersection([.command, .shift, .option, .control])
    }

    private var modifierDisplayString: String {
        var components: [String] = []
        if modifiers.contains(.command) {
            components.append("⌘")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        return components.joined()
    }

    private var keyDisplayString: String {
        switch Int(keyCode) {
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return "Key\(keyCode)"
        }
    }
}

enum KeyboardShortcutAction: UInt32, CaseIterable, Identifiable {
    case screenshotFullScreen = 101
    case screenshotArea = 102
    case screenshotWindow = 103
    case recordingFullScreen = 201
    case recordingArea = 202
    case recordingWindow = 203

    var id: UInt32 { rawValue }

    var mode: CaptureMode {
        switch self {
        case .screenshotFullScreen, .screenshotArea, .screenshotWindow:
            return .image
        case .recordingFullScreen, .recordingArea, .recordingWindow:
            return .video
        }
    }

    var captureType: CaptureType {
        switch self {
        case .screenshotFullScreen, .recordingFullScreen:
            return .fullScreen
        case .screenshotArea, .recordingArea:
            return .area
        case .screenshotWindow, .recordingWindow:
            return .window
        }
    }

    var title: String {
        switch self {
        case .screenshotFullScreen:
            return "Zrób zrzut całego ekranu"
        case .screenshotArea:
            return "Zrób zrzut fragmentu ekranu"
        case .screenshotWindow:
            return "Zrób zrzut okna aplikacji"
        case .recordingFullScreen:
            return "Nagraj cały ekran"
        case .recordingArea:
            return "Nagraj fragment ekranu"
        case .recordingWindow:
            return "Nagraj okno aplikacji"
        }
    }

    var description: String {
        switch self {
        case .screenshotFullScreen:
            return "Captures the full screen and opens the review overlay."
        case .screenshotArea:
            return "Lets you select an area, then captures it."
        case .screenshotWindow:
            return "Lets you select a window, then captures it."
        case .recordingFullScreen:
            return "Starts or stops full screen recording."
        case .recordingArea:
            return "Lets you select an area, then starts recording it."
        case .recordingWindow:
            return "Lets you select a window, then starts recording it."
        }
    }

    var defaultShortcut: KeyboardShortcutDefinition {
        switch self {
        case .screenshotFullScreen:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .shift])
        case .screenshotArea:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .shift])
        case .screenshotWindow:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .shift])
        case .recordingFullScreen:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .option])
        case .recordingArea:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .option])
        case .recordingWindow:
            return KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .option])
        }
    }

    var shortcut: KeyboardShortcutDefinition {
        let keyCodeKey = userDefaultsKey("keyCode")
        let modifiersKey = userDefaultsKey("modifiers")
        let storedKeyCode = UserDefaults.standard.object(forKey: keyCodeKey) as? Int
        let storedModifiers = UserDefaults.standard.object(forKey: modifiersKey) as? UInt

        return KeyboardShortcutDefinition(
            keyCode: storedKeyCode.map(UInt32.init) ?? defaultShortcut.keyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: storedModifiers ?? defaultShortcut.modifiers.rawValue)
        )
    }

    var keyCode: UInt32 {
        shortcut.keyCode
    }

    var carbonModifiers: UInt32 {
        shortcut.carbonModifiers
    }

    var displayShortcut: String {
        shortcut.displayString
    }

    var menuTitle: String {
        title
    }

    func setShortcut(_ shortcut: KeyboardShortcutDefinition) {
        UserDefaults.standard.set(Int(shortcut.keyCode), forKey: userDefaultsKey("keyCode"))
        UserDefaults.standard.set(shortcut.modifiers.rawValue, forKey: userDefaultsKey("modifiers"))
        NotificationCenter.default.post(name: .keyboardShortcutsChanged, object: self)
    }

    func resetShortcut() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey("keyCode"))
        UserDefaults.standard.removeObject(forKey: userDefaultsKey("modifiers"))
        NotificationCenter.default.post(name: .keyboardShortcutsChanged, object: self)
    }

    static func conflictingAction(for shortcut: KeyboardShortcutDefinition, excluding action: KeyboardShortcutAction) -> KeyboardShortcutAction? {
        allCases.first { candidate in
            candidate != action && candidate.shortcut == shortcut
        }
    }

    static func resetAllShortcuts() {
        allCases.forEach { $0.resetShortcut() }
        NotificationCenter.default.post(name: .keyboardShortcutsChanged, object: nil)
    }

    static var screenshotActions: [KeyboardShortcutAction] {
        [.screenshotFullScreen, .screenshotArea, .screenshotWindow]
    }

    static var recordingActions: [KeyboardShortcutAction] {
        [.recordingFullScreen, .recordingArea, .recordingWindow]
    }

    private func userDefaultsKey(_ suffix: String) -> String {
        "keyboardShortcut.\(rawValue).\(suffix)"
    }
}

extension Notification.Name {
    static let keyboardShortcutsChanged = Notification.Name("keyboardShortcutsChanged")
}

#endif
