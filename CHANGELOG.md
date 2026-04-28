# Changelog

All notable changes to this project will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [SemVer](https://semver.org/).

## [Unreleased]

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
