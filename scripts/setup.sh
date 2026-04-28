#!/bin/bash
# scripts/setup.sh — One-time project setup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up Gesture app..."

# Python venv
echo "Creating Python virtual environment..."
cd "$PROJECT_DIR/engine"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install --quiet -r requirements.txt

# Default config
CONFIG_DIR="$HOME/.gesture"
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
    echo "Copying default config to $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    cp "$PROJECT_DIR/config/default.yaml" "$CONFIG_DIR/config.yaml"
fi

# Swift dependencies
echo "Resolving Swift packages..."
cd "$PROJECT_DIR/GestureApp"
swift package resolve

echo "Setup complete!"
echo "  Config: $CONFIG_DIR/config.yaml"
echo "  Run engine: scripts/run-engine.sh"
echo "  Build app:  cd GestureApp && swift build"
