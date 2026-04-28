import XCTest
@testable import GestureApp

final class SocketClientTests: XCTestCase {
    func testParseGestureEvent() throws {
        let json = """
        {"type": "gesture", "name": "thumbs_up", "confidence": 0.95, "timestamp": 1710841200}
        """
        let event = try SocketClient.parseMessage(json)
        XCTAssertEqual(event.type, "gesture")
        XCTAssertEqual(event.name, "thumbs_up")
        XCTAssertEqual(event.confidence, 0.95)
    }

    func testParseStatusEvent() throws {
        let json = """
        {"type": "status", "hands_detected": 1, "fps": 28.5}
        """
        let event = try SocketClient.parseMessage(json)
        XCTAssertEqual(event.type, "status")
        XCTAssertEqual(event.handsDetected, 1)
        XCTAssertEqual(event.fps, 28.5)
    }

    func testParseMultipleMessages() throws {
        let data = """
        {"type": "gesture", "name": "peace", "confidence": 0.9, "timestamp": 1}
        {"type": "status", "hands_detected": 0, "fps": 30.0}
        """
        let events = SocketClient.parseMessages(data)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].name, "peace")
        XCTAssertEqual(events[1].type, "status")
    }
}
