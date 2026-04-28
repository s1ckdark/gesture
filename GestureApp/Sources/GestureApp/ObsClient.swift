import CryptoKit
import Foundation

/// Minimal OBS WebSocket v5 client. Opens a fresh connection per command
/// (Hello → Identify → Request → close), so latency is ~200-500ms but the
/// integration is dependency-free and stateless.
enum ObsClient {
    static func sendCommand(host: String, password: String?,
                            requestType: String, requestData: [String: Any]? = nil) {
        guard let url = URL(string: "ws://\(host)") else {
            NSLog("[Gesture] OBS: invalid host '\(host)'")
            return
        }
        let session = URLSession(configuration: .ephemeral)
        let task = session.webSocketTask(with: url)
        task.resume()

        receive(task) { hello in
            guard let helloD = hello["d"] as? [String: Any] else {
                NSLog("[Gesture] OBS: malformed Hello")
                close(task); return
            }

            // Build the Identify payload, including auth string if the server
            // supplied authentication parameters
            var identifyData: [String: Any] = ["rpcVersion": 1]
            if let authInfo = helloD["authentication"] as? [String: Any],
               let challenge = authInfo["challenge"] as? String,
               let salt = authInfo["salt"] as? String {
                guard let pw = password, !pw.isEmpty else {
                    NSLog("[Gesture] OBS: server requires password but none configured")
                    close(task); return
                }
                identifyData["authentication"] = computeAuth(password: pw, salt: salt, challenge: challenge)
            }

            send(task, dict: ["op": 1, "d": identifyData])

            // Wait for Identified, then send the actual Request, then close
            receive(task) { _ in
                var requestPayload: [String: Any] = [
                    "requestType": requestType,
                    "requestId": UUID().uuidString,
                ]
                if let requestData { requestPayload["requestData"] = requestData }
                send(task, dict: ["op": 6, "d": requestPayload])
                receive(task) { _ in close(task) }
            }
        }
    }

    private static func computeAuth(password: String, salt: String, challenge: String) -> String {
        let secretInput = (password + salt).data(using: .utf8)!
        let secretHash = SHA256.hash(data: secretInput)
        let secretB64 = Data(secretHash).base64EncodedString()
        let authInput = (secretB64 + challenge).data(using: .utf8)!
        let authHash = SHA256.hash(data: authInput)
        return Data(authHash).base64EncodedString()
    }

    private static func send(_ task: URLSessionWebSocketTask, dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        task.send(.string(str)) { error in
            if let error { NSLog("[Gesture] OBS send: \(error.localizedDescription)") }
        }
    }

    private static func receive(_ task: URLSessionWebSocketTask,
                                _ handler: @escaping ([String: Any]) -> Void) {
        task.receive { result in
            switch result {
            case .success(.string(let s)):
                if let data = s.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    handler(dict)
                } else {
                    close(task)
                }
            case .success(.data(let d)):
                if let dict = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    handler(dict)
                } else {
                    close(task)
                }
            case .failure(let error):
                NSLog("[Gesture] OBS receive: \(error.localizedDescription)")
                close(task)
            @unknown default:
                close(task)
            }
        }
    }

    private static func close(_ task: URLSessionWebSocketTask) {
        task.cancel(with: .normalClosure, reason: nil)
    }
}
