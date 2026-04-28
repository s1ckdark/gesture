import math
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
    """Classifies static hand poses based on finger extension states."""

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
        for pose_name, pose_states in STATIC_POSES.items():
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
