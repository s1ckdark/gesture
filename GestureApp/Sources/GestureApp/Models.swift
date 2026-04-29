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

extension ActionType {
    /// Single source of truth for the human-visible label of an action type.
    /// Used by Picker tags, brief() summaries, and any other UI surface.
    var displayLabel: String {
        switch self {
        case .hotkey:      return "Hotkey"
        case .shell:       return "Shell"
        case .applescript: return "AppleScript"
        case .click:       return "Click"
        case .scroll:      return "Scroll"
        case .typeText:    return "Type"
        case .webhook:     return "Webhook"
        case .obsCommand:  return "OBS"
        case .chain:       return "Chain"
        }
    }

    /// Returns true when the ActionConfig has enough data for this type to fire.
    func isValid(_ a: ActionConfig) -> Bool {
        switch self {
        case .hotkey:    return !(a.keys?.isEmpty ?? true)
        case .shell:     return !(a.command?.isEmpty ?? true)
        case .click:     return (a.button ?? "").count > 0
        case .scroll:    return (a.dx ?? 0) != 0 || (a.dy ?? 0) != 0
        case .typeText:  return !(a.text?.isEmpty ?? true)
        case .webhook:
            guard let s = a.url, !s.isEmpty, let u = URL(string: s) else { return false }
            return u.scheme == "http" || u.scheme == "https"
        case .obsCommand:
            return !(a.obsHost?.isEmpty ?? true) && !(a.obsRequest?.isEmpty ?? true)
        case .chain:     return !((a.steps ?? []).isEmpty)
        case .applescript: return false
        }
    }

    /// One-line summary suitable for menu, list rows, log lines, notifications.
    func brief(_ a: ActionConfig) -> String {
        switch self {
        case .hotkey:      return (a.keys ?? []).joined(separator: " + ")
        case .shell:
            let cmd = a.command ?? ""
            return cmd.count > 60 ? String(cmd.prefix(60)) + "…" : cmd
        case .applescript: return "applescript"
        case .click:       return "click \(a.button ?? "left") ×\(a.clickCount ?? 1)"
        case .scroll:      return "scroll dx=\(Int(a.dx ?? 0)) dy=\(Int(a.dy ?? 0))"
        case .typeText:    return "type \"\(a.text ?? "")\""
        case .webhook:     return "POST \(a.url ?? "")"
        case .obsCommand:  return "OBS \(a.obsRequest ?? "")"
        case .chain:       return "chain ×\((a.steps ?? []).count)"
        }
    }
}

struct ActionConfig: Codable, Equatable {
    /// Setting type at runtime auto-sanitizes the other fields so a stale
    /// `keys` doesn't survive a switch to .shell. didSet does not fire during
    /// `init(from: Decoder)`, so YAML round-trips don't accidentally clear
    /// fields that were intentionally written by another writer.
    var type: ActionType {
        didSet { if type != oldValue { conformFieldsToType() } }
    }
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

    /// Clear all fields that don't apply to the current type, then seed
    /// the canonical default for the type if the relevant field is empty.
    /// Called automatically by the `type` didSet; UI editors no longer need
    /// to call sanitize() explicitly when switching action types.
    mutating func conformFieldsToType() {
        // Phase 1: clear every type-specific field
        if type != .hotkey { keys = nil }
        if type != .shell { command = nil }
        if type != .click { button = nil; clickCount = nil }
        if type != .scroll { dx = nil; dy = nil }
        if type != .typeText { text = nil }
        if type != .webhook { url = nil; body = nil }
        if type != .obsCommand { obsHost = nil; obsPassword = nil; obsRequest = nil }
        if type != .chain { steps = nil }

        // Phase 2: seed sensible defaults
        switch type {
        case .hotkey:
            if keys == nil { keys = [] }
        case .shell:
            if command == nil { command = "" }
        case .click:
            if button == nil { button = "left" }
            if clickCount == nil { clickCount = 1 }
        case .scroll:
            if dx == nil { dx = 0 }
            if dy == nil { dy = -120 }
        case .typeText:
            if text == nil { text = "" }
        case .webhook:
            if url == nil { url = "" }
        case .obsCommand:
            if obsHost == nil { obsHost = "localhost:4455" }
            if obsRequest == nil { obsRequest = "" }
        case .chain:
            if steps == nil { steps = [] }
        case .applescript:
            break
        }
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
