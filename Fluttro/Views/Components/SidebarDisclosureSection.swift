//
//  SidebarDisclosureSection.swift
//  Fluttro
//
//  Shared collapsible section for editor sidebars.
//

import SwiftUI

#if os(macOS)

struct SidebarDisclosureSection<Content: View>: View {
    private let id: String
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let content: Content

    @AppStorage private var isExpanded: Bool
    @State private var isHovering = false

    init(
        id: String,
        title: String,
        systemImage: String? = nil,
        subtitle: String? = nil,
        defaultExpanded: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
        self._isExpanded = AppStorage(
            wrappedValue: defaultExpanded,
            "sidebar.section.\(id).expanded"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 12 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(headerBackground)
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    content
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private var headerBackground: Color {
        if isHovering {
            return Color(NSColor.controlAccentColor).opacity(0.12)
        }

        if isExpanded {
            return Color(NSColor.controlBackgroundColor).opacity(0.45)
        }

        return .clear
    }
}

#endif
