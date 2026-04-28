# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
