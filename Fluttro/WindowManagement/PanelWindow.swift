//
//  PanelWindow.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import Cocoa

class PanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}
