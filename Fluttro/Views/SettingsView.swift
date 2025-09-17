//
//  SettingsView.swift
//  Fluttro
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case image = "Image"
        case video = "Video"
        
        var systemImage: String {
            switch self {
            case .general: return "gear"
            case .image: return "photo"
            case .video: return "video"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle("Fluttro")
            .frame(minWidth: 200)
        } detail: {
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .image:
                    ImageSettingsView()
                case .video:
                    VideoSettingsView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .frame(minWidth: 600)
        }
        .frame(minWidth: 800, idealWidth: 900, maxWidth: 1200, minHeight: 500, idealHeight: 600, maxHeight: 800)
    }
}

#Preview {
    SettingsView()
}
