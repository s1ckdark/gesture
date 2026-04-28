import os
import urllib.request
from typing import Optional

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import BaseOptions, vision


MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/hand_landmarker/"
    "hand_landmarker/float16/latest/hand_landmarker.task"
)
MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")
MODEL_PATH = os.path.join(MODEL_DIR, "hand_landmarker.task")


def _ensure_model() -> str:
    if not os.path.exists(MODEL_PATH):
        os.makedirs(MODEL_DIR, exist_ok=True)
        print(f"Downloading hand_landmarker model to {MODEL_PATH}...")
        urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
        print("Model download complete.")
    return MODEL_PATH


class HandDetector:
    """Wraps MediaPipe HandLandmarker (Tasks API) for landmark extraction."""

    def __init__(
        self,
        max_hands: int = 1,
        min_detection_confidence: float = 0.7,
        min_tracking_confidence: float = 0.5,
    ):
        model_path = _ensure_model()
        options = vision.HandLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_path),
            num_hands=max_hands,
            min_hand_detection_confidence=min_detection_confidence,
            min_hand_presence_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
            running_mode=vision.RunningMode.VIDEO,
        )
        self._detector = vision.HandLandmarker.create_from_options(options)
        self._timestamp_ms = 0

    def detect(
        self, frame: np.ndarray
    ) -> Optional[list[tuple[float, float, float]]]:
        """Returns list of 21 (x, y, z) landmarks for the first detected hand, or None."""
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame)
        self._timestamp_ms += 33  # ~30 fps spacing; needs monotonically increasing
        result = self._detector.detect_for_video(mp_image, self._timestamp_ms)
        if not result.hand_landmarks:
            return None
        hand = result.hand_landmarks[0]
        return [(lm.x, lm.y, lm.z) for lm in hand]

    def get_palm_center(
        self, landmarks: list[tuple[float, float, float]]
    ) -> tuple[float, float]:
        wrist = landmarks[0]
        mcp = landmarks[9]
        return ((wrist[0] + mcp[0]) / 2, (wrist[1] + mcp[1]) / 2)

    def close(self):
        self._detector.close()
