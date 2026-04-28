import Foundation

/// Lightweight burst detector — when more than `limit` gestures fire within
/// `windowSeconds`, suppresses subsequent gestures for `coolDownSeconds` and
/// flips a one-shot notification flag so callers can surface a "take a break"
/// hint without spamming.
@MainActor
final class FatigueMonitor: ObservableObject {
    private var timestamps: [Date] = []
    private var suppressedUntil: Date?
    private(set) var hasNotifiedThisBurst = false

    let limit: Int
    let windowSeconds: TimeInterval
    let coolDownSeconds: TimeInterval

    init(limit: Int = 12, window: TimeInterval = 30, coolDown: TimeInterval = 60) {
        self.limit = limit
        self.windowSeconds = window
        self.coolDownSeconds = coolDown
    }

    /// Returns true if the gesture should be allowed to fire. Side-effects:
    /// records the attempt and may switch into a suppressed/cool-down state.
    func shouldFire() -> Bool {
        let now = Date()

        if let until = suppressedUntil {
            if now < until { return false }
            // Cool-down expired — reset
            suppressedUntil = nil
            hasNotifiedThisBurst = false
        }

        let cutoff = now.addingTimeInterval(-windowSeconds)
        timestamps = timestamps.filter { $0 > cutoff }

        if timestamps.count >= limit {
            suppressedUntil = now.addingTimeInterval(coolDownSeconds)
            timestamps = []
            return false
        }

        timestamps.append(now)
        return true
    }

    func markNotified() { hasNotifiedThisBurst = true }
}
