#!/usr/bin/env bash
# postStartCommand — runs every time the Codespace (re)starts. Brings up
# tailscaled in the background and starts the adb server, both idempotent
# (safe to run again if already running).
#
# Tailscale normally needs a TUN device + NET_ADMIN (granted via runArgs in
# devcontainer.json). If the platform ignores that, we fall back to
# "userspace networking" mode, which needs neither — at the cost of raw IP
# routing; ADB then has to go through Tailscale's local SOCKS5 proxy
# instead of a plain `adb connect <ip>:<port>` (see DEBUGGING.md).
set -u

sudo mkdir -p /var/lib/tailscale
STATE="--state=/var/lib/tailscale/tailscaled.state"

start_normal() {
  sudo nohup tailscaled $STATE > /tmp/tailscaled.log 2>&1 &
  disown
}

start_userspace() {
  sudo nohup tailscaled $STATE --tun=userspace-networking \
    --socks5-server=localhost:1055 > /tmp/tailscaled.log 2>&1 &
  disown
}

if ! pgrep -x tailscaled >/dev/null 2>&1; then
  start_normal
  sleep 1
  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    echo "Normal mode failed (likely no TUN device) — trying userspace networking..."
    start_userspace
    sleep 1
  fi
fi

if pgrep -x tailscaled >/dev/null 2>&1; then
  if grep -q "userspace-networking" /tmp/tailscaled.log 2>/dev/null; then
    echo "tailscaled running in USERSPACE mode (no raw TUN device available)."
    echo "Log in with: sudo tailscale up"
    echo "ADB needs the SOCKS5 proxy at localhost:1055 — see DEBUGGING.md."
  else
    echo "tailscaled running normally. Log in with: sudo tailscale up"
  fi
else
  echo "WARNING: tailscaled still not running — check /tmp/tailscaled.log"
  cat /tmp/tailscaled.log 2>/dev/null || true
fi

adb start-server >/dev/null 2>&1 || true
