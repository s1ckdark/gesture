import Foundation
import CoreGraphics

class ActionExecutor {
    static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,
        "space": 49, "tab": 48, "enter": 36, "esc": 53,
        "delete": 51, "backspace": 51,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    static func keyCode(for key: String) -> CGKeyCode? {
        keyCodes[key.lowercased()]
    }

    static func modifierFlag(for key: String) -> CGEventFlags? {
        switch key.lowercased() {
        case "cmd", "command": return .maskCommand
        case "shift": return .maskShift
        case "ctrl", "control": return .maskControl
        case "opt", "option", "alt": return .maskAlternate
        default: return nil
        }
    }

    func execute(action: ActionConfig) {
        switch action.type {
        case .hotkey:
            executeHotkey(keys: action.keys ?? [])
        case .shell:
            executeShell(command: action.command ?? "")
        case .applescript:
            break // post-MVP
        }
    }

    private func executeHotkey(keys: [String]) {
        guard !keys.isEmpty else { return }

        var modifiers = CGEventFlags()
        var mainKey: CGKeyCode?

        for key in keys {
            if let flag = Self.modifierFlag(for: key) {
                modifiers.insert(flag)
            } else if let code = Self.keyCode(for: key) {
                mainKey = code
            }
        }

        guard let keyCode = mainKey else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func executeShell(command: String) {
        guard !command.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Shell execution failed: \(error)")
            }
        }
    }
}
