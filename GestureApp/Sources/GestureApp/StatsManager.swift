import Foundation
import Combine

/// Per-gesture lifetime counts, persisted in UserDefaults.
@MainActor
final class StatsManager: ObservableObject {
    @Published private(set) var counts: [String: Int]

    private let key = "gestureCounts"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.counts = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    func record(_ gesture: String) {
        counts[gesture, default: 0] += 1
        defaults.set(counts, forKey: key)
    }

    func reset() {
        counts = [:]
        defaults.removeObject(forKey: key)
    }

    /// Top N gestures by count, descending; ties broken by name.
    func top(_ n: Int) -> [(name: String, count: Int)] {
        counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { ($0.count, $1.name) > ($1.count, $0.name) }
            .prefix(n)
            .map { ($0.name, $0.count) }
    }

    var totalRecognized: Int {
        counts.values.reduce(0, +)
    }
}
