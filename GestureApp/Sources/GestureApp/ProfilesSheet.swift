import SwiftUI

struct ProfilesSheet: View {
    @ObservedObject var manager: ProfileManager
    let onSwitched: () -> Void
    let onClose: () -> Void

    @State private var newName: String = ""
    @State private var error: String?
    @State private var showingImport = false
    @State private var copiedFlash: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Profiles").font(.title2).bold()
                Spacer()
                Button("Done") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }

            Text("Switch between named gesture configs. The active profile is the YAML the engine reads at reload.")
                .font(.caption)
                .foregroundColor(.secondary)

            if manager.profiles.isEmpty {
                Text("No profiles yet.").foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(manager.profiles, id: \.self) { name in
                            row(name)
                        }
                    }
                }
                .frame(minHeight: 160)
            }

            Divider()

            HStack {
                TextField("New profile name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                Button("Save Current as…") { saveCurrent() }
                    .disabled(!isValidNewName)
            }

            HStack {
                Button("Import…") { showingImport = true }
                if let copiedFlash {
                    Text(copiedFlash).font(.caption).foregroundColor(.green)
                }
            }

            if let error {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 360)
        .sheet(isPresented: $showingImport) {
            ImportProfileSheet(manager: manager, onClose: { showingImport = false })
        }
    }

    private var isValidNewName: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty &&
            trimmed.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    private func row(_ name: String) -> some View {
        HStack {
            if name == manager.activeProfile {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            } else {
                Image(systemName: "circle").foregroundColor(.secondary)
            }
            Text(name).font(.system(.body, design: .monospaced))
            Spacer()
            Button(action: { copyProfileToClipboard(name) }) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy profile YAML to clipboard (paste into a gist to share)")
            .controlSize(.small)
            if name != manager.activeProfile {
                Button("Switch") { switchTo(name) }
                    .controlSize(.small)
                Button(role: .destructive) {
                    deleteProfile(name)
                } label: {
                    Image(systemName: "trash")
                }
                .controlSize(.small)
            } else {
                Text("active").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func switchTo(_ name: String) {
        do {
            try manager.switchTo(name)
            error = nil
            onSwitched()
        } catch {
            self.error = "Switch failed: \(error.localizedDescription)"
        }
    }

    private func saveCurrent() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        do {
            try manager.saveCurrentAs(trimmed)
            error = nil
            newName = ""
        } catch {
            self.error = "Save failed: \(error.localizedDescription)"
        }
    }

    private func copyProfileToClipboard(_ name: String) {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gesture/profiles/\(name).yaml")
        do {
            let yaml = try String(contentsOf: path, encoding: .utf8)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(yaml, forType: .string)
            copiedFlash = "Copied '\(name)' YAML to clipboard"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if copiedFlash?.contains(name) == true { copiedFlash = nil }
            }
        } catch {
            self.error = "Copy failed: \(error.localizedDescription)"
        }
    }

    private func deleteProfile(_ name: String) {
        do {
            try manager.delete(name)
            error = nil
        } catch {
            self.error = "Delete failed: \(error.localizedDescription)"
        }
    }
}
