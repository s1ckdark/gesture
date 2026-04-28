import time

import pytest
from engine.classifier import (
    StaticClassifier,
    MotionTracker,
    CooldownManager,
    DualHandClassifier,
    DualMotionClassifier,
    CustomMotionClassifier,
    SequenceClassifier,
    ChordClassifier,
    dtw_distance,
)

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

    def test_custom_pose_rock(self):
        """User-defined pose injected via custom_poses overrides + extends defaults."""
        classifier = StaticClassifier(custom_poses={"rock": [0, 1, 0, 0, 1]})
        landmarks = _make_landmarks([0, 1, 0, 0, 1])
        assert classifier.classify(landmarks) == "rock"

    def test_custom_pose_does_not_break_defaults(self):
        classifier = StaticClassifier(custom_poses={"rock": [0, 1, 0, 0, 1]})
        landmarks = _make_landmarks([1, 0, 0, 0, 0])
        assert classifier.classify(landmarks) == "thumbs_up"

    def test_ok_sign_with_tighter_threshold(self):
        """A custom (tighter) ok_sign_distance rejects medium-spaced thumb+index."""
        loose = StaticClassifier(ok_sign_distance=0.10)
        tight = StaticClassifier(ok_sign_distance=0.03)
        landmarks = _make_landmarks([1, 1, 1, 1, 1])
        landmarks[4] = (0.5, 0.4, 0.0)
        landmarks[8] = (0.55, 0.45, 0.0)  # distance ≈ 0.071
        assert loose.classify(landmarks) == "ok_sign"
        assert tight.classify(landmarks) != "ok_sign"


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


class TestDualHandClassifier:
    def test_match_both_hands(self):
        clf = DualHandClassifier({
            "high_five": {"left": [1, 1, 1, 1, 1], "right": [1, 1, 1, 1, 1]},
        })
        hands = [
            (_make_landmarks([1, 1, 1, 1, 1]), "Left"),
            (_make_landmarks([1, 1, 1, 1, 1]), "Right"),
        ]
        assert clf.classify(hands) == "high_five"

    def test_no_match_when_one_hand_wrong(self):
        clf = DualHandClassifier({
            "double_peace": {"left": [0, 1, 1, 0, 0], "right": [0, 1, 1, 0, 0]},
        })
        hands = [
            (_make_landmarks([0, 1, 1, 0, 0]), "Left"),
            (_make_landmarks([1, 1, 1, 1, 1]), "Right"),  # right is open palm, not peace
        ]
        assert clf.classify(hands) is None

    def test_returns_none_with_one_hand(self):
        clf = DualHandClassifier({
            "high_five": {"left": [1, 1, 1, 1, 1], "right": [1, 1, 1, 1, 1]},
        })
        hands = [(_make_landmarks([1, 1, 1, 1, 1]), "Left")]
        assert clf.classify(hands) is None

    def test_returns_none_with_no_poses(self):
        clf = DualHandClassifier()
        hands = [
            (_make_landmarks([1, 1, 1, 1, 1]), "Left"),
            (_make_landmarks([1, 1, 1, 1, 1]), "Right"),
        ]
        assert clf.classify(hands) is None

    def _make_with_palm(self, finger_states, palm_xy):
        """Helper: landmarks with finger pattern AND specific palm center."""
        landmarks = _make_landmarks(finger_states)
        # palm_center = avg(wrist[0], mcp[9])
        landmarks[0] = (palm_xy[0], palm_xy[1], 0.0)
        landmarks[9] = (palm_xy[0], palm_xy[1], 0.0)
        return landmarks

    def test_proximity_match_when_close(self):
        clf = DualHandClassifier({
            "heart": {"left": [1, 1, 0, 0, 0], "right": [1, 1, 0, 0, 0], "proximity": 0.2},
        })
        hands = [
            (self._make_with_palm([1, 1, 0, 0, 0], (0.4, 0.5)), "Left"),
            (self._make_with_palm([1, 1, 0, 0, 0], (0.5, 0.5)), "Right"),  # dist=0.1
        ]
        assert clf.classify(hands) == "heart"

    def test_proximity_no_match_when_far(self):
        clf = DualHandClassifier({
            "heart": {"left": [1, 1, 0, 0, 0], "right": [1, 1, 0, 0, 0], "proximity": 0.2},
        })
        hands = [
            (self._make_with_palm([1, 1, 0, 0, 0], (0.1, 0.5)), "Left"),
            (self._make_with_palm([1, 1, 0, 0, 0], (0.9, 0.5)), "Right"),  # dist=0.8
        ]
        assert clf.classify(hands) is None


class TestDTW:
    def test_identical_sequences_zero_distance(self):
        seq = [(0.1, 0.1), (0.2, 0.2), (0.3, 0.3)]
        assert dtw_distance(seq, seq) == 0.0

    def test_distance_increases_with_difference(self):
        a = [(0.0, 0.0), (0.1, 0.0), (0.2, 0.0)]
        b = [(0.0, 0.0), (0.1, 0.5), (0.2, 1.0)]  # diverges in y
        assert dtw_distance(a, b) > 0.0

    def test_empty_sequence_returns_inf(self):
        assert dtw_distance([], [(0.1, 0.1)]) == float("inf")
        assert dtw_distance([(0.1, 0.1)], []) == float("inf")


