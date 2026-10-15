import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.localized)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle.localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }
}

// MARK: - Settings Option View Component

struct SettingsOptionView<Content: View>: View {
    let content: Content
    let isLast: Bool

    init(isLast: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isLast = isLast
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .opacity(0.5)
                    .padding(.leading, 18)
            }
        }
    }
}

private struct SettingsOptionLabel: View {
    let title: String
    let description: String?
    let infoText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(title.localized)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let infoText {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(infoText.localized)
                }
            }

            if let description, !description.isEmpty {
                Text(description.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Settings Toggle Option

struct SettingsToggleOption: View {
    let title: String
    let description: String?
    let infoText: String?
    let isLast: Bool
    @Binding var isOn: Bool

    init(
        title: String,
        description: String? = nil,
        infoText: String? = nil,
        isLast: Bool = false,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self._isOn = isOn
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack(alignment: .center, spacing: 16) {
                SettingsOptionLabel(title: title, description: description, infoText: infoText)

                Spacer(minLength: 24)

                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
            }
        }
    }
}

// MARK: - Settings Picker Option

struct SettingsPickerOption: View {
    let title: String
    let description: String?
    let infoText: String?
    let isLast: Bool
    let selection: Binding<String>
    let options: [(String, String)]

    init(
        title: String,
        description: String? = nil,
        infoText: String? = nil,
        isLast: Bool = false,
        selection: Binding<String>,
        options: [(String, String)]
    ) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self.selection = selection
        self.options = options
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack(alignment: .center, spacing: 16) {
                SettingsOptionLabel(title: title, description: description, infoText: infoText)

                Spacer(minLength: 24)

                Picker(title, selection: selection) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1.localized).tag(option.0)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: 180, alignment: .trailing)
                .accessibilityLabel(title)
            }
        }
    }
}

// MARK: - Settings Slider Option

struct SettingsSliderOption: View {
    let title: String
    let description: String?
    let infoText: String?
    let isLast: Bool
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String

    init(
        title: String,
        description: String? = nil,
        infoText: String? = nil,
        isLast: Bool = false,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1.0,
        formatter: @escaping (Double) -> String = { "\(Int($0))" }
    ) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self.value = value
        self.range = range
        self.step = step
        self.formatter = formatter
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    SettingsOptionLabel(title: title, description: description, infoText: infoText)

                    Spacer(minLength: 24)

                    Text(formatter(value.wrappedValue))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .trailing)
                }

                Slider(value: value, in: range, step: step)
                    .tint(.accentColor)
            }
        }
    }
}

// MARK: - Settings Text Option

struct SettingsTextOption: View {
    let title: String
    let description: String?
    let infoText: String?
    let isLast: Bool
    @Binding var text: String
    let placeholder: String

    init(
        title: String,
        description: String? = nil,
        infoText: String? = nil,
        isLast: Bool = false,
        text: Binding<String>,
        placeholder: String = ""
    ) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self._text = text
        self.placeholder = placeholder
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsOptionLabel(title: title, description: description, infoText: infoText)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Settings Info Option

struct SettingsInfoOption: View {
    let title: String
    let description: String?
    let infoText: String?
    let isLast: Bool

    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            SettingsOptionLabel(title: title, description: description, infoText: infoText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Settings Value Option

struct SettingsValueOption: View {
    let title: String
    let description: String?
    let value: String
    let isLast: Bool

    init(title: String, description: String? = nil, value: String, isLast: Bool = false) {
        self.title = title
        self.description = description
        self.value = value
        self.isLast = isLast
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SettingsOptionLabel(title: title, description: description, infoText: nil)

                Spacer(minLength: 24)

                Text(value)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Settings Path Option

struct SettingsPathOption: View {
    let title: String
    let path: String
    let description: String?
    let infoText: String?
    let isLast: Bool
    let action: () -> Void

    init(
        title: String,
        path: String,
        description: String? = nil,
        infoText: String? = nil,
        isLast: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.path = path
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self.action = action
    }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    SettingsOptionLabel(title: title, description: description, infoText: infoText)

                    Spacer(minLength: 24)

                    Button(LocalizationKeys.chooseFolderButton.localized) {
                        action()
                    }
                    .buttonStyle(.bordered)
                }

                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }
}

// MARK: - Compact Profile Summary

struct SettingsProfilesSummary<ProfileType: Profile>: View {
    let profiles: [ProfileType]
    let activeProfile: ProfileType?
    let resetAction: () -> Void
    let exportAction: () -> Void
    let importAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(profileCountText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(activeProfileText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            if !profiles.isEmpty {
                Text(profilePreviewText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button("Reset") {
                    resetAction()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Export") {
                    exportAction()
                }
                .buttonStyle(.bordered)

                Button("Import") {
                    importAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
    }

    private var profileCountText: String {
        String(format: "Loaded profiles: %ld".localized, profiles.count)
    }

    private var activeProfileText: String {
        if let activeProfile {
            return String(format: "Active: %@".localized, activeProfile.name)
        }

        return "No active profile".localized
    }

    private var profilePreviewText: String {
        let names = profiles.prefix(4).map(\.name).joined(separator: ", ")
        let remainder = profiles.count > 4 ? String(format: " and %ld more".localized, profiles.count - 4) : ""
        return "\(names)\(remainder)"
    }
}
