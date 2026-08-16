//
//  SettingsView.swift
//  Klapok
//
//  Created by Marcin Ryzko on 09/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewState = SettingsViewState()

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case image = "Image"
        case video = "Video"
        case shortcuts = "Shortcuts"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                return "General"
            case .image:
                return "Image"
            case .video:
                return "Video"
            case .shortcuts:
                return "Shortcuts"
            }
        }

        var systemImage: String {
            switch self {
            case .general:
                return "gearshape"
            case .image:
                return "photo"
            case .video:
                return "video"
            case .shortcuts:
                return "keyboard"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabStrip(
                selectedTab: Binding(
                    get: { viewState.selectedTab },
                    set: { viewState.selectedTab = $0 }
                )
            )

            Divider()
                .opacity(0.45)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
        }
        .frame(minWidth: 820, idealWidth: 900, maxWidth: 1120, minHeight: 560, idealHeight: 640, maxHeight: 820)
    }

    private var selectedTab: SettingsTab {
        viewState.selectedTab
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .image:
            ImageSettingsView()
        case .video:
            VideoSettingsView()
        case .shortcuts:
            KeyboardShortcutsSettingsView()
        }
    }
}

@MainActor
private final class SettingsViewState: ObservableObject {
    @Published var selectedTab: SettingsView.SettingsTab = .general
}

private struct SettingsTabStrip: View {
    @Binding var selectedTab: SettingsView.SettingsTab

    var body: some View {
        VStack(spacing: 12) {
            Text(selectedTab.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityIdentifier("settings.title")

            HStack(spacing: 14) {
                ForEach(SettingsView.SettingsTab.allCases) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 25, weight: .regular))
                    .symbolVariant(isSelected ? .fill : .none)

                Text(tab.title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 92, height: 62)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.tab.\(tab.rawValue.lowercased())")
        .accessibilityValue(isSelected ? "selected" : "unselected")
    }
}
