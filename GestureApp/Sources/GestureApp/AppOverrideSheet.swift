import SwiftUI
import AppKit

/// Sheet for adding or editing a per-app action override on a single gesture.
struct AppOverrideSheet: View {
    let gestureName: String
    /// Initial bundle ID and action, or nil for a new override.
    let editing: (bundleID: String, action: ActionConfig)?
    /// Already-bound bundle IDs that should be excluded from the picker.
    let excludeBundleIDs: Set<String>
    let onSave: (String, ActionConfig) -> Void
    let onCancel: () -> Void

    @State private var bundleID: String = ""
    @State private var manualEntry: Bool = false
    @State private var actionConfig: ActionConfig = ActionConfig(
        type: .hotkey, keys: [], command: nil, script: nil,
        button: nil, clickCount: nil, dx: nil, dy: nil, text: nil
    )

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != nil }
            .filter { editing?.bundleID == $0.bundleIdentifier || !excludeBundleIDs.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private var canSubmit: Bool {
        !bundleID.isEmpty && ActionEditorView.isValid(actionConfig)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(editing == nil ? "Add App Override" : "Edit Override")
                .font(.title2).bold()
            Text("Override the action for '\(gestureName)' when a specific app is in the foreground.")
                .font(.caption).foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Target App").font(.subheadline)
                if !manualEntry {
                    Picker("", selection: $bundleID) {
                        Text("— Select a running app —").tag("")
                        ForEach(runningApps, id: \.processIdentifier) { app in
                            HStack {
                                Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                                Text("(\(app.bundleIdentifier ?? ""))")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            .tag(app.bundleIdentifier ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                    Button("Or enter bundle ID manually…") { manualEntry = true }
                        .controlSize(.small)
                } else {
                    TextField("com.example.MyApp", text: $bundleID)
                        .textFieldStyle(.roundedBorder)
                    Button("Pick from running apps instead") { manualEntry = false; bundleID = "" }
                        .controlSize(.small)
                }
            }

            ActionEditorView(config: $actionConfig)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(bundleID, actionConfig) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 520)
        .onAppear {
            if let editing {
                bundleID = editing.bundleID
                actionConfig = editing.action
                manualEntry = !runningApps.contains { $0.bundleIdentifier == editing.bundleID }
            }
        }
    }
}
