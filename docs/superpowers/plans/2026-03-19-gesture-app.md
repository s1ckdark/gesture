# Gesture App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that recognizes hand gestures via webcam and executes configured keyboard shortcuts or shell commands.

**Architecture:** Two-process architecture — a Python engine handles camera capture and gesture recognition via MediaPipe, communicating over a Unix Domain Socket with a Swift menu bar app that executes mapped actions (hotkeys, shell commands). Configuration is YAML-based at `~/.gesture/config.yaml`.

**Tech Stack:** Swift 5.9+ / SwiftUI / AppKit, Python 3.11+ / MediaPipe / OpenCV, Yams (Swift YAML), CGEvent API, Unix Domain Socket

**Spec:** `docs/superpowers/specs/2026-03-19-gesture-app-design.md`

---

## File Structure

### Python Engine (`engine/`)

| File | Responsibility |
|------|---------------|
| `engine/main.py` | Entry point, wires components, runs main loop |
| `engine/camera.py` | OpenCV camera capture, frame provider |
| `engine/detector.py` | MediaPipe Hands wrapper, landmark extraction |
| `engine/classifier.py` | StaticClassifier + MotionTracker + CooldownManager |
| `engine/socket_server.py` | Unix Domain Socket server, JSON message send/receive |
| `engine/requirements.txt` | Python dependencies |
| `engine/tests/test_classifier.py` | Classifier unit tests |
| `engine/tests/test_socket.py` | Socket protocol tests |
| `engine/tests/__init__.py` | Test package init |

### Swift App (`GestureApp/`)

| File | Responsibility |
|------|---------------|
| `GestureApp/Package.swift` | Swift Package Manager manifest |
| `GestureApp/Sources/GestureApp/GestureApp.swift` | @main entry, MenuBarExtra |
| `GestureApp/Sources/GestureApp/StatusBarController.swift` | Menu bar icon and status display |
| `GestureApp/Sources/GestureApp/SocketClient.swift` | Unix Socket client, JSON parsing |
| `GestureApp/Sources/GestureApp/ActionExecutor.swift` | Hotkey (CGEvent) and shell execution |
| `GestureApp/Sources/GestureApp/ConfigManager.swift` | YAML config loading and parsing |
| `GestureApp/Sources/GestureApp/ProcessManager.swift` | Python process lifecycle |
| `GestureApp/Sources/GestureApp/Models.swift` | Shared data types (GestureEvent, ActionConfig, etc.) |
| `GestureApp/Tests/GestureAppTests/ConfigManagerTests.swift` | Config parsing tests |
| `GestureApp/Tests/GestureAppTests/ActionExecutorTests.swift` | Action execution tests |
| `GestureApp/Tests/GestureAppTests/SocketClientTests.swift` | Socket message parsing tests |

### Config (`config/`)

| File | Responsibility |
|------|---------------|
| `config/default.yaml` | Default gesture-to-action mappings |

---

## Task 1: Project Scaffolding

**Files:**
- Create: `engine/requirements.txt`
- Create: `engine/tests/__init__.py`
- Create: `engine/__init__.py`
- Create: `GestureApp/Package.swift`
- Create: `GestureApp/Sources/GestureApp/Models.swift`
- Create: `GestureApp/Tests/GestureAppTests/.gitkeep`
- Create: `config/default.yaml`
- Create: `.gitignore`

- [ ] **Step 1: Create .gitignore**

```gitignore
# Python
engine/__pycache__/
engine/*.pyc
engine/venv/
engine/.venv/

# Swift
GestureApp/.build/
GestureApp/.swiftpm/
*.xcodeproj
*.xcworkspace
DerivedData/

# macOS
.DS_Store

# Gesture app
.superpowers/

# Socket
/tmp/gesture.sock
```

- [ ] **Step 2: Create Python engine requirements.txt**

```
mediapipe>=0.10.0
opencv-python>=4.8.0
pyyaml>=6.0
```

- [ ] **Step 3: Create Python package init files**

Create empty `engine/__init__.py` and `engine/tests/__init__.py`.

- [ ] **Step 4: Create Swift Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "GestureApp",
            dependencies: ["Yams"],
            path: "Sources/GestureApp"
        ),
        .testTarget(
            name: "GestureAppTests",
            dependencies: ["GestureApp"],
            path: "Tests/GestureAppTests"
        ),
    ]
)
```

- [ ] **Step 5: Create Models.swift with shared types**

```swift
import Foundation

struct GestureEvent: Codable {
    let type: String
    let name: String?
    let confidence: Double?
    let timestamp: Double?
    let handsDetected: Int?
    let fps: Double?

    enum CodingKeys: String, CodingKey {
        case type, name, confidence, timestamp
        case handsDetected = "hands_detected"
        case fps
    }
}

enum ActionType: String, Codable {
    case hotkey
    case shell
    case applescript
}

struct ActionConfig: Codable {
    let type: ActionType
    let keys: [String]?
    let command: String?
    let script: String?
}

struct GestureConfig: Codable {
    let type: String
    let action: ActionConfig
}

struct RecognitionConfig: Codable {
    let confidenceThreshold: Double
    let cooldownMs: Int
    let motionBufferFrames: Int
    let staticConfirmFrames: Int

    enum CodingKeys: String, CodingKey {
        case confidenceThreshold = "confidence_threshold"
        case cooldownMs = "cooldown_ms"
        case motionBufferFrames = "motion_buffer_frames"
        case staticConfirmFrames = "static_confirm_frames"
    }
}

struct CameraConfig: Codable {
    let device: Int
    let fps: Int
    let resolution: [Int]
}

struct AppConfig: Codable {
    let camera: CameraConfig
    let recognition: RecognitionConfig
    let gestures: [String: GestureConfig]
}
```

- [ ] **Step 6: Create default.yaml config**

```yaml
camera:
  device: 0
  fps: 30
  resolution: [640, 480]

recognition:
  confidence_threshold: 0.85
  cooldown_ms: 800
  motion_buffer_frames: 20
  static_confirm_frames: 3

