import SwiftUI

struct SettingsWindow: View {
    @Binding var liveConfig: AppConfig?
    let configPath: String
    let onSave: () -> Void

    @State private var draft: AppConfig?
    @State private var saveError: String?
    @State private var saved = false

    var body: some View {
        Group {
            if let draft {
                content(draft: draft)
            } else {
                Text("Loading config…")
                    .padding()
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear {
            draft = liveConfig
        }
    }

    @ViewBuilder
    private func content(draft: AppConfig) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Gesture Mappings")
                    .font(.title2)
                    .bold()
                Spacer()
                if saved {
                    Text("Saved ✓").foregroundColor(.green).font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider().padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(orderedGestureNames(for: draft), id: \.self) { name in
                        gestureRow(name: name)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                if let saveError {
                    Text(saveError).foregroundColor(.red).font(.caption)
                }
                Spacer()
                Button("Cancel") {
                    self.draft = liveConfig // discard changes
                    NSApp.keyWindow?.close()
                }
                Button("Save") {
                    saveDraft()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(self.draft == liveConfig)
            }
            .padding()
        }
    }

    private func orderedGestureNames(for cfg: AppConfig) -> [String] {
        // Stable display order: static poses first (alpha), then motions.
        let names = Array(cfg.gestures.keys)
        return names.sorted { a, b in
            let aIsMotion = cfg.gestures[a]?.type == "motion"
            let bIsMotion = cfg.gestures[b]?.type == "motion"
            if aIsMotion != bIsMotion { return !aIsMotion }
            return a < b
        }
    }

    @ViewBuilder
    private func gestureRow(name: String) -> some View {
        if let gesture = draft?.gestures[name] {
            GestureEditor(
                name: name,
                config: Binding(
                    get: { gesture },
                    set: { newValue in
                        draft?.gestures[name] = newValue
                        saved = false
                    }
                )
            )
        }
    }

    private func saveDraft() {
        guard let draft else { return }
        do {
            try ConfigManager.save(draft, to: configPath)
            liveConfig = draft
            saved = true
            saveError = nil
            onSave()
            // Auto-clear the "saved" flash after 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if saved { saved = false }
            }
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }
}

private struct GestureEditor: View {
    let name: String
    @Binding var config: GestureConfig

    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(displayName(name))
                    .font(.headline)
                Text("(\(config.type))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { config.action.type },
                    set: { newType in
                        config.action.type = newType
                        switch newType {
                        case .hotkey:
                            config.action.command = nil
                            if config.action.keys == nil { config.action.keys = [] }
                        case .shell:
                            config.action.keys = nil
                            if config.action.command == nil { config.action.command = "" }
                        case .applescript:
                            break
                        }
                    }
                )) {
                    Text("Hotkey").tag(ActionType.hotkey)
                    Text("Shell").tag(ActionType.shell)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            switch config.action.type {
            case .hotkey:
                hotkeyEditor
            case .shell:
                shellEditor
            case .applescript:
                Text("AppleScript actions are post-MVP.").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    private var hotkeyEditor: some View {
        HStack {
            Text(displayKeys())
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(minWidth: 180, alignment: .leading)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)

            if recorder.isRecording {
                Button("Cancel (Esc)") { recorder.stop() }
                    .controlSize(.small)
            } else {
                Button("Record") { recorder.start() }
                    .controlSize(.small)
            }

            Spacer()
        }
        .onChange(of: recorder.recordedKeys) { newKeys in
            if !newKeys.isEmpty {
                config.action.keys = newKeys
            }
        }
    }

    private var shellEditor: some View {
        TextEditor(text: Binding(
            get: { config.action.command ?? "" },
            set: { config.action.command = $0 }
        ))
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 50, maxHeight: 80)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(4)
    }

    private func displayKeys() -> String {
        let keys = config.action.keys ?? []
        if recorder.isRecording { return "Press a key combo… (Esc to cancel)" }
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

    private func displayName(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }
}
