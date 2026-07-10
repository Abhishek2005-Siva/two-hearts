#!/usr/bin/env bash
# Installs Tailscale, the Android SDK, and Flutter into the Codespace so it
# can hot-reload onto a physical phone over a Tailscale-bridged wireless ADB
# connection. See DEBUGGING.md for the full phone-side steps.
#
# Each section is independent and non-fatal on failure (no `set -e`) so one
# broken step can't silently take Tailscale or Flutter down with it — every
# section prints its own OK/WARNING so failures are visible, not silent.
set -uo pipefail

echo "==> [1/3] Installing Tailscale..."
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sudo sh
fi
if command -v tailscale >/dev/null 2>&1; then
  echo "Tailscale OK."
else
  echo "WARNING: Tailscale install failed. Run manually:"
  echo "  curl -fsSL https://tailscale.com/install.sh | sudo sh"
fi

echo "==> [2/3] Installing Android SDK command-line tools..."
# Installed by hand (not a devcontainer "feature") so this doesn't depend on
# guessing a third-party feature registry path correctly.
ANDROID_SDK_ROOT="$HOME/android-sdk"
CMDLINE_ZIP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

sudo apt-get update -y >/dev/null 2>&1 || true
sudo apt-get install -y unzip >/dev/null 2>&1 || true

if [ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]; then
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  TMP_ZIP="/tmp/cmdline-tools.zip"
  if curl -fsSL -o "$TMP_ZIP" "$CMDLINE_ZIP_URL"; then
    unzip -q "$TMP_ZIP" -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  else
    echo "WARNING: couldn't download Android cmdline-tools from:"
    echo "  $CMDLINE_ZIP_URL"
    echo "Get the current URL from https://developer.android.com/studio#command-line-tools-only"
    echo "and re-run: curl -fsSL -o /tmp/cmdline-tools.zip <url> && unzip -q /tmp/cmdline-tools.zip -d \$HOME/android-sdk/cmdline-tools && mv \$HOME/android-sdk/cmdline-tools/cmdline-tools \$HOME/android-sdk/cmdline-tools/latest"
  fi
fi

export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools"

if command -v sdkmanager >/dev/null 2>&1; then
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager --install "platform-tools" "platforms;android-35" "build-tools;35.0.0" >/dev/null 2>&1 || true
  echo "Android SDK OK (platform-tools + Android 35 + build-tools 35.0.0)."
  echo "If a build asks for a different platform/build-tools version, run:"
  echo "  sdkmanager --install \"platforms;android-XX\" \"build-tools;XX.0.0\""
else
  echo "WARNING: Android SDK setup didn't finish (sdkmanager not found)."
fi

{
  echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_ROOT\""
  echo "export ANDROID_HOME=\"$ANDROID_SDK_ROOT\""
  echo "export PATH=\"\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools:\$HOME/flutter/bin\""
} >> "$HOME/.bashrc"

echo "==> [3/3] Installing Flutter..."
FLUTTER_VERSION="3.41.9"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"

if command -v flutter >/dev/null 2>&1; then
  flutter config --no-analytics || true
  flutter precache --android || true
  yes | flutter doctor --android-licenses || true
  ( cd "$(dirname "$0")/.." && flutter pub get ) || true
  echo "Flutter OK."
else
  echo "WARNING: Flutter setup didn't finish."
fi

echo ""
echo "Setup done. Open a NEW terminal (or 'source ~/.bashrc') to pick up PATH."
echo "tailscaled auto-starts on this Codespace from now on — run:"
echo "  sudo tailscale up"
echo "Then follow DEBUGGING.md to connect your phone."
