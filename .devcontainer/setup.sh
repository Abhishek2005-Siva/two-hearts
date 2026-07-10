#!/usr/bin/env bash
# Installs Flutter and Tailscale into the Codespace so it can hot-reload
# onto a physical phone over a Tailscale-bridged wireless ADB connection.
# See DEBUGGING.md for the full phone-side steps.
set -euo pipefail

FLUTTER_VERSION="3.41.9"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter $FLUTTER_VERSION..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$HOME/.bashrc"
export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --no-analytics
flutter precache --android
yes | flutter doctor --android-licenses || true

# Tailscale — bridges this cloud container onto the same private network
# as your phone so `adb connect <tailscale-ip>:<port>` can reach it.
if ! command -v tailscale >/dev/null 2>&1; then
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

cd "$(dirname "$0")/.." && flutter pub get

echo ""
echo "Setup done. Next steps:"
echo "  1. sudo tailscaled &"
echo "  2. sudo tailscale up   (opens a login link — approve it)"
echo "  3. Follow DEBUGGING.md to connect your phone."
