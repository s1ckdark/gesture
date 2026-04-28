import Foundation
import SwiftUI

/// Manages named YAML profiles under ~/.gesture/profiles/. Switching a profile
/// copies its .yaml over the active config path so the engine reads it on
/// next reload.
@MainActor
final class ProfileManager: ObservableObject {
    @Published private(set) var profiles: [String] = []
    @AppStorage("activeProfile") var activeProfile = "default"

    private var profilesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gesture/profiles")
    }

    private var configPath: String {
        ConfigManager.defaultConfigPath()
    }

    init() {
        bootstrap()
        refresh()
    }

    /// Make sure `profiles/` exists and seed `default.yaml` from the current
    /// config if no profile exists yet.
    private func bootstrap() {
        try? FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        let defaultPath = profilesDir.appendingPathComponent("default.yaml")
        if !FileManager.default.fileExists(atPath: defaultPath.path),
           FileManager.default.fileExists(atPath: configPath) {
            try? FileManager.default.copyItem(atPath: configPath, toPath: defaultPath.path)
        }
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: profilesDir.path)) ?? []
        profiles = files
            .filter { $0.hasSuffix(".yaml") }
            .map { String($0.dropLast(5)) }
            .sorted()
    }

    func switchTo(_ name: String) throws {
        let profilePath = profilesDir.appendingPathComponent("\(name).yaml")
        guard FileManager.default.fileExists(atPath: profilePath.path) else { return }
        if FileManager.default.fileExists(atPath: configPath) {
            try FileManager.default.removeItem(atPath: configPath)
        }
        try FileManager.default.copyItem(atPath: profilePath.path, toPath: configPath)
        activeProfile = name
    }

    /// Copy the current config to a new profile (or overwrite an existing one).
    func saveCurrentAs(_ name: String) throws {
        let profilePath = profilesDir.appendingPathComponent("\(name).yaml")
        if FileManager.default.fileExists(atPath: profilePath.path) {
            try FileManager.default.removeItem(atPath: profilePath.path)
        }
        try FileManager.default.copyItem(atPath: configPath, toPath: profilePath.path)
        refresh()
    }

    func delete(_ name: String) throws {
        guard name != activeProfile else { return }
        let profilePath = profilesDir.appendingPathComponent("\(name).yaml")
        try FileManager.default.removeItem(atPath: profilePath.path)
        refresh()
    }
}
