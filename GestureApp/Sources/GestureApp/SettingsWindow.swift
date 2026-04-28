import SwiftUI

struct SettingsWindow: View {
    @Binding var liveConfig: AppConfig?
    let configPath: String
    let onSave: () -> Void

    @EnvironmentObject var preview: PreviewModel
    @State private var draft: AppConfig?
    @State private var saveError: String?
    @State private var saved = false
    @State private var showingAddSheet = false
    @State private var showingPresetSheet = false
    @State private var showingMotionSheet = false

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
                Button(action: { showingPresetSheet = true }) {
                    Image(systemName: "books.vertical")
                }
                .help("Browse preset poses")
                Button(action: { showingMotionSheet = true }) {
                    Image(systemName: "waveform.path")
                }
                .help("Record a custom motion gesture")
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
                .help("Add a new custom pose")
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
        .sheet(isPresented: $showingAddSheet) {
            AddGestureSheet(
                existingNames: existingGestureNames,
                onAdd: addGesture,
                onCancel: { showingAddSheet = false }
            )
            .environmentObject(preview)
        }
        .sheet(isPresented: $showingPresetSheet) {
            PresetLibrarySheet(
                existingNames: existingGestureNames,
                onAdd: { name, cfg in addGesture(name: name, cfg: cfg) },
                onClose: { showingPresetSheet = false }
            )
        }
        .sheet(isPresented: $showingMotionSheet) {
            MotionRecordSheet(
                existingNames: existingGestureNames,
                onAdd: { name, cfg in
                    addGesture(name: name, cfg: cfg)
                    showingMotionSheet = false
                },
                onCancel: { showingMotionSheet = false }
            )
            .environmentObject(preview)
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
                ),
                onDelete: gesture.pattern != nil ? {
                    draft?.gestures.removeValue(forKey: name)
                    saved = false
                } : nil
            )
        }
    }

    private var existingGestureNames: Set<String> {
        guard let d = draft else { return [] }
        return Set(d.gestures.keys)
    }

    private func addGesture(name: String, cfg: GestureConfig) {
        guard var d = draft else { return }
        d.gestures[name] = cfg
        draft = d
        saved = false
        showingAddSheet = false
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
    /// Non-nil only for user-added custom poses (those with `pattern`).
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let emoji = config.emoji, !emoji.isEmpty {
                    Text(emoji).font(.title2)
                }
                Text(displayName(name))
                    .font(.headline)
                Text("(\(config.type))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let pat = config.pattern {
                    Text(patternBadge(pat))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(3)
                }
                Spacer()
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .help("Remove this custom pose")
                    .controlSize(.small)
                }
            }

            ActionEditorView(config: $config.action)
        }
        .padding(8)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(6)
    }

    private func displayName(_ raw: String) -> String {
        raw.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
    }

    private func patternBadge(_ pattern: [Int]) -> String {
        "[" + pattern.map { String($0) }.joined(separator: ",") + "]"
    }
}
