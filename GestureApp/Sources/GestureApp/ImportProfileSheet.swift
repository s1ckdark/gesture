import SwiftUI
import AppKit

private enum ImportSource: String, CaseIterable, Identifiable {
    case url = "From URL"
    case paste = "Paste YAML"
    var id: String { rawValue }
}

struct ImportProfileSheet: View {
    @ObservedObject var manager: ProfileManager
    let onClose: () -> Void

    @State private var source: ImportSource = .url
    @State private var urlString: String = ""
    @State private var pastedYaml: String = ""
    @State private var profileName: String = ""
    @State private var status: String?
    @State private var isError = false
    @State private var fetchedYaml: String?

    private var canImport: Bool {
        let nameOK = !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
            profileName.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let payloadOK = (source == .url && fetchedYaml != nil) ||
            (source == .paste && !pastedYaml.trimmingCharacters(in: .whitespaces).isEmpty)
        return nameOK && payloadOK
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Profile").font(.title2).bold()
            Text("Bring in a profile from a gist (or any HTTP URL returning YAML), or paste the YAML directly.")
                .font(.caption).foregroundColor(.secondary)

            Picker("", selection: $source) {
                ForEach(ImportSource.allCases) { s in Text(s.rawValue).tag(s) }
            }
            .pickerStyle(.segmented)

            switch source {
            case .url:
                VStack(alignment: .leading, spacing: 4) {
                    TextField("https://gist.githubusercontent.com/.../raw/...", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Fetch") { fetchURL() }
                            .disabled(URL(string: urlString) == nil)
                        if let preview = fetchedYaml {
                            Text("\(preview.split(separator: "\n").count) lines fetched")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            case .paste:
                TextEditor(text: $pastedYaml)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 140, maxHeight: 220)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Save as profile name").font(.subheadline)
                TextField("e.g. work_setup", text: $profileName)
                    .textFieldStyle(.roundedBorder)
            }

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundColor(isError ? .red : .green)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                    .keyboardShortcut(.cancelAction)
                Button("Import") { saveProfile() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canImport)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 360)
    }

    private func fetchURL() {
        guard let url = URL(string: urlString) else { return }
        status = "Fetching…"
        isError = false
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    self.status = "Fetch failed: \(error.localizedDescription)"
                    self.isError = true
                    return
                }
                guard let data, let s = String(data: data, encoding: .utf8) else {
                    self.status = "Empty or non-UTF8 response."
                    self.isError = true
                    return
                }
                self.fetchedYaml = s
                self.status = "Fetched \(s.count) bytes ✓"
                self.isError = false
            }
        }.resume()
    }

    private func saveProfile() {
        let yaml = source == .url ? (fetchedYaml ?? "") : pastedYaml
        let trimmedName = profileName.trimmingCharacters(in: .whitespaces)
        let dest = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gesture/profiles/\(trimmedName).yaml")
        do {
            try yaml.write(to: dest, atomically: true, encoding: .utf8)
            manager.refresh()
            status = "Imported as '\(trimmedName)' — switch to it from the Profiles sheet."
            isError = false
        } catch {
            status = "Save failed: \(error.localizedDescription)"
            isError = true
        }
    }
}
