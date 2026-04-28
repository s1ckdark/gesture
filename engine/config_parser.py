"""Per-gesture-type YAML parsers. Splits the 50-line branching loop that
used to live in `GestureEngine.__init__` into one small function per type
so each can be unit-tested without booting cv2/mediapipe.
"""
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ParsedGestures:
    custom_poses: dict = field(default_factory=dict)         # name -> [5 bits]
    dual_poses: dict = field(default_factory=dict)           # name -> {left, right, proximity?}
    motion_templates: dict = field(default_factory=dict)     # name -> [(x, y), ...]
    dual_motions: dict = field(default_factory=dict)         # name -> {left, right} (swipe directions)
    sequences: dict = field(default_factory=dict)            # name -> {sequence, window_ms}
    chords: dict = field(default_factory=dict)               # name -> {gestures, window_ms}


def _is_5bit(p) -> bool:
    return isinstance(p, list) and len(p) == 5 and all(b in (0, 1) for b in p)


def _parse_static(name, gcfg) -> Optional[list]:
    pattern = gcfg.get("pattern")
    if pattern is None:
        return None
    if _is_5bit(pattern):
        return list(pattern)
    print(f"Warning: invalid pattern for gesture '{name}': {pattern}")
    return None


def _parse_static_dual(name, gcfg) -> Optional[dict]:
    left = gcfg.get("pattern_left")
    right = gcfg.get("pattern_right")
    if not (_is_5bit(left) and _is_5bit(right)):
        print(f"Warning: invalid dual pattern for gesture '{name}'")
        return None
    pose = {"left": list(left), "right": list(right)}
    if "proximity" in gcfg:
        try:
            pose["proximity"] = float(gcfg["proximity"])
        except (TypeError, ValueError):
            print(f"Warning: invalid proximity for '{name}': {gcfg['proximity']}")
    return pose


def _parse_motion_custom(name, gcfg) -> Optional[list]:
    tpl = gcfg.get("motion_template")
    if not (isinstance(tpl, list) and len(tpl) >= 5):
        print(f"Warning: motion_template for '{name}' must have ≥5 points")
        return None
    try:
        return [(float(p[0]), float(p[1])) for p in tpl]
    except (TypeError, ValueError, IndexError):
        print(f"Warning: invalid motion_template for '{name}'")
        return None


_VALID_DIRECTIONS = {"swipe_left", "swipe_right", "swipe_up", "swipe_down"}


def _parse_motion_dual(name, gcfg) -> Optional[dict]:
    left = gcfg.get("motion_left")
    right = gcfg.get("motion_right")
    if left in _VALID_DIRECTIONS and right in _VALID_DIRECTIONS:
        return {"left": left, "right": right}
    print(
        f"Warning: motion_dual '{name}' needs motion_left/motion_right "
        f"as one of {sorted(_VALID_DIRECTIONS)}"
    )
    return None


def _parse_sequence(name, gcfg) -> Optional[dict]:
    seq = gcfg.get("sequence")
    window_ms = gcfg.get("window_ms")
    if isinstance(seq, list) and len(seq) >= 2 and isinstance(window_ms, int):
        return {"sequence": list(seq), "window_ms": window_ms}
    print(f"Warning: sequence '{name}' needs 'sequence: [..]' (≥2) and integer 'window_ms'")
    return None


def _parse_chord(name, gcfg) -> Optional[dict]:
    gestures_list = gcfg.get("sequence") or gcfg.get("gestures")
    window_ms = gcfg.get("window_ms")
    if isinstance(gestures_list, list) and len(gestures_list) >= 2 and isinstance(window_ms, int):
        return {"gestures": list(gestures_list), "window_ms": window_ms}
    print(f"Warning: chord '{name}' needs 'sequence: [..]' (≥2) and integer 'window_ms'")
    return None


_DISPATCH = {
    "static": ("custom_poses", _parse_static),
    "static_dual": ("dual_poses", _parse_static_dual),
    "motion_custom": ("motion_templates", _parse_motion_custom),
    "motion_dual": ("dual_motions", _parse_motion_dual),
    "sequence": ("sequences", _parse_sequence),
    "chord": ("chords", _parse_chord),
}


def parse_gestures(config: dict) -> ParsedGestures:
    out = ParsedGestures()
    for name, gcfg in (config.get("gestures") or {}).items():
        gtype = gcfg.get("type")
        entry = _DISPATCH.get(gtype)
        if entry is None:
            continue  # built-in motion, chain, plugin actions don't need engine-side parsing
        bucket_name, parser = entry
        result = parser(name, gcfg)
        if result is not None:
            getattr(out, bucket_name)[name] = result
    return out