gestures:
  thumbs_up:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "c"]

  peace:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "v"]

  fist:
    type: static
    action:
      type: shell
      command: "osascript -e 'tell application \"Spotify\" to playpause'"

  open_palm:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "tab"]

  ok_sign:
    type: static
    action:
      type: hotkey
      keys: ["cmd", "space"]

  swipe_left:
    type: motion
    action:
      type: shell
      command: "open -a 'Mission Control'"

  swipe_right:
    type: motion
    action:
      type: hotkey
      keys: ["cmd", "shift", "4"]
```

- [ ] **Step 7: Initialize git repo and commit**

```bash
cd /Users/dave/iWorks/gesture
git init
git add .gitignore engine/requirements.txt engine/__init__.py engine/tests/__init__.py
git add GestureApp/Package.swift GestureApp/Sources/GestureApp/Models.swift
git add config/default.yaml
git commit -m "chore: project scaffolding — Swift package, Python engine, default config"
```

---

## Task 2: Python — Static Gesture Classifier

**Files:**
- Create: `engine/classifier.py`
- Create: `engine/tests/test_classifier.py`

- [ ] **Step 1: Write failing tests for StaticClassifier**

```python
# engine/tests/test_classifier.py
import pytest
from engine.classifier import StaticClassifier

# MediaPipe landmark indices:
# 0=WRIST, 4=THUMB_TIP, 3=THUMB_IP, 8=INDEX_TIP, 6=INDEX_PIP,
# 12=MIDDLE_TIP, 10=MIDDLE_PIP, 16=RING_TIP, 14=RING_PIP,
# 20=PINKY_TIP, 18=PINKY_PIP

def _make_landmarks(finger_states):
    """Create mock landmarks from finger states [thumb, index, middle, ring, pinky].
    1 = extended, 0 = folded."""
    landmarks = [(0.5, 0.5, 0.0)] * 21  # 21 points, default center

    # Thumb: compare x-axis (tip.x > ip.x for right hand = extended)
    if finger_states[0]:
        landmarks[4] = (0.8, 0.5, 0.0)  # tip far right
        landmarks[3] = (0.6, 0.5, 0.0)  # ip closer
    else:
        landmarks[4] = (0.5, 0.5, 0.0)  # tip close
        landmarks[3] = (0.7, 0.5, 0.0)  # ip further

    # Index, Middle, Ring, Pinky: compare y-axis (tip.y < pip.y = extended)
    finger_tips = [8, 12, 16, 20]
    finger_pips = [6, 10, 14, 18]
    for i, (tip_idx, pip_idx) in enumerate(zip(finger_tips, finger_pips)):
        if finger_states[i + 1]:
            landmarks[tip_idx] = (0.5, 0.2, 0.0)  # tip above pip (y smaller)
            landmarks[pip_idx] = (0.5, 0.6, 0.0)
        else:
            landmarks[tip_idx] = (0.5, 0.8, 0.0)  # tip below pip (y larger)
            landmarks[pip_idx] = (0.5, 0.6, 0.0)

    return landmarks


class TestStaticClassifier:
    def setup_method(self):
        self.classifier = StaticClassifier()

    def test_thumbs_up(self):
        landmarks = _make_landmarks([1, 0, 0, 0, 0])
        assert self.classifier.classify(landmarks) == "thumbs_up"

    def test_peace(self):
        landmarks = _make_landmarks([0, 1, 1, 0, 0])
        assert self.classifier.classify(landmarks) == "peace"

    def test_fist(self):
        landmarks = _make_landmarks([0, 0, 0, 0, 0])
        assert self.classifier.classify(landmarks) == "fist"

    def test_open_palm(self):
        landmarks = _make_landmarks([1, 1, 1, 1, 1])
        assert self.classifier.classify(landmarks) == "open_palm"

    def test_unknown_gesture(self):
        landmarks = _make_landmarks([1, 1, 0, 0, 0])
        result = self.classifier.classify(landmarks)
        assert result is None  # not a defined gesture
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/dave/iWorks/gesture
python -m pytest engine/tests/test_classifier.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'engine.classifier'`

- [ ] **Step 3: Implement StaticClassifier**

```python
# engine/classifier.py
from typing import Optional

# Landmark indices
THUMB_TIP, THUMB_IP = 4, 3
INDEX_TIP, INDEX_PIP = 8, 6
MIDDLE_TIP, MIDDLE_PIP = 12, 10
RING_TIP, RING_PIP = 16, 14
PINKY_TIP, PINKY_PIP = 20, 18

# Pose definitions: [thumb, index, middle, ring, pinky]
STATIC_POSES = {
    "thumbs_up":  [1, 0, 0, 0, 0],
    "peace":      [0, 1, 1, 0, 0],
    "fist":       [0, 0, 0, 0, 0],
    "open_palm":  [1, 1, 1, 1, 1],
}


class StaticClassifier:
    """Classifies static hand poses based on finger extension states."""

    def _is_finger_extended(self, landmarks, tip_idx: int, pip_idx: int) -> bool:
        return landmarks[tip_idx][1] < landmarks[pip_idx][1]

    def _is_thumb_extended(self, landmarks) -> bool:
        return landmarks[THUMB_TIP][0] > landmarks[THUMB_IP][0]

    def _get_finger_states(self, landmarks) -> list[int]:
        thumb = int(self._is_thumb_extended(landmarks))
        index = int(self._is_finger_extended(landmarks, INDEX_TIP, INDEX_PIP))
        middle = int(self._is_finger_extended(landmarks, MIDDLE_TIP, MIDDLE_PIP))
        ring = int(self._is_finger_extended(landmarks, RING_TIP, RING_PIP))
        pinky = int(self._is_finger_extended(landmarks, PINKY_TIP, PINKY_PIP))
        return [thumb, index, middle, ring, pinky]

    def classify(self, landmarks) -> Optional[str]:
        states = self._get_finger_states(landmarks)
        for pose_name, pose_states in STATIC_POSES.items():
            if states == pose_states:
                return pose_name
        return None
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/dave/iWorks/gesture
python -m pytest engine/tests/test_classifier.py -v
```

Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add engine/classifier.py engine/tests/test_classifier.py
git commit -m "feat(engine): static gesture classifier with rule-based finger detection"
```

