# Debugging on your phone from a cloud Codespace

This lets you hot-reload straight onto your real Android phone using
GitHub Codespaces as the "brain" — no laptop needed. It works because
Tailscale puts your phone and the cloud container on the same private
network, so `adb` can reach the phone over the internet.

## One-time setup

### 1. Install Tailscale on your phone
- Get **Tailscale** from the Play Store.
- Open it, sign in (Google account is easiest), and toggle it **on**.
- Leave it running in the background.

### 2. Open a Codespace on this repo
- On GitHub, go to the repo → green **Code** button → **Codespaces** tab →
  **Create codespace on main**.
- Wait for it to build — `.devcontainer/setup.sh` installs Flutter and
  Tailscale automatically. First build takes a few minutes; later ones
  are fast (cached).

### 3. Connect the Codespace to your Tailscale network
`tailscaled` auto-starts in the background for every Codespace on this
repo, so you only need to log in:
```bash
sudo tailscale up
```
This prints a link — open it (on your phone or any browser) and sign in
with the **same account** you used for Tailscale on your phone.

If `tailscale`/`tailscaled` aren't found at all, the install step didn't
finish — run this once and retry:
```bash
curl -fsSL https://tailscale.com/install.sh | sudo sh
```

Once connected, confirm you can see your phone:
```bash
tailscale status
```
You should see your phone listed with a `100.x.x.x` address. That's the
IP you'll use below.

## Every time you want to debug on your phone

### 4. Enable wireless debugging on your phone
- Settings → **Developer options** → **Wireless debugging** → turn it on.
- Tap **Wireless debugging** itself (not just the toggle) to see the
  **IP address & port** (e.g. `192.168.1.42:41235`) — you won't use this
  IP directly, but this screen also has **Pair device with pairing code**,
  which you need the first time.

### 5. Pair once (first time only per Codespace)
On the wireless debugging screen, tap **Pair device with pairing code**.
It shows a 6-digit code and a *pairing* IP:port (different from the debug
port above). In the Codespace terminal:
```bash
adb pair <phone-tailscale-ip>:<pairing-port>
```
Enter the 6-digit code when prompted. Use the **Tailscale IP** from
`tailscale status`, not the LAN IP shown on the phone.

### 6. Connect and run
```bash
adb connect <phone-tailscale-ip>:<debug-port>
flutter devices          # your phone should show up
cd two_hearts
flutter run -d <device-id>
```
Once it's running, press `r` in the terminal for hot reload, `R` for hot
restart — same as running locally, but pushed straight to your phone.

## Notes
- Wireless debugging can drop if your phone sleeps deeply or reboots —
  just re-run `adb connect <ip>:<port>` (no need to re-pair unless it was
  a full reboot that cleared it).
- The Tailscale IP for your phone stays stable across sessions, so you
  can save the `adb connect` command for next time.
- All native features (camera, screen share, Spotify OAuth, WebRTC calls)
  work exactly as they would from a local `flutter run`, since this is a
  real device, not an emulator.
- Two-person features (calls, screen share, sync) still need a **second**
  real device/account on the other end — this setup gets you one live
  phone with hot reload, not both sides at once.
