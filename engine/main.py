import argparse
import os
import signal
import sys
import threading
import time
import yaml

from engine.camera import Camera
from engine.detector import HandDetector
from engine.classifier import StaticClassifier, MotionTracker, CooldownManager
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
        for name, gcfg in (self.config.get("gestures") or {}).items():
            if gcfg.get("type") == "static" and gcfg.get("pattern"):
                pattern = gcfg["pattern"]
                if isinstance(pattern, list) and len(pattern) == 5 and all(p in (0, 1) for p in pattern):
                    custom_poses[name] = pattern
                else:
                    print(f"Warning: invalid pattern for gesture '{name}': {pattern}")

        self.static_classifier = StaticClassifier(custom_poses=custom_poses)
        self.motion_tracker = MotionTracker(
            buffer_size=rec_cfg["motion_buffer_frames"],
        )
        self.cooldown = CooldownManager(
            cooldown_ms=rec_cfg["cooldown_ms"],
            confidence_threshold=rec_cfg["confidence_threshold"],
        )
        self.static_confirm_frames = rec_cfg.get("static_confirm_frames", 3)

        self.socket_server = GestureSocketServer()
        self._running = False
        self._static_buffer: list[str] = []

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

                landmarks = self.detector.detect(frame)
                hands_detected = 1 if landmarks else 0

                # Calculate FPS
                frame_count += 1
                elapsed = time.time() - fps_start
                if elapsed >= 1.0:
                    fps = frame_count / elapsed
                    self.socket_server.send_status(hands_detected, fps)
                    frame_count = 0
                    fps_start = time.time()

                if landmarks is None:
                    self._static_buffer.clear()
                    continue

                # Static gesture check (require N-frame stability)
                static_gesture = self.static_classifier.classify(landmarks)
                if static_gesture:
                    self._static_buffer.append(static_gesture)
                    if len(self._static_buffer) >= self.static_confirm_frames:
                        recent = self._static_buffer[-self.static_confirm_frames:]
                        if all(g == static_gesture for g in recent):
                            if self.cooldown.should_fire(static_gesture, 0.95):
                                self.socket_server.send_gesture(static_gesture, 0.95)
                            self._static_buffer.clear()
                else:
                    self._static_buffer.clear()

                # Motion gesture check
                palm = self.detector.get_palm_center(landmarks)
                self.motion_tracker.update(palm)
                motion_gesture = self.motion_tracker.detect()
                if motion_gesture:
                    if self.cooldown.should_fire(motion_gesture, 0.90):
                        self.socket_server.send_gesture(motion_gesture, 0.90)

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


def main():
    parser = argparse.ArgumentParser(description="Gesture Recognition Engine")
    parser.add_argument(
        "--config",
        default=os.path.expanduser("~/.gesture/config.yaml"),
        help="Path to config file",
    )
    args = parser.parse_args()
    engine = GestureEngine(args.config)

    def handle_signal(sig, frame):
        engine.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    engine.start()


if __name__ == "__main__":
    main()
