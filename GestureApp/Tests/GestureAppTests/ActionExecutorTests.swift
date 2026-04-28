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
}
