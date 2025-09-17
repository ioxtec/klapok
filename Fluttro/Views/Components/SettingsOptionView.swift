import SwiftUI

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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            
            if !isLast {
                Divider()
                    .background(Color.gray.opacity(0.08))
                    .padding(.leading, 16)
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
    
    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self._isOn = isOn
    }
    
    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let infoText = infoText {
                            Button(action: {
                                // Show info tooltip
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(infoText)
                        }
                    }
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.7)
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
    let options: [(String, String)] // (tag, display)
    
    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false, selection: Binding<String>, options: [(String, String)]) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self.selection = selection
        self.options = options
    }
    
    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let infoText = infoText {
                            Button(action: {
                                // Show info tooltip
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(infoText)
                        }
                    }
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Picker(title, selection: selection) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
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
    
    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false, value: Binding<Double>, in range: ClosedRange<Double>, step: Double = 1.0, formatter: @escaping (Double) -> String = { "\(Int($0))" }) {
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
                HStack {
                    HStack {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let infoText = infoText {
                            Button(action: {
                                // Show info tooltip
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(infoText)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatter(value.wrappedValue))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: value, in: range, step: step)
                    .accentColor(.blue)
            }
        }
    }
}

// MARK: - Settings Section Header
struct SettingsSectionHeader: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.gray.opacity(0.08))
                .padding(.leading, 16)
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
    
    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false, text: Binding<String>, placeholder: String = "") {
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
                HStack {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let infoText = infoText {
                        Button(action: {
                            // Show info tooltip
                        }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(infoText)
                    }
                    
                    Spacer()
                }
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
    @State private var showInfo = false
    
    init(title: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false) {
        self.title = title
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
    }
    
    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let infoText = infoText {
                            Button(action: {
                                showInfo.toggle()
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(infoText)
                        }
                    }
                    
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
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
    
    init(title: String, path: String, description: String? = nil, infoText: String? = nil, isLast: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.path = path
        self.description = description
        self.infoText = infoText
        self.isLast = isLast
        self.action = action
    }
    
    var body: some View {
        SettingsOptionView(isLast: isLast) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack {
                        Text(title)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if let infoText = infoText {
                            Button(action: {
                                // Show info tooltip
                            }) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(infoText)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Wybierz folder...") {
                        action()
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SettingsSectionHeader(title: "Test Section")
        
        SettingsToggleOption(
            title: "Show mouse cursor",
            description: "Include mouse cursor in screenshots",
            isOn: .constant(true)
        )
        
        SettingsPickerOption(
            title: "Default format",
            description: "File format for new screenshots",
            selection: .constant("PNG"),
            options: [("PNG", "PNG"), ("JPEG", "JPEG")]
        )
        
        SettingsSliderOption(
            title: "Quality",
            description: "Image quality for JPEG format",
            value: .constant(0.9),
            in: 0.1...1.0,
            step: 0.1,
            formatter: { "\(Int($0 * 100))%" }
        )
        
        SettingsPathOption(
            title: "Save folder",
            path: "/Users/hoxim/Documents/Fluttro Screenshots",
            description: "Folder where screenshots are saved",
            action: {}
        )
    }
    .frame(width: 600)
    .background(Color(NSColor.controlBackgroundColor))
}
