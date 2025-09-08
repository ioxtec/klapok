//
//  HotkeyManager.swift
//  Fluttro
//
//  A lightweight wrapper around Carbon's RegisterEventHotKey for a global hotkey.
//

import Foundation
#if os(macOS)
import AppKit
import Carbon.HIToolbox

/// Manages a single global hotkey using Carbon APIs.
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyEventHandler: EventHandlerRef?
    private let handlerQueue: DispatchQueue
    private var onHotkey: (() -> Void)?

    init(handlerQueue: DispatchQueue = .main) {
        self.handlerQueue = handlerQueue
    }

    deinit {
        unregister()
    }

    /// Registers a global hotkey.
    /// - Parameters:
    ///   - keyCode: kVK_... from Carbon (e.g. kVK_ANSI_7)
    ///   - modifiers: combination of cmd/option/control/shift using Carbon masks
    ///   - onTrigger: callback fired when hotkey is pressed
    /// - Returns: true if registration succeeded
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        unregister()

        self.onHotkey = onTrigger

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let unmanaged = Unmanaged<HotkeyManager>.fromOpaque(userData)
            let manager = unmanaged.takeUnretainedValue()
            manager.handlerQueue.async {
                manager.onHotkey?()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPtr, &hotKeyEventHandler)
        guard installStatus == noErr else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType("FLTR".fourCharCode), id: 1)
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard regStatus == noErr else {
            if let hotKeyEventHandler {
                RemoveEventHandler(hotKeyEventHandler)
                self.hotKeyEventHandler = nil
            }
            return false
        }

        return true
    }

    /// Unregisters the current global hotkey and removes the event handler.
    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
            self.hotKeyEventHandler = nil
        }
        onHotkey = nil
    }
}

private extension String {
    /// Converts a 4-char string to a FourCharCode.
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in utf16 {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}

#endif

