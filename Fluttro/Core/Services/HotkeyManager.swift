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

/// Manages global hotkeys using Carbon APIs.
final class HotkeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotKeyEventHandler: EventHandlerRef?
    private let handlerQueue: DispatchQueue
    private var hotkeyHandlers: [UInt32: () -> Void] = [:]

    init(handlerQueue: DispatchQueue = .main) {
        self.handlerQueue = handlerQueue
    }

    deinit {
        unregister()
    }

    /// Registers a global hotkey.
    /// - Parameters:
    ///   - id: stable identifier for this hotkey.
    ///   - keyCode: kVK_... from Carbon (e.g. kVK_ANSI_7)
    ///   - modifiers: combination of cmd/option/control/shift using Carbon masks
    ///   - onTrigger: callback fired when hotkey is pressed
    /// - Returns: true if registration succeeded
    @discardableResult
    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        unregister(id: id)
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let unmanaged = Unmanaged<HotkeyManager>.fromOpaque(userData)
            let manager = unmanaged.takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return noErr }

            manager.handlerQueue.async {
                manager.hotkeyHandlers[hotKeyID.id]?()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        if hotKeyEventHandler == nil {
            let installStatus = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, selfPtr, &hotKeyEventHandler)
            guard installStatus == noErr else {
                return false
            }
        }

        let hotKeyID = EventHotKeyID(signature: OSType("FLTR".fourCharCode), id: id)
        var hotKeyRef: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard regStatus == noErr else {
            if hotKeyRefs.isEmpty, let hotKeyEventHandler {
                RemoveEventHandler(hotKeyEventHandler)
                self.hotKeyEventHandler = nil
            }
            return false
        }

        hotKeyRefs[id] = hotKeyRef
        hotkeyHandlers[id] = onTrigger
        return true
    }

    /// Registers a single global hotkey, replacing any existing hotkeys.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) -> Bool {
        unregister()
        return register(id: 1, keyCode: keyCode, modifiers: modifiers, onTrigger: onTrigger)
    }

    /// Unregisters a global hotkey.
    func unregister(id: UInt32) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotkeyHandlers[id] = nil

        if hotKeyRefs.isEmpty, let hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
            self.hotKeyEventHandler = nil
        }
    }

    /// Unregisters all global hotkeys and removes the event handler.
    func unregister() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        hotkeyHandlers.removeAll()
        if let hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
            self.hotKeyEventHandler = nil
        }
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
