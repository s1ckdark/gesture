import Foundation
import Yams

enum ConfigError: Error, LocalizedError {
    case fileNotFound(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "Config file not found: \(path)"
        case .parseError(let msg): return "Config parse error: \(msg)"
        }
    }
}

struct ConfigManager {
    static func load(from path: String) throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path)
        }
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: yaml)
    }

    static func parse(yaml: String) throws -> AppConfig {
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(AppConfig.self, from: yaml)
        } catch {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }

    static func defaultConfigPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.gesture/config.yaml"
    }

    static func save(_ config: AppConfig, to path: String) throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(config)
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func ensureDefaultConfig(bundledConfigPath: String) throws {
        let targetPath = defaultConfigPath()
        let targetDir = (targetPath as NSString).deletingLastPathComponent

        if !FileManager.default.fileExists(atPath: targetPath) {
            try FileManager.default.createDirectory(
                atPath: targetDir,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(atPath: bundledConfigPath, toPath: targetPath)
        }
    }
}
