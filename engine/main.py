import argparse
import os
import signal
import sys
import threading
import time

import cv2
import yaml

from engine.camera import Camera
from engine.detector import HandDetector
from engine.classifier import (
    StaticClassifier,
    MotionTracker,
    CooldownManager,
    DualHandClassifier,
    DualMotionClassifier,
    CustomMotionClassifier,
    SequenceClassifier,
)
from engine.socket_server import GestureSocketServer


class GestureEngine:
    """Main engine loop: camera → detect → classify → send."""

    def __init__(self, config_path: str):
        with open(config_path) as f:
            self.config = yaml.safe_load(f)

        cam_cfg = self.config["camera"]
        rec_cfg = self.config["recognition"]

        self.camera = Camera(
            device=cam_cfg["device"],
            width=cam_cfg["resolution"][0],
            height=cam_cfg["resolution"][1],
        )
        self.detector = HandDetector()

        # Pull any custom static-pose patterns from YAML config.
        custom_poses = {}
        dual_poses = {}
        motion_templates = {}
        dual_motions = {}
        sequences = {}
        for name, gcfg in (self.config.get("gestures") or {}).items():
            gtype = gcfg.get("type")
            if gtype == "sequence":
                seq = gcfg.get("sequence")
                window_ms = gcfg.get("window_ms")
                if isinstance(seq, list) and len(seq) >= 2 and isinstance(window_ms, int):
                    sequences[name] = {"sequence": seq, "window_ms": window_ms}
                else:
                    print(f"Warning: sequence '{name}' needs 'sequence: [..]' (≥2) and integer 'window_ms'")
            elif gtype == "motion_custom":
                tpl = gcfg.get("motion_template")
                if isinstance(tpl, list) and len(tpl) >= 5:
                    try:
                        motion_templates[name] = [(float(p[0]), float(p[1])) for p in tpl]
                    except (TypeError, ValueError, IndexError):
                        print(f"Warning: invalid motion_template for '{name}'")
                else:
                    print(f"Warning: motion_template for '{name}' must have ≥5 points")
            elif gtype == "static" and gcfg.get("pattern"):
                pattern = gcfg["pattern"]
                if isinstance(pattern, list) and len(pattern) == 5 and all(p in (0, 1) for p in pattern):
                    custom_poses[name] = pattern
                else:
                    print(f"Warning: invalid pattern for gesture '{name}': {pattern}")
            elif gtype == "motion_dual":
                left = gcfg.get("motion_left")
                right = gcfg.get("motion_right")
                valid = {"swipe_left", "swipe_right", "swipe_up", "swipe_down"}
                if left in valid and right in valid:
                    dual_motions[name] = {"left": left, "right": right}
                else:
                    print(f"Warning: motion_dual '{name}' needs motion_left/motion_right "
                          f"as one of {sorted(valid)}")
            elif gtype == "static_dual":
                left = gcfg.get("pattern_left")
                right = gcfg.get("pattern_right")
                if (isinstance(left, list) and len(left) == 5 and all(p in (0, 1) for p in left)
                    and isinstance(right, list) and len(right) == 5 and all(p in (0, 1) for p in right)):
                    pose = {"left": left, "right": right}
                    if "proximity" in gcfg:
                        try:
                            pose["proximity"] = float(gcfg["proximity"])
                        except (TypeError, ValueError):
                            print(f"Warning: invalid proximity for '{name}': {gcfg['proximity']}")
                    dual_poses[name] = pose
                else:
                    print(f"Warning: invalid dual pattern for gesture '{name}'")

        self.static_classifier = StaticClassifier(custom_poses=custom_poses)
        self.dual_classifier = DualHandClassifier(dual_poses=dual_poses)
        self.custom_motion = CustomMotionClassifier(templates=motion_templates)
        self.dual_motion = DualMotionClassifier(
            dual_motions=dual_motions,
            buffer_size=rec_cfg["motion_buffer_frames"],
        )
        self.sequence_classifier = SequenceClassifier(sequences=sequences)
        self.motion_tracker = MotionTracker(
            buffer_size=rec_cfg["motion_buffer_frames"],
        )
        self.cooldown = CooldownManager(
            cooldown_ms=rec_cfg["cooldown_ms"],
            confidence_threshold=rec_cfg["confidence_threshold"],
        )
        self.static_confirm_frames = rec_cfg.get("static_confirm_frames", 3)

        self.socket_server = GestureSocketServer()
        self.socket_server.on_command = self._handle_command
        self._running = False
        self._static_buffer: list[str] = []
        self._preview_enabled = False
        self._preview_every_n = 3  # send 1 of every 3 frames (~10 fps)
        self._preview_size = (320, 240)
        self._preview_quality = 60  # JPEG quality 0..100

    def _fire(self, name: str, confidence: float):
        """Cooldown-gated emit + sequence-aware. Sends the leaf gesture, then
        checks if it completes any sequence macro and fires that too."""
        if not self.cooldown.should_fire(name, confidence):
            return
        self.socket_server.send_gesture(name, confidence)
        self.sequence_classifier.record(name)
        matched = self.sequence_classifier.detect()
        if matched and self.cooldown.should_fire(matched, 0.95):
            self.socket_server.send_gesture(matched, 0.95)

    def _handle_command(self, msg: dict):
        if msg.get("type") != "command":
            return
        action = msg.get("action")
        if action == "preview_on":
            self._preview_enabled = True
            print("Preview stream enabled")
        elif action == "preview_off":
            self._preview_enabled = False
            print("Preview stream disabled")

    def start(self):
        self._running = True

        # Start socket server in background thread
        server_thread = threading.Thread(target=self.socket_server.start, daemon=True)
        server_thread.start()

        self.camera.start()
        print("Gesture engine started. Waiting for Swift app connection...")

        frame_count = 0
        fps_start = time.time()

        try:
            while self._running:
                frame = self.camera.read()
                if frame is None:
                    continue

                hands_with_label = self.detector.detect_all(frame)
                hands_detected = len(hands_with_label)
                # Single-hand fallback uses the first detected hand
                landmarks = hands_with_label[0][0] if hands_with_label else None

                # Calculate FPS
                frame_count += 1
                elapsed = time.time() - fps_start
                if elapsed >= 1.0:
                    fps = frame_count / elapsed
                    self.socket_server.send_status(hands_detected, fps)
                    frame_count = 0
                    fps_start = time.time()

                # Preview stream — only when enabled (zero overhead otherwise)
                if self._preview_enabled and frame_count % self._preview_every_n == 0:
                    small = cv2.resize(frame, self._preview_size)
                    bgr = cv2.cvtColor(small, cv2.COLOR_RGB2BGR)
                    ok, jpg = cv2.imencode(
                        ".jpg", bgr,
                        [cv2.IMWRITE_JPEG_QUALITY, self._preview_quality],
                    )
                    if ok:
                        w, h = self._preview_size
                        self.socket_server.send_frame(jpg.tobytes(), w, h)

                    # Also stream the current finger states + palm center for the live HUD / motion recorder
                    if landmarks is not None:
                        states = self.static_classifier._get_finger_states(landmarks)
                        palm_xy = self.detector.get_palm_center(landmarks)
                        self.socket_server.send_finger_states(states, palm=palm_xy)

                if landmarks is None:
                    self._static_buffer.clear()
                    continue

                # Dual-hand check first — only when 2 hands visible.
                if hands_detected == 2:
                    dual_match = self.dual_classifier.classify(hands_with_label)
                    if dual_match:
                        self._fire(dual_match, 0.95)
                        self._static_buffer.clear()
                        continue

                    # Dual MOTION classifier — both hands moving together
                    self.dual_motion.update(hands_with_label)
                    dual_motion_match = self.dual_motion.detect()
                    if dual_motion_match:
                        self._fire(dual_motion_match, 0.90)
                        self._static_buffer.clear()
                        continue

                # Static gesture check (require N-frame stability)
                static_gesture = self.static_classifier.classify(landmarks)
                if static_gesture:
                    self._static_buffer.append(static_gesture)
                    if len(self._static_buffer) >= self.static_confirm_frames:
                        recent = self._static_buffer[-self.static_confirm_frames:]
                        if all(g == static_gesture for g in recent):
                            self._fire(static_gesture, 0.95)
                            self._static_buffer.clear()
                else:
                    self._static_buffer.clear()

                # Motion gesture check (built-in swipes)
                palm = self.detector.get_palm_center(landmarks)
                self.motion_tracker.update(palm)
                motion_gesture = self.motion_tracker.detect()
                if motion_gesture:
                    self._fire(motion_gesture, 0.90)

                # Custom motion check (DTW against user templates)
                self.custom_motion.update(palm)
                custom_motion = self.custom_motion.detect()
                if custom_motion:
                    self._fire(custom_motion, 0.85)

        except KeyboardInterrupt:
            pass
        finally:
            self.stop()

    def stop(self):
        self._running = False
        self.camera.stop()
        self.detector.close()
        self.socket_server.stop()
        print("Gesture engine stopped.")


