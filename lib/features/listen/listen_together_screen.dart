import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/delight/couple_character.dart';
import '../../core/delight/delight.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
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

enum _Tab { search, myPlaylists, partnerPlaylists }

class _ListenTogetherScreenState extends ConsumerState<ListenTogetherScreen>
    with ActivityAnnouncer {
  final _spotify = SpotifyService.instance;

  _ConnState _conn = _ConnState.idle;
  String _error = '';

  _Tab _tab = _Tab.search;

  final _searchCtrl = TextEditingController();
  List<SpotifyTrack> _results = [];
  bool _searching = false;
  String? _searchError;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  List<SpotifyPlaylist> _myPlaylists = [];
  SpotifyPlaylist? _openPlaylist;
  List<SpotifyTrack> _playlistTracks = [];
  bool _loadingPlaylistTracks = false;

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
    announceActivity('Listening together');
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
      unawaited(_loadAndSyncPlaylists());
      unawaited(_syncAccountId());
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
    if (r.contains('auth_timeout')) {
      return "Spotify never redirected back to the app after you tapped "
          'Agree.\n\nAfter the last permission screen, look for an "Open in '
          'Two Hearts?" prompt and tap Open — if you tap outside it or the '
          "browser's back/close button instead, the app never gets the "
          "result. Tap connect to try again.";
    }
    return 'Couldn\'t connect to Spotify.\n$raw';
  }

  // ── Same-account detection ───────────────────────────────────────────────

  Future<void> _syncAccountId() async {
    try {
      final id = await _spotify.myUserId();
      final coupleId = ref.read(coupleIdProvider);
      if (id == null || coupleId == null) return;
      await ref.read(firestoreServiceProvider).syncSpotifyAccountId(coupleId, id);
    } catch (_) {}
  }

  bool _sameAccountAsPartner(Map<String, dynamic>? session) {
    final ids = session?['accountIds'] as Map<String, dynamic>?;
    if (ids == null || ids.length < 2) return false;
    final mine = ids[_uid] as String?;
    if (mine == null) return false;
    return ids.entries.any((e) => e.key != _uid && e.value == mine);
  }

  // ── Playlists ─────────────────────────────────────────────────────────────

  Future<void> _loadAndSyncPlaylists() async {
    try {
      final playlists = await _spotify.myPlaylists();
      if (!mounted) return;
      setState(() => _myPlaylists = playlists);
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId != null) {
        await ref.read(firestoreServiceProvider).syncSpotifyPlaylists(
              coupleId,
              playlists.map((p) => p.toMap()).toList(),
            );
      }
    } on SpotifyAuthException catch (e) {
      _reconnectHint(e.detail, _loadAndSyncPlaylists);
    } catch (_) {}
  }

  List<SpotifyPlaylist> _partnerPlaylistsFrom(Map<String, dynamic>? session) {
    final all = session?['playlists'] as Map<String, dynamic>?;
    if (all == null) return [];
    for (final entry in all.entries) {
      if (entry.key == _uid) continue;
      final list = entry.value as List?;
      if (list == null) return [];
      return list
          .map((p) => SpotifyPlaylist.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    }
    return [];
  }

  Future<void> _openPlaylistTracks(SpotifyPlaylist p) async {
    setState(() {
      _openPlaylist = p;
      _loadingPlaylistTracks = true;
      _playlistTracks = [];
    });
    try {
      final tracks = await _spotify.playlistTracks(p.id);
      if (mounted) setState(() => _playlistTracks = tracks);
    } on SpotifyAuthException catch (e) {
      _reconnectHint(e.detail, () => _openPlaylistTracks(p));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't load that playlist (it may be private)."),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingPlaylistTracks = false);
    }
  }

  // ── Queue ─────────────────────────────────────────────────────────────────

  Future<void> _addToQueue(SpotifyTrack t) async {
    HapticFeedback.selectionClick();
    try {
      await _spotify.addToQueue(t.uri);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added "${t.name}" to queue'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on NoDeviceException {
      _noDeviceHint();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't add to queue. Try again."),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showQueue() async {
    List<SpotifyTrack> queue = [];
    String? error;
    try {
      queue = await _spotify.queue();
    } catch (_) {
      error = "Couldn't load the queue.";
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Up next',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(error,
                      style: const TextStyle(color: Colors.white54)),
                )
              else if (queue.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Queue is empty — add a song below.',
                      style: TextStyle(color: Colors.white54)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: queue.length,
                    itemBuilder: (_, i) => _trackTile(queue[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  /// Shown when Spotify rejects a request as unauthorized — almost always a
  /// token issued before a scope change (e.g. this build added playlist
  /// permissions). A fresh sign-in re-grants the right scopes. [detail] is
  /// Spotify's own error text, shown via "Details" so it can be screenshot
  /// instead of guessed at blind. [retry], if given, is re-run automatically
  /// once reconnecting succeeds, so the user doesn't have to re-tap whatever
  /// they were doing (open the playlist / re-search) a second time.
  Future<void> _reconnect(VoidCallback? retry) async {
    await _spotify.signOut();
    if (!mounted) return;
    await _connect();
    if (mounted && _conn == _ConnState.connected) retry?.call();
  }

  void _reconnectHint(String? detail, [VoidCallback? retry]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text(
          'Spotify needs you to reconnect to enable this (permissions changed).'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: detail != null ? 'Details' : 'Reconnect',
        onPressed: () {
          if (detail == null) {
            _reconnect(retry);
            return;
          }
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF141414),
              title: const Text('Spotify said',
                  style: TextStyle(color: Colors.white)),
              content: SelectableText(detail,
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _reconnect(retry);
                  },
                  child: const Text('Reconnect'),
                ),
              ],
            ),
          );
        },
      ),
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
    // Guards against out-of-order responses: if a newer search has started
    // by the time this one resolves, its result is stale and must not
    // clobber the newer one.
    final requestId = ++_searchRequestId;
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final tracks = await _spotify.search(q);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _results = tracks);
    } on SpotifyAuthException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = [];
        _searchError = 'Spotify needs you to reconnect to search.';
      });
      _reconnectHint(e.detail, () => _runSearch(q));
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _results = [];
        // The real failure reason, not a canned guess — Spotify's raw
        // response (or the token-refresh error) is what actually helps
        // diagnose this instead of another blind fix.
        _searchError = 'Search failed:\n$e';
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _searching = false);
      }
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
            IconButton(
              icon: const Icon(Icons.queue_music_rounded,
                  color: Colors.white70),
              tooltip: 'Up next',
              onPressed: _showQueue,
            ),
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
            SquishyTap(
              onTap: connecting ? null : _connect,
              style: TapAnimationStyle.bounce,
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
        if (_sameAccountAsPartner(session)) _sameAccountBanner(),
        _nowPlaying(session),
        _tabBar(),
        if (_tab == _Tab.search) _searchBar(),
        Expanded(child: _body(session)),
      ],
    );
  }

  Widget _sameAccountBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You're both connected with the same Spotify account — "
              "Spotify only ever plays on one device at a time per account, "
              "so only one of you actually hears sound right now. For audio "
              "on both phones, each of you needs your own separate Spotify "
              "Premium account.",
              style: TextStyle(
                  color: Colors.orange.shade100, fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    Widget chip(_Tab t, String label) {
      final selected = _tab == t;
      return SquishyTap(
        onTap: () => setState(() {
          _tab = t;
          _openPlaylist = null;
        }),
        style: TapAnimationStyle.pulse,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _spotifyGreen.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? _spotifyGreen : Colors.white12),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? _spotifyGreen : Colors.white54,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          chip(_Tab.search, 'Search'),
          chip(_Tab.myPlaylists, 'My Playlists'),
          chip(_Tab.partnerPlaylists, "Their Playlists"),
        ],
      ),
    );
  }

  Widget _body(Map<String, dynamic>? session) {
    if (_openPlaylist != null) return _playlistTrackList();
    switch (_tab) {
      case _Tab.search:
        return _resultList();
      case _Tab.myPlaylists:
        return _playlistList(_myPlaylists, mine: true);
      case _Tab.partnerPlaylists:
        return _playlistList(_partnerPlaylistsFrom(session), mine: false);
    }
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
          const SizedBox(width: 10),
          if (!_localPaused)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: CoupleCharacter(
                character: CoupleCharacterId.combo,
                pose: 'head_on_shoulder',
                height: 58,
              ),
            ),
          const SizedBox(width: 4),
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
    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(_searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('Type to find your song ♫',
            style: TextStyle(color: Colors.white24, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) => _trackTile(_results[i]),
    );
  }

  Widget _trackTile(SpotifyTrack t) {
    return ListTile(
      onTap: () => _pickTrack(t),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: t.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: t.imageUrl, width: 46, height: 46, fit: BoxFit.cover)
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Colors.white54, size: 22),
            tooltip: 'Add to queue',
            onPressed: () => _addToQueue(t),
          ),
          const Icon(Icons.play_circle_outline_rounded, color: _spotifyGreen),
        ],
      ),
    );
  }

  Widget _playlistList(List<SpotifyPlaylist> playlists, {required bool mine}) {
    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mine
                ? "You don't have any Spotify playlists yet."
                : "Waiting for your partner to connect Spotify…",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: playlists.length,
      itemBuilder: (context, i) {
        final p = playlists[i];
        return ListTile(
          onTap: () => _openPlaylistTracks(p),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.imageUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover)
                : Container(
                    width: 46,
                    height: 46,
                    color: Colors.white10,
                    child: const Icon(Icons.queue_music_rounded,
                        color: Colors.white30, size: 20)),
          ),
          title: Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          subtitle: Text('${p.trackCount} songs${p.owner.isEmpty ? '' : ' · ${p.owner}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        );
      },
    );
  }

  Widget _playlistTrackList() {
    final playlist = _openPlaylist!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white70, size: 20),
                onPressed: () => setState(() => _openPlaylist = null),
              ),
              Expanded(
                child: Text(playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingPlaylistTracks
              ? const Center(
                  child: CircularProgressIndicator(color: _spotifyGreen))
              : _playlistTracks.isEmpty
                  ? const Center(
                      child: Text('No tracks found.',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: _playlistTracks.length,
                      itemBuilder: (context, i) =>
                          _trackTile(_playlistTracks[i]),
                    ),
        ),
      ],
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
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.pulse,
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
