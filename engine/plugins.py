"""Plugin loader for ~/.gesture/plugins/.

Each *.py file in that directory is imported on engine start. If the module
exports a top-level `handle(gesture_name, event)` callable, it gets invoked
on every recognized gesture (in addition to the normal Swift-side action).

Plugins should be quick — they run on the engine main loop. For long-running
work, spawn a thread inside your handler.

Example plugin (~/.gesture/plugins/log_clap.py):

    def handle(gesture_name, event):
        if gesture_name == "high_five":
            with open("/tmp/claps.log", "a") as f:
                f.write(f"{event['timestamp']}: clap\\n")
"""
import importlib.util
import os
import traceback
from pathlib import Path


DEFAULT_PLUGIN_DIR = Path.home() / ".gesture" / "plugins"


class PluginManager:
    def __init__(self, plugin_dir: Path = DEFAULT_PLUGIN_DIR):
        self.plugin_dir = Path(plugin_dir)
        self.plugins: list = []

    def load(self):
        self.plugins = []
        if not self.plugin_dir.exists():
            return
        for path in sorted(self.plugin_dir.glob("*.py")):
            if path.name.startswith("_"):
                continue
            try:
                spec = importlib.util.spec_from_file_location(path.stem, path)
                if not (spec and spec.loader):
                    continue
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                if callable(getattr(module, "handle", None)):
                    self.plugins.append(module)
                    print(f"Loaded plugin: {path.stem}")
                else:
                    print(f"Skipping {path.name}: no handle(gesture, event) exported")
            except Exception as exc:
                print(f"Failed to load plugin {path.name}: {exc}")
                traceback.print_exc()

    def dispatch(self, gesture_name: str, event: dict):
        for plugin in self.plugins:
            try:
                plugin.handle(gesture_name, event)
            except Exception as exc:
                name = getattr(plugin, "__name__", "<unknown>")
                print(f"Plugin '{name}' raised on '{gesture_name}': {exc}")
