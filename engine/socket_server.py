import base64
import json
import os
import socket
import time
from typing import Callable, Optional


class GestureSocketServer:
    """Unix Domain Socket server for sending gesture events to Swift app."""

    def __init__(self, socket_path: str = "/tmp/gesture.sock"):
        self.socket_path = socket_path
        self._server: Optional[socket.socket] = None
        self._client: Optional[socket.socket] = None
        self._running = False
        self.on_command: Optional[Callable[[dict], None]] = None

    def start(self):
        # Clean up stale socket
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)

        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(self.socket_path)
        self._server.listen(1)
        self._server.settimeout(1.0)
        self._running = True

        while self._running:
            try:
                self._client, _ = self._server.accept()
                self._handle_client()
            except socket.timeout:
                continue
            except OSError:
                break

    def _handle_client(self):
        """Keep connection alive until client disconnects or server stops.
        Parses inbound newline-delimited JSON and dispatches to on_command."""
        buf = b""
        while self._running and self._client:
            try:
                self._client.settimeout(0.1)
                try:
                    data = self._client.recv(4096)
                    if not data:
                        break  # client disconnected
                    buf += data
                    while b"\n" in buf:
                        line, _, buf = buf.partition(b"\n")
                        if not line:
                            continue
                        try:
                            msg = json.loads(line.decode())
                            if self.on_command:
                                self.on_command(msg)
                        except (json.JSONDecodeError, UnicodeDecodeError):
                            pass
                except socket.timeout:
                    pass
            except OSError:
                break
        self._client = None

    def send_gesture(self, name: str, confidence: float):
        self._send({
            "type": "gesture",
            "name": name,
            "confidence": confidence,
            "timestamp": time.time(),
        })

    def send_status(self, hands_detected: int, fps: float):
        self._send({
            "type": "status",
            "hands_detected": hands_detected,
            "fps": fps,
        })

    def send_frame(self, jpeg_bytes: bytes, width: int, height: int):
        self._send({
            "type": "frame",
            "data": base64.b64encode(jpeg_bytes).decode("ascii"),
            "width": width,
            "height": height,
        })

    def _send(self, msg: dict):
        if self._client is None:
            return
        try:
            data = json.dumps(msg) + "\n"
            self._client.sendall(data.encode())
        except (BrokenPipeError, OSError):
            self._client = None

    def stop(self):
        self._running = False
        if self._client:
            try:
                self._client.close()
            except OSError:
                pass
            self._client = None
        if self._server:
            try:
                self._server.close()
            except OSError:
                pass
            self._server = None
        if os.path.exists(self.socket_path):
            os.unlink(self.socket_path)
