import Combine
import Foundation

@MainActor
final class SelfTestModel: ObservableObject {
    enum State { case idle, running, complete }

    @Published var state: State = .idle
    @Published var currentIndex: Int = 0
    @Published var gesturesToTest: [String] = []
    @Published var results: [String: Bool] = [:]

    var current: String? {
        guard gesturesToTest.indices.contains(currentIndex) else { return nil }
        return gesturesToTest[currentIndex]
    }

    var passedCount: Int { results.values.filter { $0 }.count }
    var failedCount: Int { results.values.filter { !$0 }.count }

    func start(gestures: [String]) {
        gesturesToTest = gestures
        results = [:]
        currentIndex = 0
        state = gestures.isEmpty ? .complete : .running
    }

    func handleGesture(_ name: String) {
        guard state == .running, let cur = current, name == cur else { return }
        results[cur] = true
        advance()
    }

    func skip() {
        guard state == .running, let cur = current else { return }
        if results[cur] == nil { results[cur] = false }
        advance()
    }

    func reset() {
        state = .idle
        currentIndex = 0
        results = [:]
    }

    private func advance() {
        if currentIndex + 1 < gesturesToTest.count {
            currentIndex += 1
        } else {
            state = .complete
        }
    }
}
