# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [0.6.1] - 2026-04-29

### Refactored
- `engine/landmarks.py` extracted from classifier.py — `palm_center` and `finger_states` are now module functions; 4 inline duplicates collapsed
- `_RecentBuffer` shared by `SequenceClassifier` and `ChordClassifier` — ~40 lines saved, identical behavior
- `engine/config_parser.py` extracted — `GestureEngine.__init__` shrinks from ~70 to ~10 lines, each per-type parser unit-testable
- `GestureApp.handleGestureEvent` pipeline broken into named methods (voiceGate → fatigueGate → runSideEffects → selfTestSink → notify → action)
- `ActionType.brief / isValid / displayLabel` extension — collapses 4 duplicated 9-case switches across the codebase
- `ActionConfig.conformFieldsToType` mutating method, called automatically by `type`'s didSet — eliminates the "stale field after switching action type" bug; `init(from: Decoder)` is unaffected so YAML round-trips intact

### Tests
- New ConfigManagerTests cover Yams round-trip on default.yaml and the auto-conform invariant on type changes (14 swift tests total)

## [0.6.0] - 2026-04-29

### Added
- Action chains — single gesture fires ordered list of sub-actions with optional pre-step delays
- Window-title context for app overrides — `"com.bundle.id | substring"` and `"* | substring"` keys
- Anti-fatigue mode — burst suppression with one-shot "take a break" notification
- Local HTTP API (NWListener-based) — GET /stats, GET /config, POST /trigger/<name>
- Macro recorder — capture global keypresses with delays into a chain action; bind to a static pose
- Chord macros — unordered set of gestures within a window (mirrors sequence but order-independent)
- Voice gate — SFSpeechRecognizer wake word required for gestures to fire (off by default)
- Plugin SDK — Python files under `~/.gesture/plugins/` are loaded by the engine; exported `handle(gesture, event)` is called per gesture

### Changed
- Engine `_fire` records into both SequenceClassifier and ChordClassifier and dispatches to loaded plugins

## [0.5.0] - 2026-04-29

### Added
- App-aware action overrides — per-bundle-ID overrides on each gesture; same gesture, different action depending on the frontmost app
- Stats dashboard window using SwiftUI Charts (lifetime BarMark + recent activity PointMark)
- Recognition tuning knobs in YAML — `ok_sign_distance`, `motion_threshold`, `motion_template_threshold`
- Full Korean i18n coverage — all sheets/windows now have ~85 localized strings
- Profile cloud share — clipboard export per profile + URL/paste import sheet
- OBS WebSocket v5 action type — fires StartRecord/PauseRecord/ToggleVirtualCam etc. via stateless WS client (CryptoKit-backed auth)
- Hotkey usage tracker + recommendations sheet — global event monitor counts modifier+key combos, surfaces top unbound for one-click gesture binding
- Performance: `detect_every_n_frames` to skip detection for CPU savings; preview JPEGs continue at full capture rate
- Performance: `use_gpu` toggle wires the MediaPipe Metal delegate (with graceful CPU fallback)

### Changed
- Engine main loop restructured so preview JPEG streaming runs independently of detection skipping

## [0.4.1] - 2026-04-28

### Fixed
- Python engine subprocess survived app quit and held the camera locked. AppDelegate.applicationWillTerminate now invokes ProcessManager.terminateAll() (SIGTERM → 1.5s grace → SIGKILL) so any quit path releases the camera.
- Orphan engine.main processes from previous crashes/installations are swept at app launch via `pkill -f engine.main` in applicationDidFinishLaunching.

## [0.4.0] - 2026-04-28

