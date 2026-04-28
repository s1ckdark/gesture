"""Pure-function helpers over MediaPipe Hand landmarks.

Lifted out of `classifier.py` so multiple consumers (StaticClassifier,
DualHandClassifier, DualMotionClassifier, HandDetector, the engine's
preview HUD path) can share one implementation instead of inlining the
same math in five places.
"""

# MediaPipe HandLandmarker landmark indices
WRIST = 0
THUMB_TIP, THUMB_IP = 4, 3
INDEX_TIP, INDEX_PIP = 8, 6
MIDDLE_TIP, MIDDLE_PIP = 12, 10
MIDDLE_MCP = 9
RING_TIP, RING_PIP = 16, 14
PINKY_TIP, PINKY_PIP = 20, 18


def palm_center(landmarks) -> tuple[float, float]:
    """Returns the (x, y) average of wrist and middle-finger MCP."""
    w = landmarks[WRIST]
    m = landmarks[MIDDLE_MCP]
    return ((w[0] + m[0]) / 2, (w[1] + m[1]) / 2)


def _is_finger_extended(landmarks, tip_idx: int, pip_idx: int) -> bool:
    return landmarks[tip_idx][1] < landmarks[pip_idx][1]


def _is_thumb_extended(landmarks) -> bool:
    return landmarks[THUMB_TIP][0] > landmarks[THUMB_IP][0]


def finger_states(landmarks) -> list[int]:
    """Returns [thumb, index, middle, ring, pinky] as 0/1 ints."""
    thumb = int(_is_thumb_extended(landmarks))
    index = int(_is_finger_extended(landmarks, INDEX_TIP, INDEX_PIP))
    middle = int(_is_finger_extended(landmarks, MIDDLE_TIP, MIDDLE_PIP))
    ring = int(_is_finger_extended(landmarks, RING_TIP, RING_PIP))
    pinky = int(_is_finger_extended(landmarks, PINKY_TIP, PINKY_PIP))
    return [thumb, index, middle, ring, pinky]
