import json
import os
import socket
import threading
import time
import pytest
from engine.socket_server import GestureSocketServer


SOCKET_PATH = "/tmp/gesture_test.sock"


@pytest.fixture
def server():
    srv = GestureSocketServer(SOCKET_PATH)
    thread = threading.Thread(target=srv.start, daemon=True)
    thread.start()
    time.sleep(0.1)  # let server bind
    yield srv
    srv.stop()
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)


@pytest.fixture
def client(server):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)
    yield sock
    sock.close()


class TestSocketServer:
    def test_server_creates_socket_file(self, server):
        assert os.path.exists(SOCKET_PATH)

    def test_client_can_connect(self, client):
        assert client.fileno() > 0

    def test_send_gesture_event(self, server, client):
        time.sleep(0.05)  # let server accept the connection
        server.send_gesture("thumbs_up", 0.95)
        time.sleep(0.05)
        data = client.recv(4096).decode()
        msg = json.loads(data.strip())
        assert msg["type"] == "gesture"
        assert msg["name"] == "thumbs_up"
        assert msg["confidence"] == 0.95

    def test_send_status(self, server, client):
        time.sleep(0.05)
        server.send_status(hands_detected=1, fps=30.0)
        time.sleep(0.05)
        data = client.recv(4096).decode()
        msg = json.loads(data.strip())
        assert msg["type"] == "status"
        assert msg["hands_detected"] == 1

    def test_cleanup_stale_socket(self, server):
        """If socket file exists from a previous run, server should clean it up."""
        server.stop()
        # Create stale socket file
        with open(SOCKET_PATH, "w") as f:
            f.write("")
        srv2 = GestureSocketServer(SOCKET_PATH)
        thread = threading.Thread(target=srv2.start, daemon=True)
        thread.start()
        time.sleep(0.1)
        assert os.path.exists(SOCKET_PATH)
        srv2.stop()
