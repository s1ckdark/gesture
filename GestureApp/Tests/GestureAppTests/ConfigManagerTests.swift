import XCTest
@testable import GestureApp

final class ConfigManagerTests: XCTestCase {
    let sampleYaml = """
    camera:
      device: 0
      fps: 30
      resolution: [640, 480]
    recognition:
      confidence_threshold: 0.85
      cooldown_ms: 800
      motion_buffer_frames: 20
      static_confirm_frames: 3
    gestures:
      thumbs_up:
        type: static
        action:
          type: hotkey
          keys: ["cmd", "c"]
      swipe_left:
        type: motion
        action:
          type: shell
          command: "open -a 'Mission Control'"
    """

    func testParseConfig() throws {
        let config = try ConfigManager.parse(yaml: sampleYaml)
        XCTAssertEqual(config.camera.device, 0)
        XCTAssertEqual(config.camera.fps, 30)
        XCTAssertEqual(config.recognition.confidenceThreshold, 0.85)
        XCTAssertEqual(config.recognition.cooldownMs, 800)
    }

    func testParseGestures() throws {
        let config = try ConfigManager.parse(yaml: sampleYaml)
        XCTAssertEqual(config.gestures.count, 2)

        let thumbsUp = config.gestures["thumbs_up"]
        XCTAssertNotNil(thumbsUp)
        XCTAssertEqual(thumbsUp?.type, "static")
        XCTAssertEqual(thumbsUp?.action.type, .hotkey)
        XCTAssertEqual(thumbsUp?.action.keys, ["cmd", "c"])

        let swipeLeft = config.gestures["swipe_left"]
        XCTAssertEqual(swipeLeft?.action.type, .shell)
        XCTAssertEqual(swipeLeft?.action.command, "open -a 'Mission Control'")
    }

    func testLoadDefaultConfig() throws {
        // Test that we can load the bundled default config
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configPath = projectRoot.appendingPathComponent("config/default.yaml").path
        let config = try ConfigManager.load(from: configPath)
        XCTAssertFalse(config.gestures.isEmpty)
    }
}