### Added
- Two-handed motion presets in the library (spread, pinch, page_left/right)
- TTS voice feedback (Speak Gesture Name) — AVSpeechSynthesizer announces recognized gestures
- Per-gesture emoji visual hints; surfaces in Settings rows + notification titles
- Unified ActionEditorView covering all action types in every editor (Settings, Add, Motion record)
- Click / Scroll / Type-text actions are now fully editable in the GUI (not just YAML)
- Webhook action — POST to URL with optional JSON body via URLSession
- Palm-position heatmap overlay in Camera Preview, with reset button
- Named YAML profiles (`~/.gesture/profiles/<name>.yaml`) with switcher sheet
- Gesture macros — `type: sequence` with ordered list + window_ms; engine emits the macro event when the leaf sequence completes in time

### Changed
- Engine `_fire(name, conf)` helper centralizes cooldown + sequence recording + macro detection (replaces 4 scattered cooldown/send call sites)

## [0.3.0] - 2026-04-28

### Added
- Per-gesture usage stats persisted in UserDefaults; menu bar shows top 3 with counts
- Dual-hand presets in the library (namaste, double_thumbs, double_fist, double_pinky, diamond)
- Tag-triggered GitHub Actions release workflow — pushing v*.*.* now auto-builds the universal .dmg and creates the release with notes pulled from CHANGELOG
- Live finger HUD inside the Add Gesture Sheet — 5-dot row + "Match Current" button to copy live state into pattern toggles
- GUI motion recorder (Settings → waveform.path icon) — countdown + capture from PreviewModel.palmCenter, saves directly as motion_custom
- First-run onboarding wizard (welcome → camera → accessibility → demo → done) with replay from menu
- HID action types — click (button + count), scroll (dx/dy), type_text — backed by CGEvent
- Two-handed motion (motion_dual) — coordinated swipes (e.g. spread = both swipe outward) with sync window

### Changed
- Engine `finger_states` event now also carries the live palm center for the motion recorder
- Models.swift expanded for new action fields and motion_dual schema

## [0.2.0] - 2026-04-28

### Added
- Preset pose library (ily, point_up, l_shape, three_fingers, four_fingers, pinky_only) accessible from Settings
- Add Gesture Sheet now supports both Static and Static Dual modes (left + right finger toggles, optional proximity slider)
- Optional sound feedback (NSSound "Tink") on every recognized gesture
- Optional system notifications (UNUserNotification) with the bound action description
- Transient menu-bar icon flash (checkmark.seal.fill, 1s) on gesture
- Self-test mode — walkthrough that prompts for each configured gesture and tracks pass/skip
- Live finger-state stream over the socket (`finger_states` event) with 5-dot HUD in the camera preview
- Custom motion gestures via Dynamic Time Warping — `python -m engine.main --record-motion <name>` records a YAML template, runtime DTW-matches new motion against templates
- Localization scaffolding: en + ko `Localizable.strings` covering menu bar, accessibility warning, preview, and settings strings
- VERSION single source + `scripts/release.sh` that bumps, changelogs, builds, tags, pushes, and creates the GitHub release in one shot

### Changed
- Universal binary (Intel + Apple Silicon) built via SwiftPM `--arch arm64 --arch x86_64`
- DMG packaging script under `scripts/make-dmg.sh` produces a drag-to-Applications installer

## [0.1.0] - 2026-04-28

### Added
- Initial public release
- Two-process architecture: SwiftUI menu bar app + Python MediaPipe engine, IPC over Unix Domain Socket
- 7 built-in single-hand gestures (thumbs_up, peace, fist, open_palm, ok_sign, swipe_left, swipe_right)
- 2 sample custom static poses (rock, phone) with user-defined 5-bit `pattern` field in YAML
- 3 dual-hand poses (high_five, double_peace, heart) via `static_dual` type with optional palm-proximity gating
- In-app Settings window: live hotkey recorder, per-gesture editor, type-aware Add Gesture sheet (single + dual modes)
- Camera preview window with on-demand JPEG streaming
- Launch-at-login (`SMAppService`)
- Optional system notification + sound feedback on gesture
- Transient menu-bar icon flash on recognition
- Universal binary build (Intel + Apple Silicon)
- DMG packaging script + GitHub release pipeline
- GitHub Actions CI (pytest + swift test on macos-latest)
