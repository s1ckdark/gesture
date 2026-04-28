import SwiftUI

/// Modal sheet for creating a new custom static pose.
struct AddGestureSheet: View {
    let existingNames: Set<String>
    let onAdd: (String, GestureConfig) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var fingers: [Bool] = [false, false, false, false, false]
    @State private var actionType: ActionType = .hotkey
    @State private var hotkeyKeys: [String] = []
    @State private var shellCommand: String = ""

    @StateObject private var recorder = HotkeyRecorder()

    private static let fingerLabels = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

    private var nameError: String? {
        if name.isEmpty { return nil }  // empty = neutral, button just disabled
        if !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Use letters, digits, or underscore only."
        }
        if existingNames.contains(name) {
            return "A gesture with this name already exists."
        }
        return nil
    }

    private var canSubmit: Bool {
        !name.isEmpty && nameError == nil && fingers.contains(true) &&
            (actionType == .shell ? !shellCommand.isEmpty : !hotkeyKeys.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Custom Pose")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                TextField("e.g. spider, fox, three_fingers", text: $name)
                    .textFieldStyle(.roundedBorder)
                if let err = nameError {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Finger Pattern")
                    .font(.subheadline)
                Text("Tick each finger that should be extended.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Toggle(isOn: $fingers[i]) {
                            Text(Self.fingerLabels[i])
                                .font(.caption)
                        }
                        .toggleStyle(.button)
                    }
                }
                Text("Pattern: \(patternString())")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Action")
                    .font(.subheadline)
                Picker("", selection: $actionType) {
                    Text("Hotkey").tag(ActionType.hotkey)
                    Text("Shell").tag(ActionType.shell)
                }
                .pickerStyle(.segmented)

                switch actionType {
                case .hotkey:
                    HStack {
                        Text(displayKeys())
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(minWidth: 200, alignment: .leading)
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
                        if !newKeys.isEmpty { hotkeyKeys = newKeys }
                    }
                case .shell:
                    TextEditor(text: $shellCommand)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 50, maxHeight: 80)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                case .applescript:
                    EmptyView()
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 480)
    }

    private func patternString() -> String {
        let bits = fingers.map { $0 ? "1" : "0" }
        return "[" + bits.joined(separator: ", ") + "]"
    }

    private func displayKeys() -> String {
        if recorder.isRecording { return "Press a key combo… (Esc to cancel)" }
        if hotkeyKeys.isEmpty { return "(none — click Record)" }
        return hotkeyKeys.map(symbolize).joined(separator: " + ")
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

    private func submit() {
        let pattern = fingers.map { $0 ? 1 : 0 }
        let action: ActionConfig
        switch actionType {
        case .hotkey:
            action = ActionConfig(type: .hotkey, keys: hotkeyKeys, command: nil, script: nil)
        case .shell:
            action = ActionConfig(type: .shell, keys: nil, command: shellCommand, script: nil)
        case .applescript:
            return
        }
        let cfg = GestureConfig(type: "static", pattern: pattern, action: action)
        onAdd(name, cfg)
    }
}