---

## Task 3: Python — OK Sign Detection

**Files:**
- Modify: `engine/classifier.py`
- Modify: `engine/tests/test_classifier.py`

- [ ] **Step 1: Write failing test for ok_sign**

Add to `engine/tests/test_classifier.py`:

```python
def test_ok_sign(self):
    """OK sign: thumb tip and index tip close together, other fingers extended."""
    landmarks = _make_landmarks([1, 1, 1, 1, 1])  # base: all extended
    # Move thumb tip and index tip close together
    landmarks[4] = (0.5, 0.4, 0.0)   # thumb tip
    landmarks[8] = (0.52, 0.42, 0.0)  # index tip — very close to thumb
    result = self.classifier.classify(landmarks)
    assert result == "ok_sign"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
python -m pytest engine/tests/test_classifier.py::TestStaticClassifier::test_ok_sign -v
```

Expected: FAIL — returns `"open_palm"` or `None` instead of `"ok_sign"`

- [ ] **Step 3: Add ok_sign detection to StaticClassifier**

Add to `engine/classifier.py` in `StaticClassifier.classify()`, **before** the STATIC_POSES loop:

```python
import math

# Add to StaticClassifier class:
def _distance(self, p1, p2) -> float:
    return math.sqrt((p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2)

# Update classify() method:
def classify(self, landmarks) -> Optional[str]:
    # Check ok_sign first (thumb+index tips close, others extended)
    thumb_index_dist = self._distance(landmarks[THUMB_TIP], landmarks[INDEX_TIP])
    if thumb_index_dist < 0.08:
        states = self._get_finger_states(landmarks)
        if states[2] == 1 and states[3] == 1 and states[4] == 1:  # middle, ring, pinky extended
            return "ok_sign"

    states = self._get_finger_states(landmarks)
    for pose_name, pose_states in STATIC_POSES.items():
        if states == pose_states:
            return pose_name
    return None
```

- [ ] **Step 4: Run all classifier tests**

```bash
python -m pytest engine/tests/test_classifier.py -v
```

Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add engine/classifier.py engine/tests/test_classifier.py
git commit -m "feat(engine): ok_sign detection via thumb-index distance"
```

---

## Task 4: Python — Motion Tracker

**Files:**
- Modify: `engine/classifier.py`
- Modify: `engine/tests/test_classifier.py`

- [ ] **Step 1: Write failing tests for MotionTracker**

Add to `engine/tests/test_classifier.py`:

```python
from engine.classifier import MotionTracker


class TestMotionTracker:
    def setup_method(self):
        self.tracker = MotionTracker(buffer_size=10, threshold=0.15)

    def test_no_motion_initially(self):
        self.tracker.update((0.5, 0.5))
        assert self.tracker.detect() is None

    def test_swipe_left(self):
        # Simulate hand moving left: x decreasing
        for i in range(10):
            self.tracker.update((0.8 - i * 0.05, 0.5))
        assert self.tracker.detect() == "swipe_left"

    def test_swipe_right(self):
        for i in range(10):
            self.tracker.update((0.2 + i * 0.05, 0.5))
        assert self.tracker.detect() == "swipe_right"

    def test_no_motion_when_stationary(self):
        for _ in range(10):
            self.tracker.update((0.5, 0.5))
        assert self.tracker.detect() is None

    def test_buffer_clears_after_detection(self):
        for i in range(10):
            self.tracker.update((0.8 - i * 0.05, 0.5))
        assert self.tracker.detect() == "swipe_left"
        # After detection, buffer should reset
        assert self.tracker.detect() is None
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python -m pytest engine/tests/test_classifier.py::TestMotionTracker -v
```

Expected: FAIL with `ImportError`

- [ ] **Step 3: Implement MotionTracker**

Add to `engine/classifier.py`:

```python
from collections import deque


class MotionTracker:
    """Detects directional swipe gestures from palm center trajectory."""

    def __init__(self, buffer_size: int = 20, threshold: float = 0.15):
        self.buffer: deque[tuple[float, float]] = deque(maxlen=buffer_size)
        self.threshold = threshold
        self.buffer_size = buffer_size

    def update(self, palm_center: tuple[float, float]):
        self.buffer.append(palm_center)

    def detect(self) -> Optional[str]:
        if len(self.buffer) < self.buffer_size:
            return None

        start = self.buffer[0]
        end = self.buffer[-1]
        dx = end[0] - start[0]
        dy = end[1] - start[1]

        result = None
        if abs(dx) > self.threshold and abs(dx) > abs(dy):
            result = "swipe_right" if dx > 0 else "swipe_left"
        elif abs(dy) > self.threshold and abs(dy) > abs(dx):
            result = "swipe_down" if dy > 0 else "swipe_up"

        if result:
            self.buffer.clear()

        return result
```

- [ ] **Step 4: Run all tests**

```bash
python -m pytest engine/tests/test_classifier.py -v
```

Expected: All 11 tests PASS

- [ ] **Step 5: Commit**

```bash
git add engine/classifier.py engine/tests/test_classifier.py
git commit -m "feat(engine): motion tracker with swipe detection"
```

---

## Task 5: Python — Cooldown Manager

**Files:**
- Modify: `engine/classifier.py`
- Modify: `engine/tests/test_classifier.py`

- [ ] **Step 1: Write failing tests for CooldownManager**

Add to `engine/tests/test_classifier.py`:

```python
import time
from engine.classifier import CooldownManager


