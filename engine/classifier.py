import math
import time
from collections import deque
from typing import Optional

from engine.landmarks import (
    INDEX_TIP, THUMB_TIP,
    finger_states as compute_finger_states,
    palm_center as compute_palm_center,
)

# Pose definitions: [thumb, index, middle, ring, pinky]
STATIC_POSES = {
    "thumbs_up": [1, 0, 0, 0, 0],
    "peace":     [0, 1, 1, 0, 0],
    "fist":      [0, 0, 0, 0, 0],
    "open_palm": [1, 1, 1, 1, 1],
}


class StaticClassifier:
    """Classifies static hand poses based on finger extension states.

    Built-in poses live in STATIC_POSES; user-defined poses can be supplied
    via the `custom_poses` argument and will override built-ins of the same
    name (or extend the set with new pose names).
    """

    def __init__(self, custom_poses: Optional[dict] = None,
                 ok_sign_distance: float = 0.08):
        self.poses = dict(STATIC_POSES)
        if custom_poses:
            self.poses.update(custom_poses)
        self.ok_sign_distance = ok_sign_distance

    def classify(self, landmarks) -> Optional[str]:
        states = compute_finger_states(landmarks)
        # Check ok_sign first (thumb+index tips close, middle/ring/pinky extended)
        ti = landmarks[THUMB_TIP]; ii = landmarks[INDEX_TIP]
        thumb_index_dist = math.sqrt((ti[0] - ii[0]) ** 2 + (ti[1] - ii[1]) ** 2)
        if thumb_index_dist < self.ok_sign_distance:
            if states[2] == 1 and states[3] == 1 and states[4] == 1:
                return "ok_sign"

        for pose_name, pose_states in self.poses.items():
            if states == pose_states:
                return pose_name
        return None


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


class DualMotionClassifier:
    """Coordinated two-hand motions (e.g. both swipe outward = 'spread').

    Each hand runs its own MotionTracker. When both fire within sync_window,
    the (left_motion, right_motion) pair is matched against templates.

    `dual_motions` maps gesture name → {"left": "<dir>", "right": "<dir>"}
    where <dir> is one of "swipe_left" | "swipe_right" | "swipe_up" | "swipe_down".
    """

    def __init__(self, dual_motions: Optional[dict] = None,
                 buffer_size: int = 20, threshold: float = 0.15,
                 sync_window: float = 0.6):
        self.dual_motions = dict(dual_motions or {})
        self.left = MotionTracker(buffer_size=buffer_size, threshold=threshold)
        self.right = MotionTracker(buffer_size=buffer_size, threshold=threshold)
        self.sync_window = sync_window
        self._pending_left: Optional[str] = None
        self._pending_right: Optional[str] = None
        self._pending_left_t = 0.0
        self._pending_right_t = 0.0

    def update(self, hands):
        """`hands` is a list of (landmarks, handedness_label)."""
        for landmarks, label in hands:
            palm = compute_palm_center(landmarks)
            if label == "Left":
                self.left.update(palm)
            elif label == "Right":
                self.right.update(palm)

    def detect(self) -> Optional[str]:
        if not self.dual_motions:
            return None
        now = time.time()

        l = self.left.detect()
        r = self.right.detect()
        if l:
            self._pending_left = l
            self._pending_left_t = now
        if r:
            self._pending_right = r
            self._pending_right_t = now

        # Expire stale pendings
        if self._pending_left and now - self._pending_left_t > self.sync_window:
            self._pending_left = None
        if self._pending_right and now - self._pending_right_t > self.sync_window:
            self._pending_right = None

        if self._pending_left and self._pending_right:
            if abs(self._pending_left_t - self._pending_right_t) <= self.sync_window:
                for name, pose in self.dual_motions.items():
                    if pose.get("left") == self._pending_left and \
                       pose.get("right") == self._pending_right:
                        self._pending_left = None
                        self._pending_right = None
                        return name
        return None


class DualHandClassifier:
    """Classifies two-handed static poses using per-hand 5-bit finger patterns,
    with optional palm-center proximity gating.

    `dual_poses` maps gesture name → {
        "left":  [5 bits],
        "right": [5 bits],
        "proximity": Optional[float]   # max palm-center distance in normalized coords
    }
    Both hands must match (by handedness label); when proximity is set, the
    palms must also be within that distance for the pose to fire.
    """

    def __init__(self, dual_poses: Optional[dict] = None):
        self.poses = dict(dual_poses or {})

    def classify(self, hands) -> Optional[str]:
        """`hands` is a list of (landmarks, handedness_label) tuples."""
        if len(hands) != 2 or not self.poses:
            return None
        observed = {}
        centers = {}
        for landmarks, label in hands:
            observed[label] = compute_finger_states(landmarks)
            centers[label] = compute_palm_center(landmarks)
        if "Left" not in observed or "Right" not in observed:
            return None

        dx = centers["Left"][0] - centers["Right"][0]
        dy = centers["Left"][1] - centers["Right"][1]
        palm_distance = math.sqrt(dx * dx + dy * dy)

        for name, pose in self.poses.items():
            if observed["Left"] != pose.get("left") or observed["Right"] != pose.get("right"):
                continue
            proximity = pose.get("proximity")
            if proximity is not None and palm_distance > proximity:
                continue
            return name
        return None


