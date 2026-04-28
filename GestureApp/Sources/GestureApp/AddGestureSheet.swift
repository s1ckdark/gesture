import SwiftUI

private enum GestureKind: String, CaseIterable, Identifiable {
    case single = "Static (one hand)"
    case dual = "Static Dual (two hands)"
    var id: String { rawValue }
}

/// Modal sheet for creating a new custom static or dual-hand pose.
struct AddGestureSheet: View {
    let existingNames: Set<String>
    let onAdd: (String, GestureConfig) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var kind: GestureKind = .single
    @State private var fingers: [Bool] = Array(repeating: false, count: 5)
    @State private var leftFingers: [Bool] = Array(repeating: false, count: 5)
    @State private var rightFingers: [Bool] = Array(repeating: false, count: 5)
    @State private var useProximity: Bool = false
    @State private var proximity: Double = 0.2
    @State private var actionConfig: ActionConfig = ActionConfig(
        type: .hotkey, keys: [], command: nil, script: nil,
        button: nil, clickCount: nil, dx: nil, dy: nil, text: nil
    )

    @EnvironmentObject var preview: PreviewModel

    private static let fingerLabels = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

    private var nameError: String? {
        if name.isEmpty { return nil }
        if !name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            return "Use letters, digits, or underscore only."
        }
        if existingNames.contains(name) {
            return "A gesture with this name already exists."
        }
        return nil
    }

    private var canSubmit: Bool {
        guard !name.isEmpty, nameError == nil else { return false }
        let patternsOK: Bool
        switch kind {
        case .single:
            patternsOK = fingers.contains(true)
        case .dual:
            patternsOK = leftFingers.contains(true) && rightFingers.contains(true)
        }
        return patternsOK && ActionEditorView.isValid(actionConfig)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Custom Pose")
                .font(.title2)
                .bold()

            Picker("Type", selection: $kind) {
                ForEach(GestureKind.allCases) { k in
                    Text(k.rawValue).tag(k)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.subheadline)
                    TextField("e.g. spider, fox, three_fingers", text: $name)
                        .textFieldStyle(.roundedBorder)
                    if let err = nameError {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emoji (optional)").font(.subheadline)
                    TextField("🤘", text: $emoji)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            switch kind {
            case .single:
                fingerRow(label: "Finger Pattern", binding: $fingers)
                liveHUD(target: $fingers)
            case .dual:
                fingerRow(label: "Left Hand", binding: $leftFingers)
                fingerRow(label: "Right Hand", binding: $rightFingers)
                liveHUD(target: nil) // dual: hint only, copy ambiguous
                proximityRow
            }

            ActionEditorView(config: $actionConfig)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 520)
    }

    @ViewBuilder
    private func fingerRow(label: String, binding: Binding<[Bool]>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Toggle(isOn: binding[i]) {
                        Text(Self.fingerLabels[i]).font(.caption)
                    }
                    .toggleStyle(.button)
                }
            }
            Text("Pattern: \(patternString(binding.wrappedValue))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func liveHUD(target: Binding<[Bool]>?) -> some View {
        if !preview.fingerStates.isEmpty {
            HStack(spacing: 6) {
                Text("Live:").font(.caption2).foregroundColor(.secondary)
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(preview.fingerStates[i] == 1 ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
                Text("[\(preview.fingerStates.map(String.init).joined(separator: ","))]")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                if let target {
                    Button("Match Current") {
                        target.wrappedValue = preview.fingerStates.map { $0 == 1 }
                    }
                    .controlSize(.small)
                }
            }
        } else {
            Text("Open the Camera Preview window to see live finger state here.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var proximityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Require palms close together (proximity)", isOn: $useProximity)
                .toggleStyle(.checkbox)
            if useProximity {
                HStack {
                    Text("Max distance:")
                        .font(.caption)
                    Slider(value: $proximity, in: 0.05...0.5, step: 0.01)
                    Text(String(format: "%.2f", proximity))
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func patternString(_ states: [Bool]) -> String {
        let bits = states.map { $0 ? "1" : "0" }
        return "[" + bits.joined(separator: ", ") + "]"
    }

    private func submit() {
        let action = actionConfig
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)
        let emojiValue: String? = trimmedEmoji.isEmpty ? nil : trimmedEmoji
        let cfg: GestureConfig
        switch kind {
        case .single:
            let pattern = fingers.map { $0 ? 1 : 0 }
            cfg = GestureConfig(
                type: "static",
                emoji: emojiValue,
                pattern: pattern,
                patternLeft: nil,
                patternRight: nil,
                proximity: nil,
                action: action
            )
        case .dual:
            cfg = GestureConfig(
                type: "static_dual",
                emoji: emojiValue,
                pattern: nil,
                patternLeft: leftFingers.map { $0 ? 1 : 0 },
                patternRight: rightFingers.map { $0 ? 1 : 0 },
                proximity: useProximity ? proximity : nil,
                action: action
            )
        }
        onAdd(name, cfg)
    }
}
