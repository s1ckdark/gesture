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
