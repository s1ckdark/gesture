import AppKit
import Combine

/// Records global keystrokes (with their delays between presses) and packs
/// them into an array of hotkey ActionConfigs suitable for an action chain.
@MainActor
final class MacroRecorder: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case done
    }

    @Published var state: State = .idle
    @Published var capturedSteps: [ActionConfig] = []

    private var monitor: Any?
    private var lastEventTime: Date?

    func start() {
        capturedSteps = []
        lastEventTime = Date()
        state = .recording
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.capture(event) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        state = .done
    }

    func reset() {
        stop()
        capturedSteps = []
        state = .idle
    }

    private func capture(_ event: NSEvent) {
        let now = Date()
        let elapsedMs = Int((now.timeIntervalSince(lastEventTime ?? now)) * 1000)
        lastEventTime = now

        var keys: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.command) { keys.append("cmd") }
        if flags.contains(.shift) { keys.append("shift") }
        if flags.contains(.control) { keys.append("ctrl") }
        if flags.contains(.option) { keys.append("opt") }
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            let first = chars.lowercased().first.map(String.init) ?? chars.lowercased()
            keys.append(first)
        }
        guard keys.count >= 1 else { return }

        var step = ActionConfig(
            type: .hotkey, keys: keys, command: nil, script: nil,
            button: nil, clickCount: nil, dx: nil, dy: nil, text: nil
        )
        if !capturedSteps.isEmpty {
            step.delayMs = max(40, min(2000, elapsedMs)) // clamp to a sane range
        }
        capturedSteps.append(step)
    }
}
