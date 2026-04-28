import AppKit
import Combine

/// Observable wrapper around NSEvent local monitor for capturing a single keypress.
final class HotkeyRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordedKeys: [String] = []

    private var monitor: Any?

    /// Reverse map: keyCode → string label. Built from ActionExecutor.keyCodes.
    private static let reverseMap: [CGKeyCode: String] = {
        var dict: [CGKeyCode: String] = [:]
        for (label, code) in ActionExecutor.keyCodes {
            // Prefer the first label encountered (skips aliases like backspace=51 over delete=51).
            if dict[code] == nil { dict[code] = label }
        }
        return dict
    }()

    func start() {
        stop()
        isRecording = true
        recordedKeys = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            return nil // consume — don't let it propagate to text fields, etc.
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        var keys: [String] = []
        let flags = event.modifierFlags

        if flags.contains(.command) { keys.append("cmd") }
        if flags.contains(.shift) { keys.append("shift") }
        if flags.contains(.control) { keys.append("ctrl") }
        if flags.contains(.option) { keys.append("opt") }

        let keyCode = CGKeyCode(event.keyCode)
        // Esc cancels recording without committing.
        if keyCode == 53 && keys.isEmpty {
            stop()
            return
        }

        if let label = Self.reverseMap[keyCode] {
            keys.append(label)
        } else if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            keys.append(chars.lowercased())
        }

        // Need at least one main key (not just modifiers).
        guard keys.contains(where: { ActionExecutor.modifierFlag(for: $0) == nil }) else { return }

        recordedKeys = keys
        stop()
    }

    deinit { stop() }
}
