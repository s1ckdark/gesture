#!/bin/bash
# scripts/run-engine.sh — Run the Python gesture engine standalone
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
source engine/.venv/bin/activate

CONFIG="${1:-$HOME/.gesture/config.yaml}"
python -m engine.main --config "$CONFIG"