class TestCooldownManager:
    def setup_method(self):
        self.cooldown = CooldownManager(cooldown_ms=100, confidence_threshold=0.85)

    def test_first_gesture_passes(self):
        assert self.cooldown.should_fire("thumbs_up", 0.9) is True

    def test_same_gesture_blocked_during_cooldown(self):
        self.cooldown.should_fire("thumbs_up", 0.9)
        assert self.cooldown.should_fire("thumbs_up", 0.9) is False

    def test_different_gesture_passes_during_cooldown(self):
        self.cooldown.should_fire("thumbs_up", 0.9)
        assert self.cooldown.should_fire("peace", 0.9) is True

    def test_low_confidence_blocked(self):
        assert self.cooldown.should_fire("thumbs_up", 0.5) is False

    def test_gesture_passes_after_cooldown(self):
        self.cooldown.should_fire("thumbs_up", 0.9)
        time.sleep(0.15)  # wait longer than 100ms cooldown
        assert self.cooldown.should_fire("thumbs_up", 0.9) is True
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python -m pytest engine/tests/test_classifier.py::TestCooldownManager -v
```

Expected: FAIL with `ImportError`

- [ ] **Step 3: Implement CooldownManager**

Add to `engine/classifier.py`:

```python
import time


class CooldownManager:
    """Prevents duplicate gesture firing and filters low-confidence results."""

    def __init__(self, cooldown_ms: int = 800, confidence_threshold: float = 0.85):
        self.cooldown_ms = cooldown_ms
        self.confidence_threshold = confidence_threshold
        self._last_fired: dict[str, float] = {}

    def should_fire(self, gesture: str, confidence: float) -> bool:
        if confidence < self.confidence_threshold:
            return False

        now = time.time() * 1000  # ms
        last = self._last_fired.get(gesture, 0)

        if now - last < self.cooldown_ms:
            return False

        self._last_fired[gesture] = now
        return True
```

- [ ] **Step 4: Run all tests**

```bash
python -m pytest engine/tests/test_classifier.py -v
```

Expected: All 16 tests PASS

- [ ] **Step 5: Commit**

```bash
git add engine/classifier.py engine/tests/test_classifier.py
git commit -m "feat(engine): cooldown manager for duplicate/low-confidence filtering"
```

---

## Task 6: Python — Camera Capture

**Files:**
- Create: `engine/camera.py`

- [ ] **Step 1: Implement camera capture module**

```python
# engine/camera.py
import cv2
from typing import Optional
import numpy as np


class Camera:
    """Captures frames from webcam via OpenCV."""

    def __init__(self, device: int = 0, width: int = 640, height: int = 480):
        self.device = device
        self.width = width
        self.height = height
        self._cap: Optional[cv2.VideoCapture] = None

    def start(self):
        self._cap = cv2.VideoCapture(self.device)
        self._cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
        self._cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)
        if not self._cap.isOpened():
            raise RuntimeError(f"Cannot open camera device {self.device}")

    def read(self) -> Optional[np.ndarray]:
        if self._cap is None:
            return None
        ret, frame = self._cap.read()
        if not ret:
            return None
        return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    def stop(self):
        if self._cap is not None:
            self._cap.release()
            self._cap = None

    @property
    def is_opened(self) -> bool:
        return self._cap is not None and self._cap.isOpened()
```

Note: Camera tests require hardware access so we skip unit tests here. Integration testing covers this.

- [ ] **Step 2: Commit**

```bash
git add engine/camera.py
git commit -m "feat(engine): camera capture module with OpenCV"
```

---

## Task 7: Python — MediaPipe Hand Detector

**Files:**
- Create: `engine/detector.py`

- [ ] **Step 1: Implement hand detector**

```python
# engine/detector.py
import mediapipe as mp
import numpy as np
from typing import Optional


class HandDetector:
    """Wraps MediaPipe Hands for landmark extraction."""

    def __init__(self, max_hands: int = 1, min_detection_confidence: float = 0.7,
                 min_tracking_confidence: float = 0.5):
        self._hands = mp.solutions.hands.Hands(
            static_image_mode=False,
            max_num_hands=max_hands,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )

    def detect(self, frame: np.ndarray) -> Optional[list[tuple[float, float, float]]]:
        """Returns list of 21 (x, y, z) landmarks for the first detected hand, or None."""
        results = self._hands.process(frame)
        if not results.multi_hand_landmarks:
            return None
        hand = results.multi_hand_landmarks[0]
        return [(lm.x, lm.y, lm.z) for lm in hand.landmark]

    def get_palm_center(self, landmarks: list[tuple[float, float, float]]) -> tuple[float, float]:
        """Returns palm center as average of wrist(0) and middle_finger_mcp(9)."""
        wrist = landmarks[0]
        mcp = landmarks[9]
        return ((wrist[0] + mcp[0]) / 2, (wrist[1] + mcp[1]) / 2)

    def close(self):
        self._hands.close()
```

Note: MediaPipe tests require model files. Integration testing covers this.

- [ ] **Step 2: Commit**

```bash
git add engine/detector.py
git commit -m "feat(engine): MediaPipe hand detector with landmark extraction"
```

---

## Task 8: Python — Unix Socket Server

**Files:**
- Create: `engine/socket_server.py`
- Create: `engine/tests/test_socket.py`

- [ ] **Step 1: Write failing tests for socket protocol**

```python
# engine/tests/test_socket.py
import json
import os
import socket
import threading
import time
import pytest
from engine.socket_server import GestureSocketServer


SOCKET_PATH = "/tmp/gesture_test.sock"


@pytest.fixture
def server():
    srv = GestureSocketServer(SOCKET_PATH)
    thread = threading.Thread(target=srv.start, daemon=True)
    thread.start()
    time.sleep(0.1)  # let server bind
    yield srv
    srv.stop()
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)


@pytest.fixture
def client(server):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)
    yield sock
    sock.close()


