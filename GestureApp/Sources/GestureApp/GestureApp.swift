import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, windows don't open at launch.
        NSApp.setActivationPolicy(.accessory)
        // Defensive: clean up any engine.main processes left from a previous
        // crash or pre-fix installation, before the user clicks Start.
        ProcessManager.killOrphans()
    }

    /// Closing the app via ⌘Q, Dock right-click → Quit, or even SIGTERM
    /// from launchd has to take the camera with it. Kill any live Python
    /// engine subprocess synchronously before we exit.
    func applicationWillTerminate(_ notification: Notification) {
        ProcessManager.terminateAll()
    }
}

@main
struct GestureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var statusBar = StatusBarController()
    @StateObject private var loginItem = LoginItemController()
    @StateObject private var preview = PreviewModel()
    @StateObject private var selfTest = SelfTestModel()
    @StateObject private var stats = StatsManager()
    @StateObject private var profiles = ProfileManager()
    @StateObject private var onboarding = OnboardingModel()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var processManager: ProcessManager?
    @State private var socketClient: SocketClient?
    @State private var actionExecutor = ActionExecutor()
    @State private var config: AppConfig?
    @State private var socketRetryCount = 0
    @State private var showingProfiles = false
    private let maxSocketRetries = 5

    @AppStorage("soundFeedback") private var soundFeedback = false
    @AppStorage("notifyOnGesture") private var notifyOnGesture = false
    @AppStorage("speakOnGesture") private var speakOnGesture = false

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

                if stats.totalRecognized > 0 {
                    Divider()
                    Text("Top gestures (\(stats.totalRecognized) total)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(stats.top(3), id: \.name) { entry in
                        HStack {
                            Text(entry.name).font(.caption)
                            Spacer()
                            Text("\(entry.count)×").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Button("Reset Stats") { stats.reset() }
                        .controlSize(.small)
                }

                if !statusBar.hasAccessibility {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility permission required")
                            .font(.caption)
                    }
                    Text("Hotkey actions will not work.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button("Open Permission Settings") {
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

                Button("Show Camera Preview…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "preview")
                }
                .disabled(!statusBar.isEngineRunning)

                Button("Self Test…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "selfTest")
                }
                .disabled(!statusBar.isEngineRunning)

                Button("Stats…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "stats")
                }

                Button("Reload Config") {
                    reloadConfig()
                }

                Button("Profile: \(profiles.activeProfile)") {
                    showingProfiles = true
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)

                Toggle("Sound on Gesture", isOn: $soundFeedback)
                    .toggleStyle(.checkbox)

                Toggle("Notify on Gesture", isOn: $notifyOnGesture)
                    .toggleStyle(.checkbox)

                Toggle("Speak Gesture Name", isOn: $speakOnGesture)
                    .toggleStyle(.checkbox)

                Divider()

                Button("Show Onboarding…") {
                    onboarding.reset()
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "onboarding")
                }

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
                loginItem.refresh()
                profiles.refresh()
                if !onboardingComplete {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "onboarding")
                    }
                }
            }
            .sheet(isPresented: $showingProfiles) {
                ProfilesSheet(
                    manager: profiles,
                    onSwitched: {
                        // Tell the engine to reload its config: stop+start cycles cleanly
                        // and the config-watch is owned by Swift, so just reload our copy.
                        reloadConfig()
                    },
                    onClose: { showingProfiles = false }
                )
            }
        } label: {
            Image(systemName: statusBar.flashIcon ?? statusBar.status.icon)
        }
        .menuBarExtraStyle(.window)

        Window("Gesture Settings", id: "settings") {
            SettingsWindow(
                liveConfig: $config,
                configPath: ConfigManager.defaultConfigPath(),
                onSave: { reloadConfig() }
            )
            .environmentObject(preview)
        }
        .windowResizability(.contentSize)

        Window("Camera Preview", id: "preview") {
            PreviewWindow()
                .environmentObject(preview)
        }
        .windowResizability(.contentSize)

        Window("Self Test", id: "selfTest") {
            SelfTestWindow(
                availableGestures: gestureNamesForTest(),
                onClose: { NSApp.keyWindow?.close() }
            )
            .environmentObject(selfTest)
            .environmentObject(preview)
        }
        .windowResizability(.contentSize)

        Window("Gesture Stats", id: "stats") {
            StatsWindow()
                .environmentObject(stats)
        }
        .windowResizability(.contentSize)

        Window("Welcome to Gesture", id: "onboarding") {
            OnboardingWindow(
                isEngineRunning: statusBar.isEngineRunning,
                hasAccessibility: statusBar.hasAccessibility,
                onStartEngine: { startEngine() },
                onComplete: {
                    onboardingComplete = true
                    NSApp.keyWindow?.close()
                }
            )
            .environmentObject(onboarding)
            .environmentObject(preview)
        }
        .windowResizability(.contentSize)
    }

    private func gestureNamesForTest() -> [String] {
        guard let cfg = config else { return [] }
        // Test single-hand poses + motions; dual gestures are awkward to walk through.
        return cfg.gestures
            .filter { $0.value.type == "static" || $0.value.type == "motion" }
            .keys
            .sorted()
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
            stats.record(name)
            onboarding.handleGesture(name)

            if soundFeedback {
                NSSound(named: "Tink")?.play()
            }

            if speakOnGesture {
                SpeechManager.shared.announce(name.replacingOccurrences(of: "_", with: " "))
            }

            // While self-test is running, route gesture events to the test
            // model and suppress action execution to avoid surprises.
            if selfTest.state == .running {
                selfTest.handleGesture(name)
                return
            }

            if notifyOnGesture {
                let g = config.gestures[name]
                let actionDesc = g.map(actionDescription) ?? "no action"
                let emoji = g?.emoji.map { "\($0) " } ?? ""
                NotificationManager.shared.notify(
                    title: "\(emoji)Gesture: \(name)",
                    body: actionDesc
                )
            }

            if let gestureConfig = config.gestures[name] {
                let resolved = resolveAction(for: gestureConfig)
                actionExecutor.execute(action: resolved)
            }
        }
        client.onStatus = { event in
            statusBar.updateStatus(event)
        }
        client.onFrame = { data, _, _ in
            preview.ingest(jpegData: data)
        }
        client.onFingerStates = { states, palm in
            preview.ingest(fingerStates: states, palm: palm)
        }
        client.onDisconnect = {
            statusBar.status = .stopped
            statusBar.isEngineRunning = false
            preview.deactivate()
        }

        do {
            try client.connect()
            socketClient = client
            socketRetryCount = 0
            preview.sendCommand = { action in
                client.sendCommand(action: action)
            }
            // If preview window happens to be already open, re-activate the stream.
            if preview.isActive { client.sendCommand(action: "preview_on") }
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

    /// Pick the app-specific override if the frontmost app's bundle ID matches,
    /// else fall back to the gesture's default action.
    private func resolveAction(for g: GestureConfig) -> ActionConfig {
        if let overrides = g.appOverrides,
           let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let override = overrides[bundleID] {
            return override
        }
        return g.action
    }

    private func actionDescription(_ g: GestureConfig) -> String {
        switch g.action.type {
        case .hotkey:
            return (g.action.keys ?? []).joined(separator: " + ")
        case .shell:
            let cmd = g.action.command ?? ""
            return cmd.count > 60 ? String(cmd.prefix(60)) + "…" : cmd
        case .applescript:
            return "applescript"
        case .click:
            return "click \(g.action.button ?? "left") ×\(g.action.clickCount ?? 1)"
        case .scroll:
            return "scroll dx=\(Int(g.action.dx ?? 0)) dy=\(Int(g.action.dy ?? 0))"
        case .typeText:
            return "type \"\(g.action.text ?? "")\""
        case .webhook:
            return "POST \(g.action.url ?? "")"
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
