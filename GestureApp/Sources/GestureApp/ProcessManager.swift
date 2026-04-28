import Foundation

class ProcessManager {
    /// Static registry so applicationWillTerminate can reach every live Python child
    /// even if the SwiftUI @State that owned the manager has been torn down.
    private static var activeProcesses: [Process] = []
    private static let registryQueue = DispatchQueue(label: "gesture.process.registry")
    /// Set by terminateAll(); termination handlers check this to suppress auto-restart
    /// during app shutdown.
    static var isShuttingDown = false

    private var process: Process?
    private let enginePath: String
    private let configPath: String
    private let maxRestarts = 3
    private var restartCount = 0
    var onProcessExit: ((Int32) -> Void)?

    init(enginePath: String, configPath: String) {
        self.enginePath = enginePath
        self.configPath = configPath
    }

    func start() throws {
        let process = Process()
        // enginePath points to engine/main.py — go up twice to reach project root
        let projectRoot = URL(fileURLWithPath: enginePath)
            .deletingLastPathComponent()  // engine/
            .deletingLastPathComponent()  // project root

        // Prefer project venv python; fall back to /usr/bin/env python3.
        let venvPython = projectRoot.appendingPathComponent("engine/.venv/bin/python")
        if FileManager.default.fileExists(atPath: venvPython.path) {
            process.executableURL = venvPython
            process.arguments = ["-m", "engine.main", "--config", configPath]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", "-m", "engine.main", "--config", configPath]
        }
        process.currentDirectoryURL = projectRoot

        // Capture stdout/stderr for debugging when launched from .app bundle.
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gesture/engine.log")
        try? FileManager.default.createDirectory(
            at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: logURL)
        process.standardOutput = logHandle
        process.standardError = logHandle

        process.terminationHandler = { [weak self] proc in
            // Drop from the registry so terminateAll() doesn't double-touch
            ProcessManager.registryQueue.sync {
                if let idx = ProcessManager.activeProcesses.firstIndex(where: { $0 === proc }) {
                    ProcessManager.activeProcesses.remove(at: idx)
                }
            }
            guard let self else { return }
            let status = proc.terminationStatus
            self.onProcessExit?(status)

            // Auto-restart on unexpected exit — but NEVER during app shutdown
            if !ProcessManager.isShuttingDown
               && status != 0
               && self.restartCount < self.maxRestarts {
                self.restartCount += 1
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    try? self.start()
                }
            }
        }

        try process.run()
        self.process = process
        ProcessManager.registryQueue.sync {
            ProcessManager.activeProcesses.append(process)
        }
    }

    /// Synchronously terminate every live Python child. Called from
    /// applicationWillTerminate so closing the app via ⌘Q, dock quit, or
    /// dragging the .app to trash all release the camera.
    static func terminateAll() {
        isShuttingDown = true
        let snapshot = registryQueue.sync { activeProcesses }
        for p in snapshot where p.isRunning {
            p.terminate()
        }
        // Give them up to ~1.5s to exit cleanly, then SIGKILL stragglers
        let deadline = Date().addingTimeInterval(1.5)
        for p in snapshot {
            while p.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if p.isRunning {
                kill(p.processIdentifier, SIGKILL)
            }
        }
    }

    func stop() {
        restartCount = maxRestarts // prevent auto-restart
        guard let process, process.isRunning else { return }
        process.terminate()
        // Give it a moment, then force kill
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.process?.isRunning == true {
                self?.process?.interrupt()
            }
        }
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func resetRestartCount() {
        restartCount = 0
    }
}