class TestSocketServer:
    def test_server_creates_socket_file(self, server):
        assert os.path.exists(SOCKET_PATH)

    def test_client_can_connect(self, client):
        assert client.fileno() > 0

    def test_send_gesture_event(self, server, client):
        server.send_gesture("thumbs_up", 0.95)
        time.sleep(0.05)
        data = client.recv(4096).decode()
        msg = json.loads(data.strip())
        assert msg["type"] == "gesture"
        assert msg["name"] == "thumbs_up"
        assert msg["confidence"] == 0.95

    def test_send_status(self, server, client):
        server.send_status(hands_detected=1, fps=30.0)
        time.sleep(0.05)
        data = client.recv(4096).decode()
        msg = json.loads(data.strip())
        assert msg["type"] == "status"
        assert msg["hands_detected"] == 1

    def test_cleanup_stale_socket(self, server):
        """If socket file exists from a previous run, server should clean it up."""
        server.stop()
        # Create stale socket file
        with open(SOCKET_PATH, "w") as f:
            f.write("")
        srv2 = GestureSocketServer(SOCKET_PATH)
        thread = threading.Thread(target=srv2.start, daemon=True)
        thread.start()
        time.sleep(0.1)
        assert os.path.exists(SOCKET_PATH)
        srv2.stop()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
python -m pytest engine/tests/test_socket.py -v
```

Expected: FAIL with `ModuleNotFoundError`

- [ ] **Step 3: Implement GestureSocketServer**

```python
# engine/socket_server.py
import json
import os
import socket
import time
from typing import Optional


class GestureSocketServer:
    """Unix Domain Socket server for sending gesture events to Swift app."""

    def __init__(self, socket_path: str = "/tmp/gesture.sock"):
        self.socket_path = socket_path
        self._server: Optional[socket.socket] = None
        self._client: Optional[socket.socket] = None
        self._running = False

    def start(self):
        # Clean up stale socket
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(self.socket_path)
        self._server.listen(1)
        self._server.settimeout(1.0)
        self._running = True

        while self._running:
            try:
                self._client, _ = self._server.accept()
                self._handle_client()
            except socket.timeout:
                continue
            except OSError:
                break

    def _handle_client(self):
        """Keep connection alive until client disconnects or server stops."""
        while self._running and self._client:
            try:
                # Check if client sent data (config updates, commands)
                self._client.settimeout(0.1)
                try:
                    data = self._client.recv(4096)
                    if not data:
                        break  # client disconnected
                except socket.timeout:
                    pass
            except OSError:
                break
        self._client = None

    def send_gesture(self, name: str, confidence: float):
        self._send({
            "type": "gesture",
            "name": name,
            "confidence": confidence,
            "timestamp": time.time(),
        })

    def send_status(self, hands_detected: int, fps: float):
        self._send({
            "type": "status",
            "hands_detected": hands_detected,
            "fps": fps,
        })

    def _send(self, msg: dict):
        if self._client is None:
            return
        try:
            data = json.dumps(msg) + "\n"
            self._client.sendall(data.encode())
        except (BrokenPipeError, OSError):
            self._client = None

    def stop(self):
        self._running = False
        if self._client:
            try:
                self._client.close()
            except OSError:
                pass
            self._client = None
        if self._server:
            try:
                self._server.close()
            except OSError:
                pass
            self._server = None
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)
```

- [ ] **Step 4: Run all socket tests**

```bash
python -m pytest engine/tests/test_socket.py -v
```

Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add engine/socket_server.py engine/tests/test_socket.py
git commit -m "feat(engine): Unix socket server with JSON protocol"
```

---

## Task 9: Python — Engine Main Loop

**Files:**
- Create: `engine/main.py`

- [ ] **Step 1: Implement engine entry point**

```python
# engine/main.py
import argparse
import signal
import sys
import threading
import time
import yaml

from engine.camera import Camera
from engine.detector import HandDetector
from engine.classifier import StaticClassifier, MotionTracker, CooldownManager
from engine.socket_server import GestureSocketServer


class GestureEngine:
    """Main engine loop: camera → detect → classify → send."""

    def __init__(self, config_path: str):
        with open(config_path) as f:
            self.config = yaml.safe_load(f)

        cam_cfg = self.config["camera"]
        rec_cfg = self.config["recognition"]

        self.camera = Camera(
            device=cam_cfg["device"],
            width=cam_cfg["resolution"][0],
            height=cam_cfg["resolution"][1],
        )
        self.detector = HandDetector()
        self.static_classifier = StaticClassifier()
        self.motion_tracker = MotionTracker(
            buffer_size=rec_cfg["motion_buffer_frames"],
        )
        self.cooldown = CooldownManager(
            cooldown_ms=rec_cfg["cooldown_ms"],
            confidence_threshold=rec_cfg["confidence_threshold"],
        )
        self.static_confirm_frames = rec_cfg.get("static_confirm_frames", 3)

        self.socket_server = GestureSocketServer()
        self._running = False
        self._static_buffer: list[str] = []

    def start(self):
        self._running = True

        # Start socket server in background thread
        server_thread = threading.Thread(target=self.socket_server.start, daemon=True)
        server_thread.start()

        self.camera.start()
        print("Gesture engine started. Waiting for Swift app connection...")

        frame_count = 0
        fps_start = time.time()

        try:
            while self._running:
                frame = self.camera.read()
                if frame is None:
                    continue

                landmarks = self.detector.detect(frame)
                hands_detected = 1 if landmarks else 0

                # Calculate FPS
                frame_count += 1
                elapsed = time.time() - fps_start
                if elapsed >= 1.0:
                    fps = frame_count / elapsed
                    self.socket_server.send_status(hands_detected, fps)
                    frame_count = 0
                    fps_start = time.time()

                if landmarks is None:
                    self._static_buffer.clear()
                    continue

                # Static gesture check
                static_gesture = self.static_classifier.classify(landmarks)
                if static_gesture:
                    self._static_buffer.append(static_gesture)
                    if len(self._static_buffer) >= self.static_confirm_frames:
                        # Check all recent frames agree
                        if all(g == static_gesture for g in self._static_buffer[-self.static_confirm_frames:]):
                            if self.cooldown.should_fire(static_gesture, 0.95):
                                self.socket_server.send_gesture(static_gesture, 0.95)
                            self._static_buffer.clear()
                else:
                    self._static_buffer.clear()

                # Motion gesture check
                palm = self.detector.get_palm_center(landmarks)
                self.motion_tracker.update(palm)
                motion_gesture = self.motion_tracker.detect()
                if motion_gesture:
                    if self.cooldown.should_fire(motion_gesture, 0.90):
                        self.socket_server.send_gesture(motion_gesture, 0.90)

        except KeyboardInterrupt:
            pass
        finally:
            self.stop()

    def stop(self):
        self._running = False
        self.camera.stop()
        self.detector.close()
        self.socket_server.stop()
        print("Gesture engine stopped.")


def main():
    import os
    parser = argparse.ArgumentParser(description="Gesture Recognition Engine")
    parser.add_argument(
        "--config",
        default=os.path.expanduser("~/.gesture/config.yaml"),
        help="Path to config file",
    )
    args = parser.parse_args()
    engine = GestureEngine(args.config)

    def handle_signal(sig, frame):
        engine.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    engine.start()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit**

```bash
git add engine/main.py
git commit -m "feat(engine): main loop wiring camera, detector, classifier, socket"
```

---

## Task 10: Swift — Config Manager

**Files:**
- Create: `GestureApp/Sources/GestureApp/ConfigManager.swift`
- Create: `GestureApp/Tests/GestureAppTests/ConfigManagerTests.swift`

- [ ] **Step 1: Write failing test for config parsing**

```swift
// GestureApp/Tests/GestureAppTests/ConfigManagerTests.swift
import XCTest
@testable import GestureApp

