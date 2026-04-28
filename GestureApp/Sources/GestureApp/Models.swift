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

struct ActionConfig: Codable, Equatable {
    var type: ActionType
    var keys: [String]?
    var command: String?
    var script: String?
}

struct GestureConfig: Codable, Equatable {
    var type: String
    /// Optional 5-bit finger pattern [thumb, index, middle, ring, pinky] for custom static poses.
    var pattern: [Int]?
    var action: ActionConfig
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