def record_motion(name: str, duration: float, config_path: str):
    """Record a 2D palm-center trajectory for `duration` seconds and print a
    YAML snippet the user can paste under `gestures:` in their config."""
    print(f"Recording '{name}' for {duration:.1f}s. Make your motion now…")
    time.sleep(0.8)
    print("Recording in 3…", end="", flush=True); time.sleep(1)
    print(" 2…", end="", flush=True); time.sleep(1)
    print(" 1… GO", flush=True)

    with open(config_path) as f:
        cfg = yaml.safe_load(f) or {}
    cam_cfg = cfg.get("camera", {"device": 0, "resolution": [640, 480]})
    cam = Camera(device=cam_cfg["device"], width=cam_cfg["resolution"][0],
                 height=cam_cfg["resolution"][1])
    det = HandDetector()
    cam.start()

    points: list = []
    start = time.time()
    while time.time() - start < duration:
        frame = cam.read()
        if frame is None:
            continue
        landmarks = det.detect(frame)
        if landmarks:
            points.append(det.get_palm_center(landmarks))

    cam.stop()
    det.close()

    if len(points) < 5:
        print(f"\nERROR: only {len(points)} hand frames captured. Try again with better lighting / hand position.")
        return

    print(f"\nCaptured {len(points)} points. YAML snippet to paste under 'gestures:' in your config:\n")
    print(f"  {name}:")
    print("    type: motion_custom")
    print("    motion_template:")
    for x, y in points:
        print(f"      - [{x:.4f}, {y:.4f}]")
    print("    action:")
    print("      type: hotkey")
    print('      keys: ["cmd", "shift", "r"]')


def main():
    parser = argparse.ArgumentParser(description="Gesture Recognition Engine")
    parser.add_argument(
        "--config",
        default=os.path.expanduser("~/.gesture/config.yaml"),
        help="Path to config file",
    )
    parser.add_argument(
        "--record-motion", metavar="NAME",
        help="Record a custom motion template for NAME and print a YAML snippet.",
    )
    parser.add_argument(
        "--record-duration", type=float, default=3.0,
        help="Seconds to record when --record-motion is set (default: 3.0)",
    )
    args = parser.parse_args()

    if args.record_motion:
        record_motion(args.record_motion, args.record_duration, args.config)
        return

    engine = GestureEngine(args.config)

    def handle_signal(sig, frame):
        engine.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    engine.start()


if __name__ == "__main__":
    main()
