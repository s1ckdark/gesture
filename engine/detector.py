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
