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

    /// Guards against silent schema drift: encoding the default config back to
    /// YAML and decoding again must yield the same in-memory AppConfig.
    /// Catches regressions where new ActionConfig fields are added to the
    /// struct but not to CodingKeys, or vice-versa.
    func testDefaultConfigRoundTripsThroughYams() throws {
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configPath = projectRoot.appendingPathComponent("config/default.yaml").path
        let original = try ConfigManager.load(from: configPath)

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gesture-roundtrip-\(UUID().uuidString).yaml")
        try ConfigManager.save(original, to: tmp.path)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let reloaded = try ConfigManager.load(from: tmp.path)
        XCTAssertEqual(original, reloaded,
                       "AppConfig must survive a Yams encode/decode cycle unchanged")
    }

    /// Verifies the runtime invariant: setting `type` clears irrelevant fields
    /// (so a stale `keys` doesn't survive a switch to `.shell`) and seeds
    /// defaults for the new type. Backed by the didSet on ActionConfig.type.
    func testActionConfigTypeChangeAutoConforms() {
        var a = ActionConfig(type: .hotkey, keys: ["cmd", "c"], command: nil, script: nil)
        a.type = .shell
        XCTAssertNil(a.keys, "stale keys should be cleared on type change")
        XCTAssertEqual(a.command, "", "shell default should seed empty command")

        a.type = .click
        XCTAssertNil(a.command, "stale command should be cleared on type change")
        XCTAssertEqual(a.button, "left")
        XCTAssertEqual(a.clickCount, 1)

        a.type = .obsCommand
        XCTAssertNil(a.button)
        XCTAssertEqual(a.obsHost, "localhost:4455")
    }
}