final class ConfigManagerTests: XCTestCase {
    let sampleYaml = """
    camera:
      device: 0
      fps: 30
      resolution: [640, 480]
    recognition:
      confidence_threshold: 0.85
      cooldown_ms: 800
      motion_buffer_frames: 20
      static_confirm_frames: 3
    gestures:
      thumbs_up:
        type: static
        action:
          type: hotkey
          keys: ["cmd", "c"]
      swipe_left:
        type: motion
        action:
          type: shell
          command: "open -a 'Mission Control'"
    """

    func testParseConfig() throws {
        let config = try ConfigManager.parse(yaml: sampleYaml)
        XCTAssertEqual(config.camera.device, 0)
        XCTAssertEqual(config.camera.fps, 30)
        XCTAssertEqual(config.recognition.confidenceThreshold, 0.85)
        XCTAssertEqual(config.recognition.cooldownMs, 800)
    }

    func testParseGestures() throws {
        let config = try ConfigManager.parse(yaml: sampleYaml)
        XCTAssertEqual(config.gestures.count, 2)

        let thumbsUp = config.gestures["thumbs_up"]
        XCTAssertNotNil(thumbsUp)
        XCTAssertEqual(thumbsUp?.type, "static")
        XCTAssertEqual(thumbsUp?.action.type, .hotkey)
        XCTAssertEqual(thumbsUp?.action.keys, ["cmd", "c"])

        let swipeLeft = config.gestures["swipe_left"]
        XCTAssertEqual(swipeLeft?.action.type, .shell)
        XCTAssertEqual(swipeLeft?.action.command, "open -a 'Mission Control'")
    }

    func testLoadDefaultConfig() throws {
        // Test that we can load the bundled default config
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configPath = projectRoot.appendingPathComponent("config/default.yaml").path
        let config = try ConfigManager.load(from: configPath)
        XCTAssertFalse(config.gestures.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test 2>&1 | head -30
```

Expected: FAIL — `ConfigManager` not defined

- [ ] **Step 3: Implement ConfigManager**

```swift
// GestureApp/Sources/GestureApp/ConfigManager.swift
import Foundation
import Yams

enum ConfigError: Error, LocalizedError {
    case fileNotFound(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "Config file not found: \(path)"
        case .parseError(let msg): return "Config parse error: \(msg)"
        }
    }
}

struct ConfigManager {
    static func load(from path: String) throws -> AppConfig {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path)
        }
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(yaml: yaml)
    }

