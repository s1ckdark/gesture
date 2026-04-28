import Foundation

struct GestureEvent: Codable {
    let type: String
    let name: String?
    let confidence: Double?
    let timestamp: Double?
    let handsDetected: Int?
    let fps: Double?
    /// Base64-encoded JPEG for preview frames (when type == "frame").
    let data: String?
    let width: Int?
    let height: Int?
    /// Live finger states [thumb, index, middle, ring, pinky] when type == "finger_states".
    let states: [Int]?
    /// Palm center [x, y] in normalized image coords; ships alongside `states`.
    let palm: [Double]?

    enum CodingKeys: String, CodingKey {
        case type, name, confidence, timestamp
        case handsDetected = "hands_detected"
        case fps, data, width, height, states, palm
    }
}

enum ActionType: String, Codable {
    case hotkey
    case shell
    case applescript
    case click
    case scroll
    case typeText = "type_text"
    case webhook
    case obsCommand = "obs_command"
    case chain
}

struct ActionConfig: Codable, Equatable {
    var type: ActionType
    var keys: [String]?
    var command: String?
    var script: String?
    /// For click: "left" | "right" | "middle".
    var button: String?
    /// For click: number of clicks (1 single, 2 double, …).
    var clickCount: Int?
    /// For scroll: horizontal/vertical deltas in pixel units.
    var dx: Double?
    var dy: Double?
    /// For type_text: the literal text to type.
    var text: String?
    /// For webhook: target URL.
    var url: String?
    /// For webhook: optional JSON body (string; included as-is in the POST body).
    var body: String?
    /// For obs_command: WebSocket host like "localhost:4455".
    var obsHost: String?
    /// For obs_command: OBS WebSocket password (omit if auth disabled).
    var obsPassword: String?
    /// For obs_command: requestType, e.g. "StartRecord", "ToggleVirtualCam", "PauseRecord".
    var obsRequest: String?
    /// For chain: ordered list of sub-actions to fire.
    var steps: [ActionConfig]?
    /// Inside a chain step: delay (ms) BEFORE this step runs.
    var delayMs: Int?

    enum CodingKeys: String, CodingKey {
        case type, keys, command, script, button, dx, dy, text, url, body, steps
        case clickCount = "click_count"
        case obsHost = "obs_host"
        case obsPassword = "obs_password"
        case obsRequest = "obs_request"
        case delayMs = "delay_ms"
    }
}

struct GestureConfig: Codable, Equatable {
    var type: String
    /// Optional emoji or short visual hint shown in Settings + notifications.
    var emoji: String?
    /// Optional 5-bit finger pattern [thumb, index, middle, ring, pinky] for custom static poses.
    var pattern: [Int]?
    /// For type == "static_dual": pattern of the user's left hand.
    var patternLeft: [Int]?
    /// For type == "static_dual": pattern of the user's right hand.
    var patternRight: [Int]?
    /// For type == "static_dual": optional max palm-center distance for the pose to fire.
    var proximity: Double?
    /// For type == "motion_custom": list of [x, y] palm-center points captured at recording time.
    var motionTemplate: [[Double]]?
    /// For type == "motion_dual": left hand's swipe direction (e.g. "swipe_left").
    var motionLeft: String?
    /// For type == "motion_dual": right hand's swipe direction.
    var motionRight: String?
    /// For type == "sequence": ordered list of gesture names that must fire in order.
    var sequence: [String]?
    /// For type == "sequence": maximum elapsed time for the full sequence in milliseconds.
    var windowMs: Int?
    var action: ActionConfig
    /// Per-app action overrides keyed by bundle identifier. When the frontmost
    /// app's bundle ID matches a key, that ActionConfig is fired instead of `action`.
    var appOverrides: [String: ActionConfig]?

    enum CodingKeys: String, CodingKey {
        case type, emoji, pattern, proximity, action, sequence
        case patternLeft = "pattern_left"
        case patternRight = "pattern_right"
        case motionTemplate = "motion_template"
        case motionLeft = "motion_left"
        case motionRight = "motion_right"
        case windowMs = "window_ms"
        case appOverrides = "app_overrides"
    }
}

struct RecognitionConfig: Codable, Equatable {
    var confidenceThreshold: Double
    var cooldownMs: Int
    var motionBufferFrames: Int
    var staticConfirmFrames: Int

    enum CodingKeys: String, CodingKey {
        case confidenceThreshold = "confidence_threshold"
        case cooldownMs = "cooldown_ms"
        case motionBufferFrames = "motion_buffer_frames"
        case staticConfirmFrames = "static_confirm_frames"
    }
}

struct CameraConfig: Codable, Equatable {
    var device: Int
    var fps: Int
    var resolution: [Int]
}

struct AppConfig: Codable, Equatable {
    var camera: CameraConfig
    var recognition: RecognitionConfig
    var gestures: [String: GestureConfig]
}
