import SwiftUI

/// Shared editor for an ActionConfig — covers hotkey, shell, click, scroll, type_text.
/// Used by Settings, Add Gesture, and Motion Recorder sheets.
struct ActionEditorView: View {
    @Binding var config: ActionConfig
    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Action").font(.subheadline)
            // Setting config.type triggers ActionConfig.didSet → conformFieldsToType,
            // so the per-type defaults seed and stale fields clear automatically.
            Picker("", selection: $config.type) {
                Text("Hotkey").tag(ActionType.hotkey)
                Text("Shell").tag(ActionType.shell)
                Text("Click").tag(ActionType.click)
                Text("Scroll").tag(ActionType.scroll)
                Text("Type").tag(ActionType.typeText)
                Text("Webhook").tag(ActionType.webhook)
                Text("OBS").tag(ActionType.obsCommand)
                Text("Chain").tag(ActionType.chain)
            }
            .pickerStyle(.segmented)

            switch config.type {
            case .hotkey:     hotkeyEditor
            case .shell:      shellEditor
            case .click:      clickEditor
            case .scroll:     scrollEditor
            case .typeText:   typeTextEditor
            case .webhook:    webhookEditor
            case .obsCommand: obsEditor
            case .chain:      chainEditor
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

    private var webhookEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("https://example.com/hook", text: Binding(
                get: { config.url ?? "" },
                set: { config.url = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            TextEditor(text: Binding(
                get: { config.body ?? "" },
                set: { config.body = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 50, maxHeight: 100)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(4)
            Text("POST request, Content-Type: application/json. Body is sent as-is (leave empty for a ping).")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var chainEditor: some View {
        let steps = config.steps ?? []
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(steps.count) step\(steps.count == 1 ? "" : "s")")
                .font(.caption).foregroundColor(.secondary)
            ForEach(steps.indices, id: \.self) { i in
                HStack {
                    if let delay = steps[i].delayMs, delay > 0 {
                        Text("⏱ \(delay)ms").font(.caption2).foregroundColor(.secondary)
                    }
                    Text(briefStep(steps[i]))
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                }
            }
            Text("Edit chain steps in YAML directly — `steps:` is a list of action configs, each may include `delay_ms` for a pre-step pause.")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private func briefStep(_ a: ActionConfig) -> String {
        a.type.brief(a)
    }

    private var obsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Host:").font(.caption)
                TextField("localhost:4455", text: Binding(
                    get: { config.obsHost ?? "" },
                    set: { config.obsHost = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                Text("Password:").font(.caption)
                SecureField("(empty if auth disabled)", text: Binding(
                    get: { config.obsPassword ?? "" },
                    set: { config.obsPassword = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("Request:").font(.caption)
                TextField("e.g. StartRecord, PauseRecord, ToggleVirtualCam", text: Binding(
                    get: { config.obsRequest ?? "" },
                    set: { config.obsRequest = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            Text("Sends an OBS WebSocket v5 request. Configure OBS → Tools → WebSocket Server Settings to enable.")
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

    static func isValid(_ config: ActionConfig) -> Bool {
        config.type.isValid(config)
    }
}
