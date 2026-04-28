import AppKit
import Combine

/// Counts global modifier+key combos to surface the user's most-used hotkeys.
/// Only fires for keys with at least one modifier (cmd/shift/ctrl/opt) so it
/// never logs typing. Requires Accessibility permission. Persists to UserDefaults.
@MainActor
final class HotkeyTracker: ObservableObject {
    @Published private(set) var counts: [String: Int]

    private let key = "hotkeyTrackerCounts"
    private let defaults: UserDefaults
    private var monitor: Any?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.counts = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    var isTracking: Bool { monitor != nil }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func reset() {
        counts = [:]
        defaults.removeObject(forKey: key)
    }

    func keys(forCombo combo: String) -> [String] {
        combo.split(separator: "+").map(String.init)
    }

    /// Returns the top N hotkey combos NOT already bound to a gesture.
    func topUnbound(boundCombos: Set<String>, limit: Int = 10) -> [(combo: String, count: Int)] {
        counts
            .filter { !boundCombos.contains(Self.normalize($0.key)) }
            .map { ($0.key, $0.value) }
            .sorted { ($0.1, $0.0) > ($1.1, $1.0) }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }

    static func normalize(_ combo: String) -> String {
        combo.split(separator: "+").map(String.init).sorted().joined(separator: "+")
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags
        var parts: [String] = []
        if flags.contains(.command) { parts.append("cmd") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option) { parts.append("opt") }
        guard !parts.isEmpty else { return }
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return }
        let key = chars.lowercased().first.map { String($0) } ?? chars.lowercased()
        // Skip control characters
        guard let first = key.first, first.isLetter || first.isNumber else { return }
        parts.append(key)
        let combo = parts.joined(separator: "+")
        counts[combo, default: 0] += 1
        defaults.set(counts, forKey: self.key)
    }
}
