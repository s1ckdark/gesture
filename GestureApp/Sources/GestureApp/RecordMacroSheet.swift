import SwiftUI

struct RecordMacroSheet: View {
    let existingNames: Set<String>
    let onAdd: (String, GestureConfig) -> Void
    let onCancel: () -> Void

    @StateObject private var recorder = MacroRecorder()
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var fingers: [Bool] = Array(repeating: false, count: 5)

    private static let fingerLabels = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

    private var nameError: String? {
        if name.isEmpty { return nil }
        if !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Use letters, digits, or underscore only."
        }
        if existingNames.contains(name) { return "A gesture with this name already exists." }
        return nil
    }

    private var canSubmit: Bool {
        !name.isEmpty && nameError == nil && fingers.contains(true) &&
            !recorder.capturedSteps.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Record Macro").font(.title2).bold()
            Text("Bind any sequence of keypresses to a static pose. Recording uses a global keyboard monitor (needs Accessibility permission).")
                .font(.caption).foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.subheadline)
                    TextField("e.g. fast_save", text: $name)
                        .textFieldStyle(.roundedBorder)
                    if let err = nameError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emoji").font(.subheadline)
                    TextField("✨", text: $emoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Trigger Pose").font(.subheadline)
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Toggle(isOn: $fingers[i]) {
                            Text(Self.fingerLabels[i]).font(.caption)
                        }
                        .toggleStyle(.button)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Captured \(recorder.capturedSteps.count) keypress\(recorder.capturedSteps.count == 1 ? "" : "es")")
                        .font(.subheadline)
                    Spacer()
                    switch recorder.state {
                    case .idle:
                        Button("Start Recording") { recorder.start() }
                            .buttonStyle(.borderedProminent)
                    case .recording:
                        HStack(spacing: 6) {
                            Image(systemName: "record.circle.fill").foregroundColor(.red)
                            Text("Recording — every keypress is captured")
                        }
                        Button("Stop") { recorder.stop() }
                    case .done:
                        Button("Re-record") { recorder.reset() }
                    }
                }
                if recorder.capturedSteps.count > 0 {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(recorder.capturedSteps.indices, id: \.self) { i in
                                Text(briefStep(recorder.capturedSteps[i]))
                                    .font(.system(.caption2, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") {
                    recorder.stop()
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 380)
        .onDisappear { recorder.stop() }
    }

    private func briefStep(_ a: ActionConfig) -> String {
        let keys = (a.keys ?? []).joined(separator: "+")
        if let d = a.delayMs, d > 0 { return "+\(d)ms ⌨\(keys)" }
        return "⌨\(keys)"
    }

    private func submit() {
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        let chain = ActionConfig(
            type: .chain, keys: nil, command: nil, script: nil,
            button: nil, clickCount: nil, dx: nil, dy: nil, text: nil,
            url: nil, body: nil,
            obsHost: nil, obsPassword: nil, obsRequest: nil,
            steps: recorder.capturedSteps,
            delayMs: nil
        )
        let cfg = GestureConfig(
            type: "static",
            emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
            pattern: fingers.map { $0 ? 1 : 0 },
            patternLeft: nil, patternRight: nil,
            proximity: nil, motionTemplate: nil,
            motionLeft: nil, motionRight: nil,
            sequence: nil, windowMs: nil,
            action: chain
        )
        onAdd(name, cfg)
    }
}
