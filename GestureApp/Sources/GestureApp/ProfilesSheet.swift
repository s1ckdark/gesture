import SwiftUI

struct ProfilesSheet: View {
    @ObservedObject var manager: ProfileManager
    let onSwitched: () -> Void
    let onClose: () -> Void

    @State private var newName: String = ""
    @State private var error: String?

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

            if let error {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 320)
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

    private func deleteProfile(_ name: String) {
        do {
            try manager.delete(name)
            error = nil
        } catch {
            self.error = "Delete failed: \(error.localizedDescription)"
        }
    }
}
