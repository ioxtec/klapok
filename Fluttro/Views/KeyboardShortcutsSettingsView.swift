//
//  KeyboardShortcutsSettingsView.swift
//  Fluttro
//
//  Keyboard shortcuts settings.
//

import SwiftUI

#if os(macOS)
import AppKit
import Carbon.HIToolbox

struct KeyboardShortcutsSettingsView: View {
    @StateObject private var viewState = KeyboardShortcutsSettingsViewState()

    private var refreshID: UUID {
        get { viewState.refreshID }
        nonmutating set { viewState.refreshID = newValue }
    }

    private var conflictMessage: String? {
        get { viewState.conflictMessage }
        nonmutating set { viewState.conflictMessage = newValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsSection(
                    title: "Screenshots",
                    subtitle: "Use global shortcuts to capture without opening the panel first.",
                    systemImage: "camera"
                ) {
                    ForEach(Array(KeyboardShortcutAction.screenshotActions.enumerated()), id: \.element.id) { index, shortcut in
                        KeyboardShortcutOption(
                            shortcut: shortcut,
                            isLast: index == KeyboardShortcutAction.screenshotActions.count - 1,
                            onConflict: { conflictMessage = $0 }
                        )
                    }
                }

                SettingsSection(
                    title: "Recording",
                    subtitle: "Recording shortcuts start a new capture, and stop an active recording.",
                    systemImage: "record.circle"
                ) {
                    ForEach(Array(KeyboardShortcutAction.recordingActions.enumerated()), id: \.element.id) { index, shortcut in
                        KeyboardShortcutOption(
                            shortcut: shortcut,
                            isLast: index == KeyboardShortcutAction.recordingActions.count - 1,
                            onConflict: { conflictMessage = $0 }
                        )
                    }
                }

                HStack {
                    Spacer()

                    Button("Restore Default Shortcuts") {
                        KeyboardShortcutAction.resetAllShortcuts()
                        refreshID = UUID()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("settings.content.shortcuts")
        .id(refreshID)
        .alert(
            "Shortcut already in use",
            isPresented: Binding(
                get: { conflictMessage != nil },
                set: { if !$0 { conflictMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(conflictMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutsChanged)) { _ in
            refreshID = UUID()
        }
    }
}

@MainActor
private final class KeyboardShortcutsSettingsViewState: ObservableObject {
    @Published var refreshID = UUID()
    @Published var conflictMessage: String?
}

private struct KeyboardShortcutOption: View {
    let shortcut: KeyboardShortcutAction
    let isLast: Bool
    var onConflict: (String) -> Void = { _ in }

    var body: some View {
        SettingsOptionView(isLast: isLast) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(shortcut.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 24)

                ShortcutRecorder(
                    shortcut: shortcut.shortcut,
                    onChange: { newShortcut in
                        if let conflict = KeyboardShortcutAction.conflictingAction(for: newShortcut, excluding: shortcut) {
                            onConflict("\(newShortcut.displayString) is already assigned to \(conflict.title).")
                        } else {
                            shortcut.setShortcut(newShortcut)
                        }
                    }
                )
                .frame(width: 128, height: 30)
                .accessibilityLabel("\(shortcut.title), \(shortcut.displayShortcut)")
            }
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: KeyboardShortcutDefinition
    let onChange: (KeyboardShortcutDefinition) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = onChange
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
        nsView.onChange = onChange
        nsView.refreshTitle()
    }
}

private final class ShortcutRecorderButton: NSButton {
    var shortcut = KeyboardShortcutDefinition(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .shift])
    var onChange: ((KeyboardShortcutDefinition) -> Void)?
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        isBordered = true
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        refreshTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    func refreshTitle() {
        guard !isRecording else { return }
        title = shortcut.displayString
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Type shortcut"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == kVK_Escape {
            stopRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        let newShortcut = KeyboardShortcutDefinition(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )
        shortcut = newShortcut
        stopRecording()
        onChange?(newShortcut)
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    private func stopRecording() {
        isRecording = false
        refreshTitle()
    }
}

#endif
