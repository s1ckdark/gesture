import Foundation
import Combine

struct GestureLogEntry: Identifiable {
    let id = UUID()
    let name: String
    let time: Date
}

/// Per-gesture lifetime counts (persisted) plus an in-memory rolling log
/// of the last N events for the activity chart.
@MainActor
final class StatsManager: ObservableObject {
    @Published private(set) var counts: [String: Int]
    @Published private(set) var recentEvents: [GestureLogEntry] = []

    private let key = "gestureCounts"
    private let defaults: UserDefaults
    private let maxRecent = 200

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.counts = (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    func record(_ gesture: String) {
        counts[gesture, default: 0] += 1
        recentEvents.append(GestureLogEntry(name: gesture, time: Date()))
        if recentEvents.count > maxRecent {
            recentEvents.removeFirst(recentEvents.count - maxRecent)
        }
        defaults.set(counts, forKey: key)
    }

    func reset() {
        counts = [:]
        recentEvents = []
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
