import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/presence/activity_announcer.dart';
import '../../core/theme/app_theme.dart';
import 'spotify_remote_service.dart';

const _spotifyGreen = Color(0xFF1DB954);

/// A local remote for whatever's playing in the Spotify app on THIS phone —
/// play/pause, skip, and now-playing info, via Android's system
/// MediaSession framework (see spotify_remote_service.dart). Replaced the
/// old Spotify Web API/OAuth-based "Listen Together" (search, playlists,
/// cross-device sync) — that capability genuinely required the real API,
/// so this screen can no longer do any of that; it only ever controls
/// your own phone's Spotify. iOS has no equivalent public API for reading
/// another app's now-playing session, so this is Android-only.
class SpotifyRemoteScreen extends ConsumerStatefulWidget {
  const SpotifyRemoteScreen({super.key});

  @override
  ConsumerState<SpotifyRemoteScreen> createState() =>
      _SpotifyRemoteScreenState();
}

enum _AccessState { checking, notSupported, denied, granted }

class _SpotifyRemoteScreenState extends ConsumerState<SpotifyRemoteScreen>
    with ActivityAnnouncer, WidgetsBindingObserver {
  final _remote = SpotifyRemoteService.instance;
  _AccessState _access = _AccessState.checking;
  SpotifyNowPlaying? _state;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    announceActivity('Controlling Spotify');
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  // The two-step access flow (app info → notification access) bounces the
  // person out to system Settings and back at least once, sometimes twice.
  // Neither of those settings screens hands back a result this app can
  // await directly, so re-checking on every resume is the only way to
  // notice they've come back — including still on the "denied" pane after
  // only finishing step 1.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!Platform.isAndroid) {
      setState(() => _access = _AccessState.notSupported);
      return;
    }
    final granted = await _remote.isAccessGranted();
    if (!mounted) return;
    setState(() => _access = granted ? _AccessState.granted : _AccessState.denied);
    if (granted) _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final s = await _remote.getState();
      if (mounted) setState(() => _state = s);
    } catch (_) {}
  }

  Future<void> _grantAccess() => _remote.openAccessSettings();

  Future<void> _act(Future<void> Function() action) async {
    HapticFeedback.selectionClick();
    try {
      await action();
    } catch (_) {}
    // Transport actions don't report their own result — nudge state a
    // moment later rather than waiting a full poll cycle.
    Future.delayed(const Duration(milliseconds: 300), _refresh);
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          const Icon(Icons.headphones_rounded, color: _spotifyGreen, size: 22),
          const SizedBox(width: 8),
          const Text('Spotify Remote',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_access) {
      case _AccessState.checking:
        return const Center(
            child: CircularProgressIndicator(color: _spotifyGreen));
      case _AccessState.notSupported:
        return const _NoticePane(
          emoji: '📱',
          title: 'Android only',
          body: 'iOS has no public API for another app to control or read '
              "another app's now-playing session, so this feature only "
              'works on Android.',
        );
      case _AccessState.denied:
        return _accessPane();
      case _AccessState.granted:
        return _nowPlayingPane();
    }
  }

  Widget _accessPane() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎧', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Control Spotify from here',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 10),
          const Text(
            'This needs "Notification access" — the same Android '
            'permission Bluetooth and car controls use to play/pause '
            "Spotify. No Spotify account, sign-in, or developer setup "
            "needed. Two Hearts never reads your notification content.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Because Two Hearts wasn\'t installed from the Play Store, '
            'Android splits turning this on into two manual steps — '
            'neither can be skipped or done automatically, by this app or '
            'any other, on purpose.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          _AccessStep(
            number: '1',
            title: 'Allow restricted settings',
            body: 'Tap below, then tap the ⋮ (three dots, top right) → '
                '"Allow restricted settings" → Allow.',
            buttonLabel: 'Open App Settings',
            onTap: () => _remote.openAppInfoSettings(),
          ),
          const SizedBox(height: 14),
          _AccessStep(
            number: '2',
            title: 'Turn on notification access',
            body: 'Find "Two Hearts" in the list below and turn it on.',
            buttonLabel: 'Open Notification Access',
            onTap: _grantAccess,
          ),
        ],
      ),
    );
  }

  Widget _nowPlayingPane() {
    final s = _state;
    if (s == null || s.title == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎵', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 18),
              const Text('Nothing playing on Spotify right now',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 22),
              SquishyTap(
                onTap: () => _remote.openSpotify(),
                style: TapAnimationStyle.bounce,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    color: _spotifyGreen,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Text('Open Spotify',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasArt = s.artUri != null &&
        (s.artUri!.startsWith('http://') || s.artUri!.startsWith('https://'));
    final progress =
        s.durationMs > 0 ? (s.positionMs / s.durationMs).clamp(0.0, 1.0) : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: hasArt
                  ? CachedNetworkImage(
                      imageUrl: s.artUri!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _artPlaceholder(),
                    )
                  : _artPlaceholder(),
            ),
            const SizedBox(height: 24),
            Text(s.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(s.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),
            // Non-interactive — MediaSession seek support isn't guaranteed
            // consistent across apps, so this only ever reflects position,
            // it doesn't accept a scrub/drag.
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(_spotifyGreen),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(s.positionMs),
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
                Text(_fmt(s.durationMs),
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _transportButton(
                  icon: Icons.skip_previous_rounded,
                  size: 30,
                  onTap: () => _act(_remote.skipPrevious),
                ),
                const SizedBox(width: 20),
                _transportButton(
                  icon: s.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  size: 64,
                  color: _spotifyGreen,
                  onTap: () => _act(_remote.playPause),
                ),
                const SizedBox(width: 20),
                _transportButton(
                  icon: Icons.skip_next_rounded,
                  size: 30,
                  onTap: () => _act(_remote.skipNext),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder() => Container(
        width: 220,
        height: 220,
        color: Colors.white10,
        child: const Icon(Icons.music_note_rounded,
            color: Colors.white38, size: 56),
      );

  Widget _transportButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.bounce,
      child: Icon(icon, color: color, size: size),
    );
  }
}

// One numbered step of the two-step "grant access" flow. Both steps stay
// visible regardless of progress — there's no public API to detect
// whether step 1 (restricted settings) is already done, so numbering
// them and letting the person judge which they still need is more honest
// than guessing.
class _AccessStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onTap;

  const _AccessStep({
    required this.number,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: _spotifyGreen, shape: BoxShape.circle),
                child: Text(number,
                    style: const TextStyle(
                        color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          SquishyTap(
            onTap: onTap,
            style: TapAnimationStyle.bounce,
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _spotifyGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(buttonLabel,
                  style: const TextStyle(
                      color: Colors.black, fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticePane extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _NoticePane({required this.emoji, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 54)),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
