# Gesture

A macOS menu bar app that recognizes hand gestures via webcam and runs configured keyboard shortcuts or shell commands.

Two-process architecture:

```
┌─────────────┐         ┌──────────────────┐
│ Swift App   │         │ Python Engine    │
│ MenuBarExtra│◄──────► │ MediaPipe Hands  │
│ Hotkey/Shell│  Unix   │ Camera (OpenCV)  │
│ executor    │ Socket  │ Classifier       │
└─────────────┘  JSONL  └──────────────────┘
       │                        │
       ▼                        ▼
~/.gesture/config.yaml    Camera (AVFoundation)
```

## Features

- **7 built-in poses & motions** — thumbs_up, peace, fist, open_palm, ok_sign, swipe_left, swipe_right
- **Custom static poses** — define your own 5-finger patterns directly in YAML, no code changes
- **Action types** — keyboard shortcut (CGEvent) or shell command (zsh)
- **In-app editor** — Settings window lets you remap any gesture to any shortcut, with live key recorder
- **Camera preview** — debug window streams a downsampled live feed when you need to verify positioning
- **Launch at login** — toggleable from the menu
- **Stable recognition** — N-frame confirmation for static poses, 800ms cooldown to prevent runaway repeats

## Quick start

Requirements: macOS 13+, Python 3.11+, Xcode command line tools.

```bash
git clone https://github.com/s1ckdark/gesture.git
cd gesture
./scripts/setup.sh           # creates engine/.venv, installs deps, copies default config
./scripts/make-app.sh debug  # builds Swift app + wraps in proper .app bundle
open dist/GestureApp.app
```

The first time you run it macOS will ask for:

- **Camera access** — needed by the Python engine for hand detection
- **Accessibility access** — needed by the Swift app to post keyboard events

The menu bar shows a warning row with a button that jumps straight to the right System Settings pane if either permission is missing.

## Default mappings

The bundled `config/default.yaml` ships with these gesture-to-action pairs (edit `~/.gesture/config.yaml` or use the Settings window to change them):

| Gesture | Action |
|---------|--------|
| 👍 thumbs_up | ⌘C |
| ✌️ peace | ⌘V |
| ✊ fist | Spotify play/pause |
| 🖐️ open_palm | ⌘Tab |
| 👌 ok_sign | ⌘Space (Spotlight) |
| 🤘 rock | ⌘⇧M (Zoom mute mic) |
| 🤙 phone | ⌘⇧V (Zoom toggle camera) |
| swipe_left | open Mission Control |
| swipe_right | ⌘⇧4 (region screenshot) |

## Custom poses

Static poses are described as a 5-bit finger pattern: `[thumb, index, middle, ring, pinky]` where `1` means extended and `0` means folded. Add a `pattern` field under any gesture name in your config:

```yaml
gestures:
  spider:                       # made-up name
    type: static
    pattern: [1, 1, 0, 0, 1]    # thumb, index, pinky extended
    action:
      type: hotkey
      keys: ["cmd", "shift", "s"]
```

Reload via menu → "Reload Config". Pattern conflicts with the built-ins (thumbs_up, peace, fist, open_palm) override the defaults if you give them the same name.

You can also add new poses from inside the app: open Settings → click the **+** button → name + finger toggles + action.

## Two-handed poses

Use `type: static_dual` and supply patterns for both the user's left and right hands. Both must match for the pose to fire — dual matches are checked before single-hand poses when two hands are visible.

```yaml
gestures:
  high_five:
    type: static_dual
    pattern_left:  [1, 1, 1, 1, 1]   # open palm
    pattern_right: [1, 1, 1, 1, 1]
    action:
      type: shell
      command: "afplay /System/Library/Sounds/Glass.aiff"
```

Note: handedness is from your perspective (subject), not the camera's. MediaPipe labels them automatically.

## Development

```bash
# Python engine — 21 tests
source engine/.venv/bin/activate
python -m pytest engine/tests/ -v

# Swift app — 9 tests
cd GestureApp && swift test

# Run engine standalone (logs to terminal)
./scripts/run-engine.sh

# Watch engine logs when launched via the .app bundle
tail -f ~/.gesture/engine.log
```

The engine writes structured JSONL events over `/tmp/gesture.sock`. You can connect any client and stream gesture/status/frame events for tooling.

## Tech stack

- **Swift 5.9+ / SwiftUI / AppKit** — `MenuBarExtra`, `Window` scenes, `CGEvent`, `SMAppService`, `Yams` for YAML
- **Python 3.11+ / MediaPipe Tasks API** — `HandLandmarker` (VIDEO mode), `OpenCV` for camera + JPEG, `pyyaml`
- **Unix Domain Socket** — newline-delimited JSON, single-client

## License

MIT — see `LICENSE` once added.