    static func parse(yaml: String) throws -> AppConfig {
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(AppConfig.self, from: yaml)
        } catch {
            throw ConfigError.parseError(error.localizedDescription)
        }
    }

    static func defaultConfigPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.gesture/config.yaml"
    }

    static func ensureDefaultConfig(bundledConfigPath: String) throws {
        let targetPath = defaultConfigPath()
        let targetDir = (targetPath as NSString).deletingLastPathComponent

        if !FileManager.default.fileExists(atPath: targetPath) {
            try FileManager.default.createDirectory(
                atPath: targetDir,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(atPath: bundledConfigPath, toPath: targetPath)
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test --filter ConfigManagerTests 2>&1
```

Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add GestureApp/Sources/GestureApp/ConfigManager.swift
git add GestureApp/Tests/GestureAppTests/ConfigManagerTests.swift
git commit -m "feat(app): config manager with YAML parsing via Yams"
```

---

## Task 11: Swift — Socket Client

**Files:**
- Create: `GestureApp/Sources/GestureApp/SocketClient.swift`
- Create: `GestureApp/Tests/GestureAppTests/SocketClientTests.swift`

- [ ] **Step 1: Write failing test for message parsing**

```swift
// GestureApp/Tests/GestureAppTests/SocketClientTests.swift
import XCTest
@testable import GestureApp

final class SocketClientTests: XCTestCase {
    func testParseGestureEvent() throws {
        let json = """
        {"type": "gesture", "name": "thumbs_up", "confidence": 0.95, "timestamp": 1710841200}
        """
        let event = try SocketClient.parseMessage(json)
        XCTAssertEqual(event.type, "gesture")
        XCTAssertEqual(event.name, "thumbs_up")
        XCTAssertEqual(event.confidence, 0.95)
    }

    func testParseStatusEvent() throws {
        let json = """
        {"type": "status", "hands_detected": 1, "fps": 28.5}
        """
        let event = try SocketClient.parseMessage(json)
        XCTAssertEqual(event.type, "status")
        XCTAssertEqual(event.handsDetected, 1)
        XCTAssertEqual(event.fps, 28.5)
    }

    func testParseMultipleMessages() throws {
        let data = """
        {"type": "gesture", "name": "peace", "confidence": 0.9, "timestamp": 1}
        {"type": "status", "hands_detected": 0, "fps": 30.0}
        """
        let events = SocketClient.parseMessages(data)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].name, "peace")
        XCTAssertEqual(events[1].type, "status")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test --filter SocketClientTests 2>&1 | head -20
```

Expected: FAIL

- [ ] **Step 3: Implement SocketClient**

```swift
// GestureApp/Sources/GestureApp/SocketClient.swift
import Foundation

class SocketClient {
    private let socketPath: String
    private var fileHandle: FileHandle?
    private var inputStream: InputStream?
    private var isConnected = false
    var onGesture: ((GestureEvent) -> Void)?
    var onStatus: ((GestureEvent) -> Void)?
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
                    // Process complete lines
                    while let newlineRange = buffer.range(of: "\n") {
                        let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                        buffer = String(buffer[newlineRange.upperBound...])
                        if let event = try? Self.parseMessage(line) {
                            DispatchQueue.main.async {
                                switch event.type {
                                case "gesture": self.onGesture?(event)
                                case "status": self.onStatus?(event)
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

    func disconnect() {
        isConnected = false
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test --filter SocketClientTests 2>&1
```

Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add GestureApp/Sources/GestureApp/SocketClient.swift
git add GestureApp/Tests/GestureAppTests/SocketClientTests.swift
git commit -m "feat(app): Unix socket client with JSON message parsing"
```

---

## Task 12: Swift — Action Executor

**Files:**
- Create: `GestureApp/Sources/GestureApp/ActionExecutor.swift`
- Create: `GestureApp/Tests/GestureAppTests/ActionExecutorTests.swift`

- [ ] **Step 1: Write failing test for key code mapping**

```swift
// GestureApp/Tests/GestureAppTests/ActionExecutorTests.swift
import XCTest
@testable import GestureApp

final class ActionExecutorTests: XCTestCase {
    func testKeyCodeMapping() {
        XCTAssertEqual(ActionExecutor.keyCode(for: "c"), 8)
        XCTAssertEqual(ActionExecutor.keyCode(for: "v"), 9)
        XCTAssertEqual(ActionExecutor.keyCode(for: "space"), 49)
        XCTAssertEqual(ActionExecutor.keyCode(for: "tab"), 48)
        XCTAssertEqual(ActionExecutor.keyCode(for: "enter"), 36)
        XCTAssertNil(ActionExecutor.keyCode(for: "nonexistent"))
    }

    func testModifierFlags() {
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "cmd"), CGEventFlags.maskCommand)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "shift"), CGEventFlags.maskShift)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "ctrl"), CGEventFlags.maskControl)
        XCTAssertEqual(ActionExecutor.modifierFlag(for: "opt"), CGEventFlags.maskAlternate)
        XCTAssertNil(ActionExecutor.modifierFlag(for: "x"))
    }

    func testBuildShellAction() {
        let config = ActionConfig(type: .shell, keys: nil, command: "echo hello", script: nil)
        // Just verify it doesn't crash — actual execution needs shell
        XCTAssertEqual(config.command, "echo hello")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test --filter ActionExecutorTests 2>&1 | head -20
```

Expected: FAIL

- [ ] **Step 3: Implement ActionExecutor**

```swift
// GestureApp/Sources/GestureApp/ActionExecutor.swift
import Foundation
import CoreGraphics

class ActionExecutor {
    static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,
        "space": 49, "tab": 48, "enter": 36, "esc": 53,
        "delete": 51, "backspace": 51,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    static func keyCode(for key: String) -> CGKeyCode? {
        keyCodes[key.lowercased()]
    }

    static func modifierFlag(for key: String) -> CGEventFlags? {
        switch key.lowercased() {
        case "cmd", "command": return .maskCommand
        case "shift": return .maskShift
        case "ctrl", "control": return .maskControl
        case "opt", "option", "alt": return .maskAlternate
        default: return nil
        }
    }

    func execute(action: ActionConfig) {
        switch action.type {
        case .hotkey:
            executeHotkey(keys: action.keys ?? [])
        case .shell:
            executeShell(command: action.command ?? "")
        case .applescript:
            break // post-MVP
        }
    }

    private func executeHotkey(keys: [String]) {
        guard !keys.isEmpty else { return }

        // Separate modifiers from the main key
        var modifiers = CGEventFlags()
        var mainKey: CGKeyCode?

        for key in keys {
            if let flag = Self.modifierFlag(for: key) {
                modifiers.insert(flag)
            } else if let code = Self.keyCode(for: key) {
                mainKey = code
            }
        }

        guard let keyCode = mainKey else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = modifiers
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func executeShell(command: String) {
        guard !command.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Shell execution failed: \(error)")
            }
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test --filter ActionExecutorTests 2>&1
```

Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add GestureApp/Sources/GestureApp/ActionExecutor.swift
git add GestureApp/Tests/GestureAppTests/ActionExecutorTests.swift
git commit -m "feat(app): action executor with CGEvent hotkeys and shell commands"
```

---

## Task 13: Swift — Process Manager

**Files:**
- Create: `GestureApp/Sources/GestureApp/ProcessManager.swift`

- [ ] **Step 1: Implement ProcessManager**

```swift
// GestureApp/Sources/GestureApp/ProcessManager.swift
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
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-m", "engine.main", "--config", configPath]
        // enginePath points to engine/main.py — go up twice to reach project root
        process.currentDirectoryURL = URL(fileURLWithPath: enginePath)
            .deletingLastPathComponent()  // engine/
            .deletingLastPathComponent()  // project root

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
```

- [ ] **Step 2: Commit**

```bash
git add GestureApp/Sources/GestureApp/ProcessManager.swift
git commit -m "feat(app): Python process lifecycle manager with auto-restart"
```

---

## Task 14: Swift — Menu Bar App & Status Bar Controller

**Files:**
- Create: `GestureApp/Sources/GestureApp/GestureApp.swift`
- Create: `GestureApp/Sources/GestureApp/StatusBarController.swift`

- [ ] **Step 1: Implement StatusBarController**

```swift
// GestureApp/Sources/GestureApp/StatusBarController.swift
import SwiftUI

enum AppStatus {
    case stopped
    case running
    case handDetected

    var icon: String {
        switch self {
        case .stopped: return "hand.raised.slash"
        case .running: return "hand.raised"
        case .handDetected: return "hand.raised.fill"
        }
    }

    var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .handDetected: return "Hand Detected"
        }
    }
}

class StatusBarController: ObservableObject {
    @Published var status: AppStatus = .stopped
    @Published var fps: Double = 0
    @Published var lastGesture: String = ""
    @Published var isEngineRunning = false

    func updateStatus(_ event: GestureEvent) {
        if event.type == "status" {
            fps = event.fps ?? 0
            status = (event.handsDetected ?? 0) > 0 ? .handDetected : .running
        }
    }

    func gestureRecognized(_ name: String) {
        lastGesture = name
        // Clear after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.lastGesture == name {
                self?.lastGesture = ""
            }
        }
    }
}
```

- [ ] **Step 2: Implement GestureApp main entry**

```swift
// GestureApp/Sources/GestureApp/GestureApp.swift
import SwiftUI

@main
struct GestureApp: App {
    @StateObject private var statusBar = StatusBarController()
    @State private var processManager: ProcessManager?
    @State private var socketClient: SocketClient?
    @State private var actionExecutor = ActionExecutor()
    @State private var config: AppConfig?

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

                Divider()

                Button(statusBar.isEngineRunning ? "Stop" : "Start") {
                    toggleEngine()
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

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
        } label: {
            Image(systemName: statusBar.status.icon)
        }
        .menuBarExtraStyle(.window)
        .onAppear {
            reloadConfig()
        }
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

        // Find engine path relative to app bundle or working directory
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
            print("Failed to start engine: \(error)")
        }
    }

    private var socketRetryCount = 0
    private let maxSocketRetries = 5

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
        // Look for engine relative to the working directory
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            "\(cwd)/engine/main.py",
            Bundle.main.resourcePath.map { "\($0)/engine/main.py" } ?? "",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "\(cwd)/engine/main.py"
    }
}
```

- [ ] **Step 3: Verify build compiles**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift build 2>&1 | tail -5
```

Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add GestureApp/Sources/GestureApp/GestureApp.swift
git add GestureApp/Sources/GestureApp/StatusBarController.swift
git commit -m "feat(app): menu bar app with start/stop toggle and status display"
```

---

## Task 15: Integration — Python venv Setup & End-to-End Smoke Test

**Files:**
- Create: `scripts/setup.sh`
- Create: `scripts/run-engine.sh`

- [ ] **Step 1: Create setup script**

```bash
#!/bin/bash
# scripts/setup.sh — One-time project setup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up Gesture app..."

# Python venv
echo "Creating Python virtual environment..."
cd "$PROJECT_DIR/engine"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Default config
CONFIG_DIR="$HOME/.gesture"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    echo "Copying default config to $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    cp "$PROJECT_DIR/config/default.yaml" "$CONFIG_DIR/config.yaml"
fi

# Swift dependencies
echo "Resolving Swift packages..."
cd "$PROJECT_DIR/GestureApp"
swift package resolve

echo "Setup complete!"
echo "  Config: $CONFIG_DIR/config.yaml"
echo "  Run engine: scripts/run-engine.sh"
echo "  Build app:  cd GestureApp && swift build"
```

- [ ] **Step 2: Create engine run script**

```bash
#!/bin/bash
# scripts/run-engine.sh — Run the Python gesture engine standalone
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
source engine/.venv/bin/activate

CONFIG="${1:-$HOME/.gesture/config.yaml}"
python -m engine.main --config "$CONFIG"
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x /Users/dave/iWorks/gesture/scripts/setup.sh
chmod +x /Users/dave/iWorks/gesture/scripts/run-engine.sh
```

- [ ] **Step 4: Run setup**

```bash
cd /Users/dave/iWorks/gesture
./scripts/setup.sh
```

Expected: venv created, packages installed, default config copied

- [ ] **Step 5: Run Python tests**

```bash
cd /Users/dave/iWorks/gesture
source engine/.venv/bin/activate
python -m pytest engine/tests/ -v
```

Expected: All tests PASS

- [ ] **Step 6: Run Swift tests**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift test 2>&1
```

Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/setup.sh scripts/run-engine.sh
git commit -m "feat: setup and run scripts for project bootstrapping"
```

---

## Task 16: Final — Build & Manual Smoke Test

- [ ] **Step 1: Build Swift app**

```bash
cd /Users/dave/iWorks/gesture/GestureApp
swift build -c release 2>&1
```

Expected: Build succeeds

- [ ] **Step 2: Start engine manually to test camera**

```bash
cd /Users/dave/iWorks/gesture
./scripts/run-engine.sh
```

Expected: "Gesture engine started. Waiting for Swift app connection..."
Verify camera permission dialog appears. Press Ctrl+C to stop.

- [ ] **Step 3: Test full flow**

1. Start the engine: `./scripts/run-engine.sh`
2. In another terminal, run the app: `cd GestureApp && swift run`
3. Verify menu bar icon appears
4. Show hand to camera — verify "Hand Detected" status
5. Make thumbs up gesture — verify Cmd+C is triggered
6. Swipe left — verify Mission Control opens
7. Click "Stop" in menu bar — verify engine stops

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "chore: finalize MVP — gesture recognition app ready for testing"
```
