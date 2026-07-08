import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/delight/delight.dart';
import '../../core/providers/providers.dart';
import 'spotify_config.dart';
import 'spotify_service.dart';

const _spotifyGreen = Color(0xFF1DB954);

/// Listen Together — one shared Spotify track, play/pause/track mirrored
/// between both phones through Firestore. Each phone plays through its own
/// Spotify Premium account (Web API); we keep the "now playing" in sync
/// (same pattern as Movie Night).
class ListenTogetherScreen extends ConsumerStatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  ConsumerState<ListenTogetherScreen> createState() =>
      _ListenTogetherScreenState();
}

enum _ConnState { idle, connecting, connected, error }

class _ListenTogetherScreenState extends ConsumerState<ListenTogetherScreen> {
  final _spotify = SpotifyService.instance;

  _ConnState _conn = _ConnState.idle;
  String _error = '';

  final _searchCtrl = TextEditingController();
  List<SpotifyTrack> _results = [];
  bool _searching = false;
  Timer? _searchDebounce;

  Timer? _heartbeat;
  Timer? _poll;

  // Local playback mirror (polled from the Web API).
  bool _localPaused = true;
  int _localPositionMs = 0;
  String? _localUri;

  // Sync bookkeeping — ignore our own echoes, apply the partner's changes.
  String? _appliedUri;
  bool? _appliedPlaying;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (SpotifyConfig.isConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    _heartbeat?.cancel();
    _poll?.cancel();
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).leaveListen(coupleId);
    }
    super.dispose();
  }

  // ── Connect ────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    setState(() {
      _conn = _ConnState.connecting;
      _error = '';
    });
    try {
      await _spotify.loadCached();
      if (!_spotify.isSignedIn) {
        await _spotify.signIn();
      } else {
        // Validate the cached token; falls through to sign-in on failure.
        try {
          await _spotify.currentState();
        } catch (_) {
          await _spotify.signIn();
        }
      }
      if (!mounted) return;
      setState(() => _conn = _ConnState.connected);
      _startPolling();
      _startHeartbeat();
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        await ref.read(firestoreServiceProvider).joinListen(coupleId);
      }
      DelightHaptics.soft();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conn = _ConnState.error;
        _error = _friendlyError(e.toString());
      });
    }
  }

  String _friendlyError(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('denied') || r.contains('cancel') ||
        r.contains('user_cancel')) {
      return 'Spotify sign-in was cancelled. Tap connect to try again.';
    }
    if (r.contains('premium')) {
      return 'Listen Together needs Spotify Premium on both sides.';
    }
    return 'Couldn\'t connect to Spotify.\n$raw';
  }

  // ── Poll local state → mirror to Firestore ───────────────────────────────

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final s = await _spotify.currentState();
        if (s == null || !mounted) return;
        _localPaused = !s.isPlaying;
        _localPositionMs = s.positionMs;
        _localUri = s.uri;
        setState(() {});
        _maybeWritePlayback();
      } catch (_) {}
    });
  }

  Future<void> _maybeWritePlayback({bool force = false}) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null || _localUri == null) return;
    if (!force &&
        DateTime.now().difference(_lastWrite) <
            const Duration(milliseconds: 900)) {
      return;
    }
    _lastWrite = DateTime.now();
    await ref.read(firestoreServiceProvider).updateListenPlayback(
          coupleId,
          isPlaying: !_localPaused,
          positionMs: _localPositionMs,
        );
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        ref.read(firestoreServiceProvider).listenHeartbeat(coupleId);
      }
    });
  }

  // ── Apply the partner's changes ──────────────────────────────────────────

  bool _iAmController(Map<String, dynamic>? session) =>
      session != null && session['updatedBy'] == _uid;

  Future<void> _applyRemote(Map<String, dynamic> session) async {
    if (_conn != _ConnState.connected) return;
    if (_iAmController(session)) return; // my own echo
    final uri = session['uri'] as String?;
    final isPlaying = session['isPlaying'] as bool? ?? false;
    if (uri == null) return;

    if (uri != _appliedUri) {
      _appliedUri = uri;
      _appliedPlaying = isPlaying;
      try {
        await _spotify.play(uri, positionMs: _expectedPosition(session));
        if (!isPlaying) await _spotify.pause();
      } on NoDeviceException {
        _noDeviceHint();
      } catch (_) {}
      return;
    }
    if (isPlaying != _appliedPlaying) {
      _appliedPlaying = isPlaying;
      try {
        if (isPlaying) {
          await _spotify.resume();
        } else {
          await _spotify.pause();
        }
      } on NoDeviceException {
        _noDeviceHint();
      } catch (_) {}
    }
  }

  int _expectedPosition(Map<String, dynamic> session) {
    final base = (session['positionMs'] as num?)?.toInt() ?? 0;
    final playing = session['isPlaying'] as bool? ?? false;
    final ts = session['updatedAt'];
    if (!playing || ts == null) return base;
    DateTime? updated;
    try {
      updated = (ts as dynamic).toDate() as DateTime;
    } catch (_) {}
    if (updated == null) return base;
    final elapsed = DateTime.now().difference(updated).inMilliseconds;
    return base + elapsed.clamp(0, 600000);
  }

  Future<void> _resync(Map<String, dynamic> session) async {
    try {
      await _spotify.seek(_expectedPosition(session));
      if (session['isPlaying'] == true) await _spotify.resume();
      DelightHaptics.soft();
    } on NoDeviceException {
      _noDeviceHint();
    } catch (_) {}
  }

  void _noDeviceHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Open Spotify on your phone and press play once, then tap Re-sync.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(q.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final tracks = await _spotify.search(q);
      if (mounted) setState(() => _results = tracks);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickTrack(SpotifyTrack t) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    _appliedUri = t.uri;
    _appliedPlaying = true;
    try {
      await _spotify.play(t.uri);
    } on NoDeviceException {
      _noDeviceHint();
    } catch (_) {}
    await ref.read(firestoreServiceProvider).setListenTrack(
          coupleId,
          uri: t.uri,
          name: t.name,
          artist: t.artist,
          imageUrl: t.imageUrl,
          durationMs: t.durationMs,
        );
    if (mounted) {
      setState(() => _results = []);
      _searchCtrl.clear();
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_localPaused) {
        await _spotify.resume();
      } else {
        await _spotify.pause();
      }
      _localPaused = !_localPaused;
      setState(() {});
      await _maybeWritePlayback(force: true);
    } on NoDeviceException {
      _noDeviceHint();
    } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(listenSessionProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;

    ref.listen(listenSessionProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null) _applyRemote(s);
    });

    final partnerHere = _partnerPresent(session);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            _header(partner?.displayLabel.split(' ').first, partnerHere),
            Expanded(
              child: !SpotifyConfig.isConfigured
                  ? const _SetupNotice()
                  : _conn != _ConnState.connected
                      ? _connectPane()
                      : _room(session),
            ),
          ],
        ),
      ),
    );
  }

  bool _partnerPresent(Map<String, dynamic>? session) {
    final present = session?['present'] as Map<String, dynamic>?;
    if (present == null) return false;
    for (final e in present.entries) {
      if (e.key == _uid) continue;
      try {
        final t = (e.value as dynamic).toDate() as DateTime;
        if (DateTime.now().difference(t).inSeconds < 60) return true;
      } catch (_) {}
    }
    return false;
  }

  Widget _header(String? partnerName, bool partnerHere) {
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
          const Text('Listen Together',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_conn == _ConnState.connected)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: partnerHere ? _spotifyGreen : Colors.white24,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  partnerHere
                      ? '${partnerName ?? 'They'} is here'
                      : 'waiting for ${partnerName ?? 'them'}…',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _connectPane() {
    final connecting = _conn == _ConnState.connecting;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎧', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text(
              'Play the same song,\nat the same second ♡',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect your Spotify (Premium) to start. Your partner connects '
              'theirs — whoever picks a song, both hear it.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            if (_conn == _ConnState.error) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12.5, height: 1.4)),
              ),
            ],
            const SizedBox(height: 28),
            GestureDetector(
              onTap: connecting ? null : _connect,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  color: _spotifyGreen,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: _spotifyGreen.withValues(alpha: 0.4),
                        blurRadius: 18),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (connecting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    else
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.black, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      connecting ? 'Connecting…' : 'Connect Spotify',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _room(Map<String, dynamic>? session) {
    return Column(
      children: [
        _nowPlaying(session),
        _searchBar(),
        Expanded(child: _resultList()),
      ],
    );
  }

  Widget _nowPlaying(Map<String, dynamic>? session) {
    final name = session?['name'] as String?;
    final artist = session?['artist'] as String?;
    final image = session?['imageUrl'] as String?;
    final has = name != null && (session?['uri'] != null);

    if (!has) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          children: [
            Text('🎵', style: TextStyle(fontSize: 34)),
            SizedBox(height: 10),
            Text('Search a song below to start the vibe',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _spotifyGreen.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _spotifyGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image != null && image.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: image, width: 64, height: 64, fit: BoxFit.cover)
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note_rounded,
                        color: Colors.white38)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MiniBtn(
                      icon: _localPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onTap: _togglePlay,
                    ),
                    const SizedBox(width: 8),
                    _MiniBtn(
                      icon: Icons.sync_rounded,
                      label: 'Re-sync',
                      onTap:
                          session == null ? null : () => _resync(session),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search a song or artist…',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _spotifyGreen)),
                )
              : const Icon(Icons.search_rounded, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _resultList() {
    if (_results.isEmpty) {
      return const Center(
        child: Text('Type to find your song ♫',
            style: TextStyle(color: Colors.white24, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final t = _results[i];
        return ListTile(
          onTap: () => _pickTrack(t),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: t.imageUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover)
                : Container(
                    width: 46,
                    height: 46,
                    color: Colors.white10,
                    child: const Icon(Icons.music_note_rounded,
                        color: Colors.white30, size: 20)),
          ),
          title: Text(t.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          subtitle: Text(t.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: const Icon(Icons.play_circle_outline_rounded,
              color: _spotifyGreen),
        );
      },
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  const _MiniBtn({required this.icon, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label == null ? 8 : 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.04 : 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: onTap == null ? Colors.white30 : Colors.white,
                size: 18),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(label!,
                  style: TextStyle(
                      color: onTap == null ? Colors.white30 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔧', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 18),
            const Text(
              'Listen Together needs a\none-time Spotify setup',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3),
            ),
            const SizedBox(height: 14),
            const Text(
              'Create a free app at developer.spotify.com, then build with '
              'your Client ID:\n\n'
              'flutter run --dart-define=SPOTIFY_CLIENT_ID=xxxx\n\n'
              '(Full steps are in lib/features/listen/spotify_config.dart)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