def dtw_distance(seq_a, seq_b) -> float:
    """Standard O(N*M) Dynamic Time Warping distance between two 2D point sequences,
    normalized by max(len) so longer sequences don't artificially balloon the cost."""
    n, m = len(seq_a), len(seq_b)
    if n == 0 or m == 0:
        return float("inf")

    inf = float("inf")
    dp = [[inf] * (m + 1) for _ in range(n + 1)]
    dp[0][0] = 0.0

    for i in range(1, n + 1):
        ax, ay = seq_a[i - 1][0], seq_a[i - 1][1]
        for j in range(1, m + 1):
            bx, by = seq_b[j - 1][0], seq_b[j - 1][1]
            cost = math.sqrt((ax - bx) ** 2 + (ay - by) ** 2)
            dp[i][j] = cost + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])

    return dp[n][m] / max(n, m)


def _normalize_trajectory(points):
    """Translate so first point is at origin — makes DTW position-invariant."""
    if not points:
        return []
    x0, y0 = points[0][0], points[0][1]
    return [(p[0] - x0, p[1] - y0) for p in points]


class CustomMotionClassifier:
    """DTW-based matcher for user-recorded motion templates.

    `templates` is a dict: gesture_name → list of (x, y) palm-center points.
    Buffer the live palm centers, periodically run DTW against every template,
    and fire when the best distance is below `threshold`.
    """

    def __init__(self, templates: Optional[dict] = None, threshold: float = 0.12,
                 buffer_size: int = 30):
        self.templates = dict(templates or {})
        self.threshold = threshold
        self.buffer: deque = deque(maxlen=buffer_size)
        self.buffer_size = buffer_size

    def update(self, palm: tuple):
        self.buffer.append(palm)

    def detect(self) -> Optional[str]:
        if len(self.buffer) < self.buffer_size or not self.templates:
            return None

        observed = _normalize_trajectory(list(self.buffer))
        best_name, best_dist = None, float("inf")
        for name, template in self.templates.items():
            t_norm = _normalize_trajectory(template)
            dist = dtw_distance(observed, t_norm)
            if dist < best_dist:
                best_dist = dist
                best_name = name

        if best_name is not None and best_dist < self.threshold:
            self.buffer.clear()
            return best_name
        return None


class _RecentBuffer:
    """Rolling list of (gesture, timestamp_ms) trimmed to `max_window_ms`.
    Shared between SequenceClassifier and ChordClassifier so they don't
    each re-implement the same record + prune dance.
    """

    def __init__(self, max_window_ms: float):
        self._items: list = []
        self._max_window = max_window_ms

    def record(self, gesture: str):
        now = time.time() * 1000
        self._items.append((gesture, now))
        if self._max_window > 0:
            self._items = [(g, t) for g, t in self._items if now - t <= self._max_window]

    @property
    def items(self) -> list:
        return self._items

    def remove(self, names) -> None:
        bad = set(names)
        self._items = [(g, t) for g, t in self._items if g not in bad]

    def clear(self) -> None:
        self._items = []


class SequenceClassifier:
    """Detects ordered gesture sequences within a time window.

    `sequences` maps macro_name → {"sequence": [name, ...], "window_ms": int}.
    Caller must invoke `record(name)` for every fired gesture; the classifier
    keeps a rolling buffer trimmed to the longest configured window and
    reports a match when the most recent N records equal a sequence and
    span ≤ that sequence's window.
    """

    def __init__(self, sequences: Optional[dict] = None):
        self.sequences = dict(sequences or {})
        max_window = max(
            (s.get("window_ms", 0) for s in self.sequences.values()),
            default=0,
        )
        self._buffer = _RecentBuffer(max_window)

    def record(self, gesture: str):
        self._buffer.record(gesture)

    def detect(self) -> Optional[str]:
        recent = self._buffer.items
        if not self.sequences or not recent:
            return None
        for name, spec in self.sequences.items():
            seq = spec.get("sequence") or []
            window = spec.get("window_ms", 0)
            n = len(seq)
            if n == 0 or len(recent) < n:
                continue
            tail = recent[-n:]
            tail_names = [g for g, _ in tail]
            if tail_names == seq and (tail[-1][1] - tail[0][1]) <= window:
                self._buffer.clear()
                return name
        return None


class ChordClassifier:
    """Like SequenceClassifier but order-independent. Fires when ALL gestures
    in a chord have been recorded within `window_ms` of each other.
    """

    def __init__(self, chords: Optional[dict] = None):
        self.chords = dict(chords or {})
        max_window = max(
            (c.get("window_ms", 0) for c in self.chords.values()),
            default=0,
        )
        self._buffer = _RecentBuffer(max_window)

    def record(self, gesture: str):
        self._buffer.record(gesture)

    def detect(self) -> Optional[str]:
        recent = self._buffer.items
        if not self.chords or not recent:
            return None
        for name, spec in self.chords.items():
            target = set(spec.get("gestures") or [])
            window = spec.get("window_ms", 0)
            if not target:
                continue
            latest_for: dict = {}
            for g, t in recent:
                if g in target and t > latest_for.get(g, -1):
                    latest_for[g] = t
            if set(latest_for.keys()) != target:
                continue
            spread = max(latest_for.values()) - min(latest_for.values())
            if spread <= window:
                self._buffer.remove(target)
                return name
        return None


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
