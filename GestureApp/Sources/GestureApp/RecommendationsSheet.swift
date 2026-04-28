import SwiftUI

struct RecommendationsSheet: View {
    @ObservedObject var tracker: HotkeyTracker
    let availableGestures: [String]   // gesture names without a hotkey binding (or any)
    let onBind: (String, [String]) -> Void   // (gestureName, hotkeyKeys)
    let onClose: () -> Void

    let boundCombos: Set<String>

    @State private var selectedCombo: String?
    @State private var pickedGesture: String = ""
    @State private var status: String?

    private var topRecommendations: [(combo: String, count: Int)] {
        tracker.topUnbound(boundCombos: boundCombos, limit: 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recommendations").font(.title2).bold()
                Spacer()
                Button("Reset Tracker") { tracker.reset() }
                    .controlSize(.small)
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Hotkeys you press often that aren't yet bound to a gesture. Pick one + a gesture to bind.")
                .font(.caption).foregroundColor(.secondary)

            if !tracker.isTracking {
                Label("Hotkey tracking is off — turn it on from the menu bar.",
                      systemImage: "info.circle")
                    .font(.caption).foregroundColor(.orange)
            }

            if topRecommendations.isEmpty {
                Spacer()
                Text("No data yet. Use your computer normally for a while, then come back.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topRecommendations, id: \.combo) { entry in
                            row(combo: entry.combo, count: entry.count)
                        }
                    }
                }
                .frame(minHeight: 180)

                if let selectedCombo {
                    Divider()
                    HStack {
                        Text("Bind \(prettyCombo(selectedCombo)) to:")
                            .font(.subheadline)
                        Picker("", selection: $pickedGesture) {
                            Text("— Choose a gesture —").tag("")
                            ForEach(availableGestures, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        Button("Bind") {
                            onBind(pickedGesture, tracker.keys(forCombo: selectedCombo))
                            status = "Bound \(prettyCombo(selectedCombo)) to \(pickedGesture). Save in Settings to persist."
                            self.selectedCombo = nil
                            pickedGesture = ""
                        }
                        .disabled(pickedGesture.isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let status {
                    Text(status).font(.caption).foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 540, minHeight: 380)
    }

    @ViewBuilder
    private func row(combo: String, count: Int) -> some View {
        let isSelected = combo == selectedCombo
        HStack {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
            Text(prettyCombo(combo))
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text("\(count)×").font(.caption).foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedCombo = combo }
        .padding(.vertical, 2)
    }

    private func prettyCombo(_ combo: String) -> String {
        combo.split(separator: "+").map { part -> String in
            switch part {
            case "cmd": return "⌘"
            case "shift": return "⇧"
            case "ctrl": return "⌃"
            case "opt": return "⌥"
            default: return String(part).uppercased()
            }
        }.joined(separator: " ")
    }
}
