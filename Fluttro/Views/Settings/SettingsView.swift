//
//  AppSettingView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI
import SwiftUICore

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Advanced", systemImage: "star") {
                AdvancedSettingsView()
            }
        }
        .scenePadding()
        .frame(
            minWidth: 500, idealWidth: 600, maxWidth: 800, minHeight: 400, idealHeight: 500,
            maxHeight: 700)
    }
}
