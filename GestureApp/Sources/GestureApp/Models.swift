import Foundation

struct GestureEvent: Codable {
    let type: String
    let name: String?
    let confidence: Double?
    let timestamp: Double?
    let handsDetected: Int?
    let fps: Double?

    enum CodingKeys: String, CodingKey {
        case type, name, confidence, timestamp
        case handsDetected = "hands_detected"
        case fps
    }
}

enum ActionType: String, Codable {
    case hotkey
    case shell
    case applescript
}

struct ActionConfig: Codable {
    let type: ActionType
    let keys: [String]?
    let command: String?
    let script: String?
}

struct GestureConfig: Codable {
    let type: String
    let action: ActionConfig
}

struct RecognitionConfig: Codable {
    let confidenceThreshold: Double
    let cooldownMs: Int
    let motionBufferFrames: Int
    let staticConfirmFrames: Int

    enum CodingKeys: String, CodingKey {
        case confidenceThreshold = "confidence_threshold"
        case cooldownMs = "cooldown_ms"
        case motionBufferFrames = "motion_buffer_frames"
        case staticConfirmFrames = "static_confirm_frames"
    }
}

struct CameraConfig: Codable {
    let device: Int
    let fps: Int
    let resolution: [Int]
}

struct AppConfig: Codable {
    let camera: CameraConfig
    let recognition: RecognitionConfig
    let gestures: [String: GestureConfig]
}
