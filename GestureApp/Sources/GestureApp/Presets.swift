import Foundation

enum PresetKind {
    case single(pattern: [Int])
    case dual(left: [Int], right: [Int], proximity: Double?)
    case dualMotion(motionLeft: String, motionRight: String)
}

struct GesturePreset: Identifiable {
    let id = UUID()
    let key: String        // gesture name to be added (must be alphanumeric/underscore)
    let emoji: String
    let displayName: String
    let description: String
    let kind: PresetKind
    let suggestedHotkey: [String]

    func toConfig() -> GestureConfig {
        let action = ActionConfig(
            type: .hotkey,
            keys: suggestedHotkey,
            command: nil,
            script: nil
        )
        switch kind {
        case .single(let pattern):
            return GestureConfig(
                type: "static",
                pattern: pattern,
                patternLeft: nil, patternRight: nil,
                proximity: nil, motionTemplate: nil,
                motionLeft: nil, motionRight: nil,
                action: action
            )
        case .dual(let left, let right, let proximity):
            return GestureConfig(
                type: "static_dual",
                pattern: nil,
                patternLeft: left, patternRight: right,
                proximity: proximity, motionTemplate: nil,
                motionLeft: nil, motionRight: nil,
                action: action
            )
        case .dualMotion(let mLeft, let mRight):
            return GestureConfig(
                type: "motion_dual",
                pattern: nil,
                patternLeft: nil, patternRight: nil,
                proximity: nil, motionTemplate: nil,
                motionLeft: mLeft, motionRight: mRight,
                action: action
            )
        }
    }

    var patternBadge: String {
        switch kind {
        case .single(let p):
            return "[" + p.map(String.init).joined(separator: ",") + "]"
        case .dual(let l, let r, _):
            let ls = "[" + l.map(String.init).joined(separator: ",") + "]"
            let rs = "[" + r.map(String.init).joined(separator: ",") + "]"
            return "L \(ls)  R \(rs)"
        case .dualMotion(let mLeft, let mRight):
            return "L \(arrow(mLeft))  R \(arrow(mRight))"
        }
    }

    var isDual: Bool {
        switch kind {
        case .single: return false
        case .dual, .dualMotion: return true
        }
    }

    private func arrow(_ direction: String) -> String {
        switch direction {
        case "swipe_left": return "←"
        case "swipe_right": return "→"
        case "swipe_up": return "↑"
        case "swipe_down": return "↓"
        default: return direction
        }
    }
}

enum PresetLibrary {
    /// Curated single-hand poses the user can add to their config with one click.
    static let single: [GesturePreset] = [
        GesturePreset(
            key: "ily", emoji: "🤟",
            displayName: "I Love You",
            description: "Thumb + index + pinky out",
            kind: .single(pattern: [1, 1, 0, 0, 1]),
            suggestedHotkey: ["cmd", "shift", "1"]
        ),
        GesturePreset(
            key: "point_up", emoji: "☝️",
            displayName: "Point Up",
            description: "Index only",
            kind: .single(pattern: [0, 1, 0, 0, 0]),
            suggestedHotkey: ["cmd", "shift", "u"]
        ),
        GesturePreset(
            key: "l_shape", emoji: "🫵",
            displayName: "L Shape",
            description: "Thumb + index extended",
            kind: .single(pattern: [1, 1, 0, 0, 0]),
            suggestedHotkey: ["cmd", "shift", "l"]
        ),
        GesturePreset(
            key: "three_fingers", emoji: "🤟",
            displayName: "Three",
            description: "Index + middle + ring",
            kind: .single(pattern: [0, 1, 1, 1, 0]),
            suggestedHotkey: ["cmd", "shift", "3"]
        ),
        GesturePreset(
            key: "four_fingers", emoji: "🖖",
            displayName: "Four",
            description: "All except thumb",
            kind: .single(pattern: [0, 1, 1, 1, 1]),
            suggestedHotkey: ["cmd", "shift", "4"]
        ),
        GesturePreset(
            key: "pinky_only", emoji: "🤙",
            displayName: "Pinky Only",
            description: "Pinky finger up",
            kind: .single(pattern: [0, 0, 0, 0, 1]),
            suggestedHotkey: ["cmd", "shift", "p"]
        ),
    ]

    /// Curated two-handed poses; some require palms close together (proximity).
    static let dual: [GesturePreset] = [
        GesturePreset(
            key: "namaste", emoji: "🙏",
            displayName: "Namaste",
            description: "Palms together, fingers up",
            kind: .dual(left: [1, 1, 1, 1, 1], right: [1, 1, 1, 1, 1], proximity: 0.10),
            suggestedHotkey: ["cmd", "opt", "n"]
        ),
        GesturePreset(
            key: "double_thumbs", emoji: "👍👍",
            displayName: "Double Thumbs Up",
            description: "Both thumbs up",
            kind: .dual(left: [1, 0, 0, 0, 0], right: [1, 0, 0, 0, 0], proximity: nil),
            suggestedHotkey: ["cmd", "opt", "t"]
        ),
        GesturePreset(
            key: "double_fist", emoji: "✊✊",
            displayName: "Double Fist",
            description: "Both fists",
            kind: .dual(left: [0, 0, 0, 0, 0], right: [0, 0, 0, 0, 0], proximity: nil),
            suggestedHotkey: ["cmd", "opt", "f"]
        ),
        GesturePreset(
            key: "double_pinky", emoji: "🤙🤙",
            displayName: "Double Pinky",
            description: "Both pinkies out",
            kind: .dual(left: [0, 0, 0, 0, 1], right: [0, 0, 0, 0, 1], proximity: nil),
            suggestedHotkey: ["cmd", "opt", "p"]
        ),
        GesturePreset(
            key: "diamond", emoji: "🔷",
            displayName: "Diamond",
            description: "Both index+thumb out, palms close",
            kind: .dual(left: [1, 1, 0, 0, 0], right: [1, 1, 0, 0, 0], proximity: 0.20),
            suggestedHotkey: ["cmd", "opt", "d"]
        ),
    ]

    /// Two-handed motion presets: each hand's swipe direction must match.
    static let dualMotion: [GesturePreset] = [
        GesturePreset(
            key: "spread", emoji: "🌐",
            displayName: "Spread Outward",
            description: "Both hands swipe away from center",
            kind: .dualMotion(motionLeft: "swipe_left", motionRight: "swipe_right"),
            suggestedHotkey: ["cmd", "shift", "."]
        ),
        GesturePreset(
            key: "pinch", emoji: "🤏",
            displayName: "Pinch Inward",
            description: "Both hands swipe toward center",
            kind: .dualMotion(motionLeft: "swipe_right", motionRight: "swipe_left"),
            suggestedHotkey: ["cmd", "shift", "z"]
        ),
        GesturePreset(
            key: "page_right", emoji: "📃",
            displayName: "Page Right",
            description: "Both hands swipe right",
            kind: .dualMotion(motionLeft: "swipe_right", motionRight: "swipe_right"),
            suggestedHotkey: ["cmd", "right"]
        ),
        GesturePreset(
            key: "page_left", emoji: "📃",
            displayName: "Page Left",
            description: "Both hands swipe left",
            kind: .dualMotion(motionLeft: "swipe_left", motionRight: "swipe_left"),
            suggestedHotkey: ["cmd", "left"]
        ),
    ]

    static var all: [GesturePreset] { single + dual + dualMotion }
}
