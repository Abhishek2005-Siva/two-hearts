import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';

import '../../core/delight/delight.dart';
import '../../core/providers/providers.dart';
import 'spotify_config.dart';

const _spotifyGreen = Color(0xFF1DB954);

/// Listen Together — one shared Spotify track, play/pause/track mirrored
/// between both phones through Firestore. Each phone plays through its own
/// Spotify Premium account; we just keep the "now playing" in sync (same
/// pattern as Movie Night).
class ListenTogetherScreen extends ConsumerStatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  ConsumerState<ListenTogetherScreen> createState() =>
      _ListenTogetherScreenState();
}

enum _ConnState { idle, connecting, connected, error }

class _ListenTogetherScreenState extends ConsumerState<ListenTogetherScreen> {
  _ConnState _conn = _ConnState.idle;
  String _error = '';
  String? _token;

  final _searchCtrl = TextEditingController();
  List<_Track> _results = [];
  bool _searching = false;
  Timer? _searchDebounce;

  StreamSubscription? _playerSub;
  Timer? _heartbeat;
  Timer? _positionWriter;

  // Local playback mirror (from the Spotify SDK).
  bool _localPaused = true;
  int _localPositionMs = 0;
  String? _localUri;

  // Sync bookkeeping — ignore our own echoes, apply the partner's changes.
  String? _appliedUri;
  bool? _appliedPlaying;

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
    _playerSub?.cancel();
    _heartbeat?.cancel();
    _positionWriter?.cancel();
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) {
      ref.read(firestoreServiceProvider).leaveListen(coupleId);
    }
    try {
      SpotifySdk.disconnect();
    } catch (_) {}
    super.dispose();
  }

  // ── Connect ────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    setState(() {
      _conn = _ConnState.connecting;
      _error = '';
    });
    try {
      await SpotifySdk.connectToSpotifyRemote(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUri,
        scope: SpotifyConfig.scope,
      );
      _token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUri,
        scope: SpotifyConfig.scope,
      );
      if (!mounted) return;
      setState(() => _conn = _ConnState.connected);
      _startPlayerSubscription();
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
    if (r.contains('couldn') || r.contains('not installed') ||
        r.contains('notinstalled')) {
      return 'Spotify app not found. Install Spotify and make sure you\'re '
          'logged in with a Premium account, then try again.';
    }
    if (r.contains('auth') || r.contains('denied') || r.contains('token')) {
      return 'Spotify sign-in was cancelled or denied. Tap connect to retry.';
    }
    if (r.contains('premium')) {
      return 'Listen Together needs Spotify Premium on both sides.';
    }
    return 'Couldn\'t connect to Spotify. $raw';
  }

  // ── Local player state → Firestore ───────────────────────────────────────

  void _startPlayerSubscription() {
    _playerSub?.cancel();
    _playerSub = SpotifySdk.subscribePlayerState().listen((PlayerState s) {
      final track = s.track;
      _localPaused = s.isPaused;
      _localPositionMs = s.playbackPosition;
      _localUri = track?.uri;
      if (mounted) setState(() {});
      // Push my play/pause changes so the partner follows.
      _maybeWritePlayback();
    });
    // Also push position periodically so a re-sync / late join lands close.
    _positionWriter?.cancel();
    _positionWriter = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_localPaused) _maybeWritePlayback(force: true);
    });
  }

  bool _iAmController(Map<String, dynamic>? session) =>
      session != null && session['updatedBy'] == _uid;

  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _maybeWritePlayback({bool force = false}) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null || _localUri == null) return;
    // Throttle to avoid hammering Firestore on every state tick.
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

  Future<void> _applyRemote(Map<String, dynamic> session) async {
    if (_conn != _ConnState.connected) return;
    if (_iAmController(session)) return; // my own echo
    final uri = session['uri'] as String?;
    final isPlaying = session['isPlaying'] as bool? ?? false;
    if (uri == null) return;

    // New track chosen by the partner → play it here and seek to their spot.
    if (uri != _appliedUri) {
      _appliedUri = uri;
      _appliedPlaying = isPlaying;
      try {
        await SpotifySdk.play(spotifyUri: uri);
        final pos = _expectedPosition(session);
        if (pos > 1500) await SpotifySdk.seekTo(positionedMilliseconds: pos);
        if (!isPlaying) await SpotifySdk.pause();
      } catch (_) {}
      return;
    }
    // Same track, play/pause flipped.
    if (isPlaying != _appliedPlaying) {
      _appliedPlaying = isPlaying;
      try {
        if (isPlaying) {
          await SpotifySdk.resume();
        } else {
          await SpotifySdk.pause();
        }
      } catch (_) {}
    }
  }

  /// Their stored position advanced by however long ago they wrote it.
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
      final pos = _expectedPosition(session);
      await SpotifySdk.seekTo(positionedMilliseconds: pos);
      if (session['isPlaying'] == true) {
        await SpotifySdk.resume();
      }
      DelightHaptics.soft();
    } catch (_) {}
  }

  // ── Search (Spotify Web API) ─────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      _runSearch(q.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty || _token == null) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await http.get(
        Uri.parse(
            'https://api.spotify.com/v1/search?type=track&limit=25&q=${Uri.encodeQueryComponent(q)}'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode == 401) {
        // Token expired — refresh and retry once.
        _token = await SpotifySdk.getAccessToken(
          clientId: SpotifyConfig.clientId,
          redirectUrl: SpotifyConfig.redirectUri,
          scope: SpotifyConfig.scope,
        );
        return _runSearch(q);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['tracks']?['items'] as List?) ?? [];
      final tracks = items.map((t) => _Track.fromJson(t)).toList();
      if (mounted) setState(() => _results = tracks);
    } catch (_) {
      // Leave results as-is on a transient failure.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickTrack(_Track t) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    _appliedUri = t.uri; // don't echo this back onto ourselves
    _appliedPlaying = true;
    try {
      await SpotifySdk.play(spotifyUri: t.uri);
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

  Future<void> _togglePlay(Map<String, dynamic>? session) async {
    try {
      if (_localPaused) {
        await SpotifySdk.resume();
      } else {
        await SpotifySdk.pause();
      }
      await _maybeWritePlayback(force: true);
    } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(listenSessionProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;

    // Apply partner updates as they arrive.
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
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
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
              style: TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            if (_conn == _ConnState.error) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3)),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 15),
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
                    imageUrl: image,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover)
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
                      onTap: () => _togglePlay(session),
                    ),
                    const SizedBox(width: 8),
                    _MiniBtn(
                      icon: Icons.sync_rounded,
                      label: 'Re-sync',
                      onTap: session == null
                          ? null
                          : () => _resync(session),
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
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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

// ── Track model (from Web API search) ───────────────────────────────────────

class _Track {
  final String uri;
  final String name;
  final String artist;
  final String imageUrl;
  final int durationMs;

  _Track({
    required this.uri,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.durationMs,
  });

  factory _Track.fromJson(Map<String, dynamic> j) {
    final artists = (j['artists'] as List?) ?? [];
    final images = (j['album']?['images'] as List?) ?? [];
    return _Track(
      uri: j['uri'] as String? ?? '',
      name: j['name'] as String? ?? 'Unknown',
      artist: artists.isEmpty
          ? ''
          : artists.map((a) => a['name'] as String? ?? '').join(', '),
      imageUrl: images.isEmpty ? '' : (images.last['url'] as String? ?? ''),
      durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
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
              'Create a free app at developer.spotify.com, then build the '
              'app with your Client ID:\n\n'
              'flutter run --dart-define=SPOTIFY_CLIENT_ID=xxxx\n\n'
              '(Full steps are in lib/features/listen/spotify_config.dart)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
