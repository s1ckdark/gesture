import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, windows don't open at launch.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct GestureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var statusBar = StatusBarController()
    @State private var processManager: ProcessManager?
    @State private var socketClient: SocketClient?
    @State private var actionExecutor = ActionExecutor()
    @State private var config: AppConfig?
    @State private var socketRetryCount = 0
    private let maxSocketRetries = 5

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: statusBar.status.icon)
                    Text(statusBar.status.label)
                }
                .font(.headline)

                if statusBar.isEngineRunning {
                    Text("FPS: \(String(format: "%.1f", statusBar.fps))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !statusBar.lastGesture.isEmpty {
                    Text("Last: \(statusBar.lastGesture)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if !statusBar.hasAccessibility {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility 권한 필요")
                            .font(.caption)
                    }
                    Text("핫키 액션이 작동하지 않습니다.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button("권한 설정 열기") {
                        Permissions.requestAccessibility()
                    }
                    .controlSize(.small)
                }

                Divider()

                Button(statusBar.isEngineRunning ? "Stop" : "Start") {
                    toggleEngine()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Reload Config") {
                    reloadConfig()
                }

                Divider()

                Button("Quit") {
                    stopEngine()
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(8)
            .onAppear {
                reloadConfig()
                statusBar.refreshPermissions()
            }
        } label: {
            Image(systemName: statusBar.status.icon)
        }
        .menuBarExtraStyle(.window)

        Window("Gesture Settings", id: "settings") {
            SettingsWindow(
                liveConfig: $config,
                configPath: ConfigManager.defaultConfigPath(),
                onSave: { reloadConfig() }
            )
        }
        .windowResizability(.contentSize)
    }

    private func toggleEngine() {
        if statusBar.isEngineRunning {
            stopEngine()
        } else {
            startEngine()
        }
    }

    private func startEngine() {
        guard let config else { return }

        let enginePath = findEnginePath()

        let pm = ProcessManager(
            enginePath: enginePath,
            configPath: ConfigManager.defaultConfigPath()
        )
        pm.onProcessExit = { status in
            DispatchQueue.main.async {
                if status != 0 {
                    statusBar.status = .stopped
                    statusBar.isEngineRunning = false
                }
            }
        }

        do {
            try pm.start()
            processManager = pm
            statusBar.isEngineRunning = true
            statusBar.status = .running

            // Connect socket after a brief delay for Python to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                connectSocket(config: config)
            }
        } catch {
            NSLog("[Gesture] Failed to start engine: \(error.localizedDescription) — enginePath=\(enginePath)")
        }
    }

    private func connectSocket(config: AppConfig) {
        let client = SocketClient()
        client.onGesture = { event in
            guard let name = event.name else { return }
            statusBar.gestureRecognized(name)

            if let gestureConfig = config.gestures[name] {
                actionExecutor.execute(action: gestureConfig.action)
            }
        }
        client.onStatus = { event in
            statusBar.updateStatus(event)
        }
        client.onDisconnect = {
            statusBar.status = .stopped
            statusBar.isEngineRunning = false
        }

        do {
            try client.connect()
            socketClient = client
            socketRetryCount = 0
        } catch {
            socketRetryCount += 1
            if socketRetryCount < maxSocketRetries {
                print("Socket connection failed (\(socketRetryCount)/\(maxSocketRetries)), retrying...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    connectSocket(config: config)
                }
            } else {
                print("Socket connection failed after \(maxSocketRetries) attempts. Stopping engine.")
                stopEngine()
            }
        }
    }

    private func stopEngine() {
        socketClient?.disconnect()
        socketClient = nil
        processManager?.stop()
        processManager = nil
        statusBar.status = .stopped
        statusBar.isEngineRunning = false
    }

    private func reloadConfig() {
        do {
            config = try ConfigManager.load(from: ConfigManager.defaultConfigPath())
        } catch {
            print("Config load failed: \(error)")
        }
    }

    private func findEnginePath() -> String {
        // 1. cwd-relative (works when running via `swift run` from project root)
        let cwd = FileManager.default.currentDirectoryPath
        // 2. Bundle-relative — when packaged as .app inside <project>/dist/<App>.app,
        //    project root is two levels above the bundle.
        let bundlePath = Bundle.main.bundlePath
        let bundleParent = (bundlePath as NSString).deletingLastPathComponent  // dist/
        let projectFromBundle = (bundleParent as NSString).deletingLastPathComponent  // project root

        let candidates = [
            "\(cwd)/engine/main.py",
            "\(projectFromBundle)/engine/main.py",
            Bundle.main.resourcePath.map { "\($0)/engine/main.py" } ?? "",
        ]
        for path in candidates where !path.isEmpty {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        // Last resort
        return "\(projectFromBundle)/engine/main.py"
    }
}
