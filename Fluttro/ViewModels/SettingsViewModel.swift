//
//  SettingsViewModel.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import Foundation
#if os(macOS)
import AppKit

final class SettingsViewModel {
    @Published var showMouseCursor: Bool = false
}

#endif
