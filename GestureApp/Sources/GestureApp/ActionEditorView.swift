import SwiftUI

/// Shared editor for an ActionConfig — covers hotkey, shell, click, scroll, type_text.
/// Used by Settings, Add Gesture, and Motion Recorder sheets.
struct ActionEditorView: View {
    @Binding var config: ActionConfig
    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Action").font(.subheadline)
            Picker("", selection: Binding(
                get: { config.type },
                set: { newType in
                    config.type = newType
                    sanitize(for: newType)
                }
            )) {
                Text("Hotkey").tag(ActionType.hotkey)
                Text("Shell").tag(ActionType.shell)
                Text("Click").tag(ActionType.click)
                Text("Scroll").tag(ActionType.scroll)
                Text("Type").tag(ActionType.typeText)
            }
            .pickerStyle(.segmented)

            switch config.type {
            case .hotkey:    hotkeyEditor
            case .shell:     shellEditor
            case .click:     clickEditor
            case .scroll:    scrollEditor
            case .typeText:  typeTextEditor
            case .applescript:
                Text("AppleScript actions are post-MVP.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var hotkeyEditor: some View {
        HStack {
            Text(displayKeys())
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(minWidth: 200, alignment: .leading)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
            if recorder.isRecording {
                Button("Cancel (Esc)") { recorder.stop() }.controlSize(.small)
            } else {
                Button("Record") { recorder.start() }.controlSize(.small)
            }
            Spacer()
        }
        .onChange(of: recorder.recordedKeys) { newKeys in
            if !newKeys.isEmpty { config.keys = newKeys }
        }
    }

    private var shellEditor: some View {
        TextEditor(text: Binding(
            get: { config.command ?? "" },
            set: { config.command = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 50, maxHeight: 80)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(4)
    }

    private var clickEditor: some View {
        HStack(spacing: 12) {
            Picker("Button", selection: Binding(
                get: { config.button ?? "left" },
                set: { config.button = $0 }
            )) {
                Text("Left").tag("left")
                Text("Right").tag("right")
                Text("Middle").tag("middle")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Stepper("Count: \(config.clickCount ?? 1)", value: Binding(
                get: { config.clickCount ?? 1 },
                set: { config.clickCount = $0 }
            ), in: 1...3)
            .frame(maxWidth: 160)
        }
    }

    private var scrollEditor: some View {
        HStack(spacing: 8) {
            Text("dx:")
            TextField("0", value: Binding(
                get: { config.dx ?? 0 },
                set: { config.dx = $0 }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 70)
            Text("dy:")
            TextField("0", value: Binding(
                get: { config.dy ?? 0 },
                set: { config.dy = $0 }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 70)
            Text("pixels — positive = down/right")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var typeTextEditor: some View {
        TextField("Text to type when fired", text: Binding(
            get: { config.text ?? "" },
            set: { config.text = $0 }
        ))
        .textFieldStyle(.roundedBorder)
        .font(.system(.body, design: .monospaced))
    }

    private func displayKeys() -> String {
        if recorder.isRecording { return "Press a key combo… (Esc to cancel)" }
        let keys = config.keys ?? []
        if keys.isEmpty { return "(none — click Record)" }
        return keys.map(symbolize).joined(separator: " + ")
    }

    private func symbolize(_ key: String) -> String {
        switch key {
        case "cmd": return "⌘"
        case "shift": return "⇧"
        case "ctrl": return "⌃"
        case "opt": return "⌥"
        default: return key.uppercased()
        }
    }

    /// Reset fields that don't apply to the new type so YAML doesn't carry leftovers.
    private func sanitize(for newType: ActionType) {
        switch newType {
        case .hotkey:
            config.command = nil; config.text = nil; config.button = nil
            config.clickCount = nil; config.dx = nil; config.dy = nil
            if config.keys == nil { config.keys = [] }
        case .shell:
            config.keys = nil; config.text = nil; config.button = nil
            config.clickCount = nil; config.dx = nil; config.dy = nil
            if config.command == nil { config.command = "" }
        case .click:
            config.keys = nil; config.command = nil; config.text = nil
            config.dx = nil; config.dy = nil
            if config.button == nil { config.button = "left" }
            if config.clickCount == nil { config.clickCount = 1 }
        case .scroll:
            config.keys = nil; config.command = nil; config.text = nil
            config.button = nil; config.clickCount = nil
            if config.dx == nil { config.dx = 0 }
            if config.dy == nil { config.dy = -120 }
        case .typeText:
            config.keys = nil; config.command = nil
            config.button = nil; config.clickCount = nil
            config.dx = nil; config.dy = nil
            if config.text == nil { config.text = "" }
        case .applescript: break
        }
    }

    static func isValid(_ config: ActionConfig) -> Bool {
        switch config.type {
        case .hotkey: return !(config.keys?.isEmpty ?? true)
        case .shell: return !(config.command?.isEmpty ?? true)
        case .click: return (config.button ?? "").count > 0
        case .scroll: return (config.dx ?? 0) != 0 || (config.dy ?? 0) != 0
        case .typeText: return !(config.text?.isEmpty ?? true)
        case .applescript: return false
        }
    }
}
