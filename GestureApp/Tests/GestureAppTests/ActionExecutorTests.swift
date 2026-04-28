import XCTest
import CoreGraphics
@testable import GestureApp

final class ActionExecutorTests: XCTestCase {
    func testKeyCodeMapping() {
        XCTAssertEqual(ActionExecutor.keyCode(for: "c"), 8)
        XCTAssertEqual(ActionExecutor.keyCode(for: "v"), 9)
        XCTAssertEqual(ActionExecutor.keyCode(for: "space"), 49)
        XCTAssertEqual(ActionExecutor.keyCode(for: "tab"), 48)
        XCTAssertEqual(ActionExecutor.keyCode(for: "enter"), 36)
        XCTAssertNil(ActionExecutor.keyCode(for: "nonexistent"))
    }

    func testModifierFlags() {
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "cmd"), CGEventFlags.maskCommand)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "shift"), CGEventFlags.maskShift)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "ctrl"), CGEventFlags.maskControl)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "opt"), CGEventFlags.maskAlternate)
        XCTAssertNil(ActionExecutor.modifierFlag(for: "x"))
    }

    func testBuildShellAction() {
        let config = ActionConfig(type: .shell, keys: nil, command: "echo hello", script: nil)
        XCTAssertEqual(config.command, "echo hello")
    }

    func testBuildClickAction() {
        let config = ActionConfig(type: .click, keys: nil, command: nil, script: nil,
                                  button: "right", clickCount: 2)
        XCTAssertEqual(config.type, .click)
        XCTAssertEqual(config.button, "right")
        XCTAssertEqual(config.clickCount, 2)
    }

    func testBuildScrollAction() {
        let config = ActionConfig(type: .scroll, keys: nil, command: nil, script: nil,
                                  button: nil, clickCount: nil, dx: 0, dy: -120)
        XCTAssertEqual(config.type, .scroll)
        XCTAssertEqual(config.dy, -120)
    }

    func testBuildTypeTextAction() {
        let config = ActionConfig(type: .typeText, keys: nil, command: nil, script: nil,
                                  button: nil, clickCount: nil, dx: nil, dy: nil,
                                  text: "Hello!")
        XCTAssertEqual(config.type, .typeText)
        XCTAssertEqual(config.text, "Hello!")
    }
}
