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
    @StateObject private var hotkeyTracker = HotkeyTracker()
    @StateObject private var fatigue = FatigueMonitor()
    @StateObject private var voice = VoiceTrigger()
    @State private var httpServer = HTTPServer()
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
    @AppStorage("hotkeyTrackingEnabled") private var hotkeyTrackingEnabled = false
    @AppStorage("antiFatigueEnabled") private var antiFatigueEnabled = false
    @AppStorage("voiceGateEnabled") private var voiceGateEnabled = false
    @AppStorage("voiceTriggerWord") private var voiceTriggerWord = "gesture"
    @AppStorage("httpApiEnabled") private var httpApiEnabled = false
    @AppStorage("httpApiPort") private var httpApiPort = 14455
    @State private var showingRecommendations = false

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

                Toggle("Track Hotkeys (recommendations)", isOn: Binding(
                    get: { hotkeyTrackingEnabled },
                    set: { newValue in
                        hotkeyTrackingEnabled = newValue
                        if newValue { hotkeyTracker.start() } else { hotkeyTracker.stop() }
                    }
                ))
                .toggleStyle(.checkbox)

                Toggle("Anti-fatigue mode", isOn: $antiFatigueEnabled)
                    .toggleStyle(.checkbox)

                Toggle("Voice Gate (\"\(voiceTriggerWord)\")", isOn: Binding(
                    get: { voiceGateEnabled },
                    set: { newValue in
                        voiceGateEnabled = newValue
                        if newValue {
                            voice.triggerWord = voiceTriggerWord
                            voice.start()
                        } else {
                            voice.stop()
                        }
                    }
                ))
                .toggleStyle(.checkbox)

                Toggle("HTTP API (port \(httpApiPort))", isOn: Binding(
                    get: { httpApiEnabled },
                    set: { newValue in
                        httpApiEnabled = newValue
                        if newValue { startHTTPServer() } else { httpServer.stop() }
                    }
                ))
                .toggleStyle(.checkbox)

                Button("Recommendations…") {
                    NSApp.activate(ignoringOtherApps: true)
                    showingRecommendations = true
                }

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
                if hotkeyTrackingEnabled { hotkeyTracker.start() }
                if httpApiEnabled { startHTTPServer() }
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
            .sheet(isPresented: $showingRecommendations) {
                RecommendationsSheet(
                    tracker: hotkeyTracker,
                    availableGestures: (config?.gestures.keys.sorted()) ?? [],
                    onBind: { gestureName, keys in bindHotkeyToGesture(gestureName: gestureName, keys: keys) },
                    onClose: { showingRecommendations = false },
                    boundCombos: boundHotkeyCombos()
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
            handleGestureEvent(event, config: config)
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

    /// Single entry point for every recognized gesture, whether it came from
    /// the engine socket, the HTTP API, or self-test injection. Runs a small
    /// pipeline of named guards so the order of feedback channels is visible
    /// in stack traces and easy to reorder.
    private func handleGestureEvent(_ event: GestureEvent, config: AppConfig) {
        guard let name = event.name else { return }

        // 1. Voice gate — only allow while a recent wake word is in effect
        if voiceGateEnabled, !voice.isGateOpen { return }

        // 2. Anti-fatigue burst suppression
        if antiFatigueEnabled, !fatigue.shouldFire() {
            if !fatigue.hasNotifiedThisBurst {
                fatigue.markNotified()
                NotificationManager.shared.notify(
                    title: "Take a break 🧘",
                    body: "You've fired many gestures. Resting hand for a minute."
                )
            }
            return
        }

        // 3. Side effects — record, tell SwiftUI, sound + speech feedback
        runSideEffects(for: name)

        // 4. Self-test sink — if test is in progress, that consumes the event
        //    and we DON'T fire the bound action.
        if selfTest.state == .running {
            selfTest.handleGesture(name)
            return
        }

        // 5. Optional toast
        if notifyOnGesture {
            postGestureNotification(for: name, in: config)
        }

        // 6. Resolve + execute the action
        if let gestureConfig = config.gestures[name] {
            actionExecutor.execute(action: resolveAction(for: gestureConfig))
        }
    }

    private func runSideEffects(for name: String) {
        statusBar.gestureRecognized(name)
        stats.record(name)
        onboarding.handleGesture(name)
        if soundFeedback {
            NSSound(named: "Tink")?.play()
        }
        if speakOnGesture {
            SpeechManager.shared.announce(name.replacingOccurrences(of: "_", with: " "))
        }
    }

    private func postGestureNotification(for name: String, in config: AppConfig) {
        let g = config.gestures[name]
        let body = g.map(actionDescription) ?? "no action"
        let emoji = g?.emoji.map { "\($0) " } ?? ""
        NotificationManager.shared.notify(title: "\(emoji)Gesture: \(name)", body: body)
    }

    private func startHTTPServer() {
        httpServer.onTrigger = { [self] name in fireSyntheticGesture(name) }
        httpServer.statsProvider = {
            try? JSONSerialization.data(withJSONObject: stats.counts, options: [.prettyPrinted])
        }
        httpServer.configProvider = {
            guard let cfg = config else { return nil }
            return try? JSONEncoder().encode(cfg)
        }
        do {
            try httpServer.start(port: UInt16(httpApiPort))
        } catch {
            NSLog("[Gesture] HTTP API start failed: \(error.localizedDescription)")
            httpApiEnabled = false
        }
    }

    /// Fires a gesture as if it had been recognized — for HTTP-triggered tests
    /// or external integrations. Runs through the same resolve+execute path
    /// (so app overrides + chains apply), but skips anti-fatigue gating since
    /// the caller is presumed to know what they're doing.
    private func fireSyntheticGesture(_ name: String) {
        guard let cfg = config, let g = cfg.gestures[name] else { return }
        statusBar.gestureRecognized(name)
        stats.record(name)
        actionExecutor.execute(action: resolveAction(for: g))
    }

    private func boundHotkeyCombos() -> Set<String> {
        guard let cfg = config else { return [] }
        var set = Set<String>()
        for (_, g) in cfg.gestures where g.action.type == .hotkey {
            if let keys = g.action.keys {
                set.insert(HotkeyTracker.normalize(keys.joined(separator: "+")))
            }
        }
        return set
    }

    private func bindHotkeyToGesture(gestureName: String, keys: [String]) {
        guard var cfg = config, var g = cfg.gestures[gestureName] else { return }
        g.action = ActionConfig(type: .hotkey, keys: keys, command: nil, script: nil)
        cfg.gestures[gestureName] = g
        config = cfg
        // Persist to disk so the change isn't lost on Reload Config.
        try? ConfigManager.save(cfg, to: ConfigManager.defaultConfigPath())
    }

    /// Pick the app-specific override if the frontmost app's bundle ID (and
    /// optionally window title substring) match, else fall back to the
    /// gesture's default action.
    ///
    /// Override key syntax:
    ///   "com.google.Chrome"           — match bundle ID only
    ///   "com.google.Chrome | github"  — bundle ID AND window title contains
    ///   "* | github.com"              — any app AND window title contains
    private func resolveAction(for g: GestureConfig) -> ActionConfig {
        guard let overrides = g.appOverrides, !overrides.isEmpty else { return g.action }
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let title = frontmostWindowTitle() ?? ""

        // Title-qualified keys are more specific; check them first.
        let sortedKeys = overrides.keys.sorted { ($0.contains("|") ? 1 : 0) > ($1.contains("|") ? 1 : 0) }
        for key in sortedKeys {
            if Self.matches(overrideKey: key, bundleID: bundleID, title: title),
               let override = overrides[key] {
                return override
            }
        }
        return g.action
    }

    private static func matches(overrideKey: String, bundleID: String, title: String) -> Bool {
        if overrideKey.contains("|") {
            let parts = overrideKey.split(separator: "|", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return false }
            let bundleOK = (parts[0] == "*" || parts[0] == bundleID)
            let titleOK = !parts[1].isEmpty && title.localizedCaseInsensitiveContains(parts[1])
            return bundleOK && titleOK
        }
        return overrideKey == bundleID
    }

    /// Returns the frontmost window's title via CGWindowListCopyWindowInfo.
    /// Requires Screen Recording permission to read titles of OTHER apps; falls
    /// back to nil if unavailable, so bundle-only overrides keep working.
    private func frontmostWindowTitle() -> String? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return nil }
        let targetPID = frontmost.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for info in list {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid == targetPID,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let title = info[kCGWindowName as String] as? String, !title.isEmpty
            else { continue }
            return title
        }
        return nil
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
        case .obsCommand:
            return "OBS \(g.action.obsRequest ?? "")"
        case .chain:
            return "chain (\((g.action.steps ?? []).count) steps)"
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
