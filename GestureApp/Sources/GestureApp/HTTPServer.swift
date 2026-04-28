import Foundation
import Network

/// Minimal local HTTP server. Parses the first request line manually so
/// we don't need a third-party dep. Handlers are set by GestureApp.
final class HTTPServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "gesture.http", qos: .utility)

    var onTrigger: ((String) -> Void)?
    var statsProvider: (() -> Data?)?
    var configProvider: (() -> Data?)?

    var isRunning: Bool { listener != nil }

    func start(port: UInt16) throws {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let listener = try NWListener(using: .tcp, on: nwPort)
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            defer { conn.cancel() }
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                return
            }
            let response = self.respond(to: request)
            conn.send(content: response, completion: .contentProcessed { _ in })
        }
    }

    private func respond(to request: String) -> Data {
        let firstLine = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            return Self.makeResponse(status: "400 Bad Request", body: Data())
        }
        let method = parts[0]
        let path = parts[1]

        switch (method, path) {
        case ("GET", "/"):
            let body = Data("Gesture HTTP API.\nGET /stats, GET /config, POST /trigger/<name>\n".utf8)
            return Self.makeResponse(status: "200 OK", body: body, contentType: "text/plain")
        case ("GET", "/stats"):
            let body = statsProvider?() ?? Data("{}".utf8)
            return Self.makeResponse(status: "200 OK", body: body, contentType: "application/json")
        case ("GET", "/config"):
            let body = configProvider?() ?? Data("{}".utf8)
            return Self.makeResponse(status: "200 OK", body: body, contentType: "application/json")
        default:
            if method == "POST" && path.hasPrefix("/trigger/") {
                let name = String(path.dropFirst("/trigger/".count))
                if !name.isEmpty {
                    DispatchQueue.main.async { [weak self] in self?.onTrigger?(name) }
                    let body = Data("{\"ok\":true,\"triggered\":\"\(name)\"}".utf8)
                    return Self.makeResponse(status: "200 OK", body: body, contentType: "application/json")
                }
            }
            return Self.makeResponse(status: "404 Not Found", body: Data("not found".utf8))
        }
    }

    private static func makeResponse(status: String, body: Data,
                                     contentType: String = "text/plain") -> Data {
        var headers = "HTTP/1.1 \(status)\r\n"
        headers += "Content-Type: \(contentType); charset=utf-8\r\n"
        headers += "Content-Length: \(body.count)\r\n"
        headers += "Connection: close\r\n\r\n"
        var data = Data(headers.utf8)
        data.append(body)
        return data
    }
}
