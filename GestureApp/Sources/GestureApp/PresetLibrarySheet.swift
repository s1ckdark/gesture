import SwiftUI

struct PresetLibrarySheet: View {
    let existingNames: Set<String>
    let onAdd: (String, GestureConfig) -> Void
    let onClose: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preset Library")
                    .font(.title2).bold()
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Click Add to copy a preset into your gestures. You can change the action later from Settings.")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PresetLibrary.all) { preset in
                        card(preset)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 400)
    }

    @ViewBuilder
    private func card(_ p: GesturePreset) -> some View {
        let alreadyAdded = existingNames.contains(p.key)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(p.emoji).font(.system(size: 32))
                VStack(alignment: .leading) {
                    Text(p.displayName).font(.headline)
                    Text(p.key).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            Text(p.description).font(.caption).foregroundColor(.secondary)
            Text(patternBadge(p.pattern))
                .font(.system(.caption2, design: .monospaced))
                .padding(.horizontal, 4)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(3)
            HStack {
                Text("Default: \(p.suggestedHotkey.map(symbolize).joined(separator: " + "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(alreadyAdded ? "Already added" : "Add") {
                    onAdd(p.key, p.toConfig())
                }
                .controlSize(.small)
                .disabled(alreadyAdded)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    private func patternBadge(_ pattern: [Int]) -> String {
        "[" + pattern.map { String($0) }.joined(separator: ",") + "]"
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
}