class TestCustomMotionClassifier:
    def test_match_similar_trajectory(self):
        # Template: smooth rightward arc
        template = [(i / 30, 0.5 - 0.05 * (i / 30)) for i in range(30)]
        clf = CustomMotionClassifier({"arc": template}, threshold=0.05, buffer_size=30)
        # Feed nearly-identical points
        for p in template:
            clf.update(p)
        assert clf.detect() == "arc"

    def test_no_match_for_dissimilar_trajectory(self):
        template = [(i / 30, 0.5) for i in range(30)]  # straight line
        clf = CustomMotionClassifier({"line": template}, threshold=0.02, buffer_size=30)
        # Feed a vertical zigzag instead
        for i in range(30):
            clf.update((0.5, 0.1 + 0.5 * (i % 2)))
        assert clf.detect() is None

    def test_buffer_clears_after_match(self):
        template = [(i / 30, 0.5) for i in range(30)]
        clf = CustomMotionClassifier({"line": template}, threshold=0.05, buffer_size=30)
        for p in template:
            clf.update(p)
        assert clf.detect() == "line"
        # Buffer should be empty now
        assert clf.detect() is None

    def test_returns_none_with_no_templates(self):
        clf = CustomMotionClassifier(buffer_size=5)
        for i in range(5):
            clf.update((0.1 * i, 0.5))
        assert clf.detect() is None


class TestDualMotionClassifier:
    """Helper to build hand tuples with a specific palm center via wrist (idx 0) and mcp (idx 9)."""
    def _hand(self, palm_xy, label):
        landmarks = [(palm_xy[0], palm_xy[1], 0.0)] * 21
        return (landmarks, label)

    def _feed_swipe(self, clf, label, x_start, x_end, n=10):
        # Linear horizontal sweep from x_start to x_end at y=0.5
        for i in range(n):
            t = i / (n - 1)
            x = x_start + (x_end - x_start) * t
            clf.update([self._hand((x, 0.5), label)])

    def test_match_both_swipe_left(self):
        clf = DualMotionClassifier(
            {"shrink": {"left": "swipe_left", "right": "swipe_left"}},
            buffer_size=10, threshold=0.15,
        )
        self._feed_swipe(clf, "Left", 0.8, 0.2)
        self._feed_swipe(clf, "Right", 0.8, 0.2)
        assert clf.detect() == "shrink"

    def test_match_spread(self):
        # Spread = each hand swipes outward from center (Left ←, Right →)
        clf = DualMotionClassifier(
            {"spread": {"left": "swipe_left", "right": "swipe_right"}},
            buffer_size=10, threshold=0.15,
        )
        self._feed_swipe(clf, "Left", 0.5, 0.1)   # left hand swipes left
        self._feed_swipe(clf, "Right", 0.5, 0.9)  # right hand swipes right
        assert clf.detect() == "spread"

    def test_no_match_when_directions_differ(self):
        clf = DualMotionClassifier(
            {"shrink": {"left": "swipe_left", "right": "swipe_left"}},
            buffer_size=10, threshold=0.15,
        )
        self._feed_swipe(clf, "Left", 0.8, 0.2)   # left swipes left ✓
        self._feed_swipe(clf, "Right", 0.2, 0.8)  # right swipes right ✗
        assert clf.detect() is None

    def test_returns_none_with_no_templates(self):
        clf = DualMotionClassifier({}, buffer_size=10, threshold=0.15)
        self._feed_swipe(clf, "Left", 0.8, 0.2)
        self._feed_swipe(clf, "Right", 0.8, 0.2)
        assert clf.detect() is None


class TestSequenceClassifier:
    def test_match_in_order_within_window(self):
        clf = SequenceClassifier({
            "combo": {"sequence": ["thumbs_up", "peace", "fist"], "window_ms": 3000},
        })
        clf.record("thumbs_up")
        clf.record("peace")
        clf.record("fist")
        assert clf.detect() == "combo"

    def test_no_match_wrong_order(self):
        clf = SequenceClassifier({
            "combo": {"sequence": ["thumbs_up", "peace"], "window_ms": 3000},
        })
        clf.record("peace")
        clf.record("thumbs_up")
        assert clf.detect() is None

    def test_no_match_outside_window(self):
        clf = SequenceClassifier({
            "combo": {"sequence": ["thumbs_up", "peace"], "window_ms": 100},
        })
        clf.record("thumbs_up")
        time.sleep(0.15)  # > window
        clf.record("peace")
        assert clf.detect() is None

    def test_clears_after_match(self):
        clf = SequenceClassifier({
            "combo": {"sequence": ["a", "b"], "window_ms": 3000},
        })
        clf.record("a")
        clf.record("b")
        assert clf.detect() == "combo"
        # Record again — buffer was cleared, single record can't match
        clf.record("b")
        assert clf.detect() is None

    def test_returns_none_with_no_sequences(self):
        clf = SequenceClassifier()
        clf.record("anything")
        assert clf.detect() is None


class TestChordClassifier:
    def test_match_in_either_order(self):
        clf = ChordClassifier({
            "combo": {"gestures": ["a", "b"], "window_ms": 1000},
        })
        clf.record("b")
        clf.record("a")  # reverse order, still matches
        assert clf.detect() == "combo"

    def test_no_match_missing_one(self):
        clf = ChordClassifier({
            "combo": {"gestures": ["a", "b", "c"], "window_ms": 1000},
        })
        clf.record("a"); clf.record("b")
        assert clf.detect() is None

    def test_no_match_outside_window(self):
        clf = ChordClassifier({
            "combo": {"gestures": ["a", "b"], "window_ms": 100},
        })
        clf.record("a")
        time.sleep(0.15)
        clf.record("b")
        assert clf.detect() is None

    def test_clears_after_match(self):
        clf = ChordClassifier({
            "combo": {"gestures": ["a", "b"], "window_ms": 1000},
        })
        clf.record("a"); clf.record("b")
        assert clf.detect() == "combo"
        clf.record("a")  # alone, can't match
        assert clf.detect() is None
