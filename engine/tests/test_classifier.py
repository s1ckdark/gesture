import time

import pytest
from engine.classifier import StaticClassifier, MotionTracker, CooldownManager

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

    def test_ok_sign(self):
        """OK sign: thumb tip and index tip close together, other fingers extended."""
        landmarks = _make_landmarks([1, 1, 1, 1, 1])  # base: all extended
        # Move thumb tip and index tip close together
        landmarks[4] = (0.5, 0.4, 0.0)    # thumb tip
        landmarks[8] = (0.52, 0.42, 0.0)  # index tip — very close to thumb
        result = self.classifier.classify(landmarks)
        assert result == "ok_sign"


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
