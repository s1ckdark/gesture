import Foundation

class SocketClient {
    private let socketPath: String
    private var fileHandle: FileHandle?
    private var isConnected = false
    var onGesture: ((GestureEvent) -> Void)?
    var onStatus: ((GestureEvent) -> Void)?
    var onFrame: ((Data, Int, Int) -> Void)?
    var onDisconnect: (() -> Void)?

    init(socketPath: String = "/tmp/gesture.sock") {
        self.socketPath = socketPath
    }

    func connect() throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw NSError(domain: "SocketClient", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strcpy(dest, ptr)
                }
            }
        }

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockAddr in
                Darwin.connect(fd, sockAddr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            close(fd)
            throw NSError(domain: "SocketClient", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to connect to \(socketPath)"])
        }

        fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        isConnected = true
        startReading()
    }

    private func startReading() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let fh = self.fileHandle else { return }
            var buffer = ""

            while self.isConnected {
                let data = fh.availableData
                if data.isEmpty {
                    self.isConnected = false
                    DispatchQueue.main.async { self.onDisconnect?() }
                    break
                }
                if let chunk = String(data: data, encoding: .utf8) {
                    buffer += chunk
                    while let newlineRange = buffer.range(of: "\n") {
                        let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                        buffer = String(buffer[newlineRange.upperBound...])
                        if let event = try? Self.parseMessage(line) {
                            DispatchQueue.main.async {
                                switch event.type {
                                case "gesture": self.onGesture?(event)
                                case "status": self.onStatus?(event)
                                case "frame":
                                    if let b64 = event.data,
                                       let imgData = Data(base64Encoded: b64),
                                       let w = event.width, let h = event.height {
                                        self.onFrame?(imgData, w, h)
                                    }
                                default: break
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static func parseMessage(_ json: String) throws -> GestureEvent {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(GestureEvent.self, from: data)
    }

    static func parseMessages(_ data: String) -> [GestureEvent] {
        data.split(separator: "\n").compactMap { line in
            try? parseMessage(String(line))
        }
    }

    func sendCommand(action: String) {
        guard let fh = fileHandle, isConnected else { return }
        let json = "{\"type\":\"command\",\"action\":\"\(action)\"}\n"
        if let data = json.data(using: .utf8) {
            try? fh.write(contentsOf: data)
        }
    }

    func disconnect() {
        isConnected = false
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
