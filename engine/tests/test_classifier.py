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
