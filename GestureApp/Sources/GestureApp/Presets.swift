import Foundation

struct GesturePreset: Identifiable {
    let id = UUID()
    let key: String        // gesture name to be added (must be alphanumeric/underscore)
    let emoji: String
    let displayName: String
    let description: String
    let pattern: [Int]
    let suggestedHotkey: [String]

    func toConfig() -> GestureConfig {
        GestureConfig(
            type: "static",
            pattern: pattern,
            patternLeft: nil,
            patternRight: nil,
            proximity: nil,
            action: ActionConfig(
                type: .hotkey,
                keys: suggestedHotkey,
                command: nil,
                script: nil
            )
        )
    }
}

enum PresetLibrary {
    /// Curated single-hand poses the user can add to their config with one click.
    static let all: [GesturePreset] = [
        GesturePreset(
            key: "ily", emoji: "🤟",
            displayName: "I Love You",
            description: "Thumb + index + pinky out",
            pattern: [1, 1, 0, 0, 1],
            suggestedHotkey: ["cmd", "shift", "1"]
        ),
        GesturePreset(
            key: "point_up", emoji: "☝️",
            displayName: "Point Up",
            description: "Index only",
            pattern: [0, 1, 0, 0, 0],
            suggestedHotkey: ["cmd", "shift", "u"]
        ),
        GesturePreset(
            key: "l_shape", emoji: "🫵",
            displayName: "L Shape",
            description: "Thumb + index extended",
            pattern: [1, 1, 0, 0, 0],
            suggestedHotkey: ["cmd", "shift", "l"]
        ),
        GesturePreset(
            key: "three_fingers", emoji: "🤟",
            displayName: "Three",
            description: "Index + middle + ring",
            pattern: [0, 1, 1, 1, 0],
            suggestedHotkey: ["cmd", "shift", "3"]
        ),
        GesturePreset(
            key: "four_fingers", emoji: "🖖",
            displayName: "Four",
            description: "All except thumb",
            pattern: [0, 1, 1, 1, 1],
            suggestedHotkey: ["cmd", "shift", "4"]
        ),
        GesturePreset(
            key: "pinky_only", emoji: "🤙",
            displayName: "Pinky Only",
            description: "Pinky finger up",
            pattern: [0, 0, 0, 0, 1],
            suggestedHotkey: ["cmd", "shift", "p"]
        ),
    ]
}
