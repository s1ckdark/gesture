import math
import time
from collections import deque
from typing import Optional

THUMB_TIP, THUMB_IP = 4, 3
INDEX_TIP, INDEX_PIP = 8, 6
MIDDLE_TIP, MIDDLE_PIP = 12, 10
RING_TIP, RING_PIP = 16, 14
PINKY_TIP, PINKY_PIP = 20, 18

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

    def __init__(self, custom_poses: Optional[dict] = None):
        self.poses = dict(STATIC_POSES)
        if custom_poses:
            self.poses.update(custom_poses)

    def _is_finger_extended(self, landmarks, tip_idx: int, pip_idx: int) -> bool:
        return landmarks[tip_idx][1] < landmarks[pip_idx][1]

    def _is_thumb_extended(self, landmarks) -> bool:
        return landmarks[THUMB_TIP][0] > landmarks[THUMB_IP][0]

    def _distance(self, p1, p2) -> float:
        return math.sqrt((p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2)

    def _get_finger_states(self, landmarks) -> list[int]:
        thumb = int(self._is_thumb_extended(landmarks))
        index = int(self._is_finger_extended(landmarks, INDEX_TIP, INDEX_PIP))
        middle = int(self._is_finger_extended(landmarks, MIDDLE_TIP, MIDDLE_PIP))
        ring = int(self._is_finger_extended(landmarks, RING_TIP, RING_PIP))
        pinky = int(self._is_finger_extended(landmarks, PINKY_TIP, PINKY_PIP))
        return [thumb, index, middle, ring, pinky]

    def classify(self, landmarks) -> Optional[str]:
        # Check ok_sign first (thumb+index tips close, middle/ring/pinky extended)
        thumb_index_dist = self._distance(landmarks[THUMB_TIP], landmarks[INDEX_TIP])
        if thumb_index_dist < 0.08:
            states = self._get_finger_states(landmarks)
            if states[2] == 1 and states[3] == 1 and states[4] == 1:
                return "ok_sign"

        states = self._get_finger_states(landmarks)
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
        self._single = StaticClassifier()  # reuse finger-state logic

    def _palm_center(self, landmarks) -> tuple:
        wrist = landmarks[0]
        mcp = landmarks[9]
        return ((wrist[0] + mcp[0]) / 2, (wrist[1] + mcp[1]) / 2)

    def classify(self, hands) -> Optional[str]:
        """`hands` is a list of (landmarks, handedness_label) tuples."""
        if len(hands) != 2 or not self.poses:
            return None
        observed = {}
        centers = {}
        for landmarks, label in hands:
            observed[label] = self._single._get_finger_states(landmarks)
            centers[label] = self._palm_center(landmarks)
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
