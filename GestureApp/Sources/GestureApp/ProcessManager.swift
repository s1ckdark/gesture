import Foundation

class ProcessManager {
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
            guard let self else { return }
            let status = proc.terminationStatus
            self.onProcessExit?(status)

            // Auto-restart on unexpected exit
            if status != 0 && self.restartCount < self.maxRestarts {
                self.restartCount += 1
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    try? self.start()
                }
            }
        }

        try process.run()
        self.process = process
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
