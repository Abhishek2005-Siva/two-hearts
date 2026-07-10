import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'spotify_config.dart';

/// Thin wrapper around the Spotify Web API + OAuth (Authorization Code with
/// PKCE). No proprietary native SDK — just HTTPS. Tokens are cached in
/// SharedPreferences and auto-refreshed.
class SpotifyService {
  SpotifyService._();
  static final SpotifyService instance = SpotifyService._();

  static const _kAccess = 'spotify_access_token';
  static const _kRefresh = 'spotify_refresh_token';
  static const _kExpiry = 'spotify_expiry_ms';
  static const _kMarket = 'spotify_market';

  String? _accessToken;
  String? _refreshToken;
  DateTime _expiry = DateTime.fromMillisecondsSinceEpoch(0);
  String? _market;
  String? _userId;

  bool get isSignedIn => _refreshToken != null;

  // ── Auth ──────────────────────────────────────────────────────────────

  Future<void> loadCached() async {
    final p = await SharedPreferences.getInstance();
    _accessToken = p.getString(_kAccess);
    _refreshToken = p.getString(_kRefresh);
    _expiry = DateTime.fromMillisecondsSinceEpoch(p.getInt(_kExpiry) ?? 0);
    _market = p.getString(_kMarket);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (_accessToken != null) await p.setString(_kAccess, _accessToken!);
    if (_refreshToken != null) await p.setString(_kRefresh, _refreshToken!);
    await p.setInt(_kExpiry, _expiry.millisecondsSinceEpoch);
    if (_market != null) await p.setString(_kMarket, _market!);
  }

  Future<void> signOut() async {
    _accessToken = _refreshToken = _market = _userId = null;
    _expiry = DateTime.fromMillisecondsSinceEpoch(0);
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAccess);
    await p.remove(_kRefresh);
    await p.remove(_kExpiry);
    await p.remove(_kMarket);
  }

  /// The signed-in account's market (ISO 3166-1 alpha-2 country code), used
  /// to scope search results. Spotify deprecated the `market=from_token`
  /// shortcut in Nov 2024 — a literal code must be sent instead — so this is
  /// fetched from `/me` once (needs `user-read-private`) and cached.
  Future<String?> _resolveMarket() async {
    if (_market != null) return _market;
    await _fetchMe();
    return _market;
  }

  /// This Spotify account's own user ID — used to detect both partners
  /// having connected the *same* Spotify account (which only lets one of
  /// their phones play at a time; that's a Spotify-side restriction, not a
  /// bug in this app).
  Future<String?> myUserId() async {
    if (_userId != null) return _userId;
    await _fetchMe();
    return _userId;
  }

  Future<void> _fetchMe() async {
    try {
      final res = await _api('GET', '/me');
      if (res.statusCode != 200) return;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final country = j['country'] as String?;
      if (country != null && country.isNotEmpty) _market = country;
      final id = j['id'] as String?;
      if (id != null && id.isNotEmpty) _userId = id;
      await _persist();
    } catch (_) {}
  }

  String _randomString(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rng = Random.secure();
    return List.generate(len, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _b64url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  /// Runs the full browser OAuth flow. Throws on failure/cancel.
  Future<void> signIn() async {
    final verifier = _randomString(96);
    final challenge = _b64url(sha256.convert(utf8.encode(verifier)).bytes);

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': SpotifyConfig.clientId,
      'response_type': 'code',
      'redirect_uri': SpotifyConfig.redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': SpotifyConfig.scopeString,
      // Forces the consent screen every time, even if this account already
      // approved the app under an older, narrower scope set — without this,
      // Spotify can silently skip re-prompting and hand back a token that
      // still lacks the newly-added scopes (e.g. playlist access), so
      // tapping "reconnect" would appear to do nothing.
      'show_dialog': 'true',
    }).toString();

    // Without a timeout, a redirect that never makes it back into the app
    // (e.g. Android not handing the custom scheme back to us) hangs this
    // Future forever with no error shown — the user is left staring at a
    // stuck browser tab with no way to recover except force-closing it.
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: SpotifyConfig.callbackScheme,
      ).timeout(const Duration(minutes: 3));
    } on TimeoutException {
      throw Exception(
          'auth_timeout: the redirect back to the app never arrived');
    }
    final code = Uri.parse(result).queryParameters['code'];
    final err = Uri.parse(result).queryParameters['error'];
    if (err != null) throw Exception('auth denied: $err');
    if (code == null) throw Exception('auth failed: no code');

    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': SpotifyConfig.redirectUri,
        'client_id': SpotifyConfig.clientId,
        'code_verifier': verifier,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('token exchange failed: ${res.body}');
    }
    _storeToken(jsonDecode(res.body) as Map<String, dynamic>);
    await _persist();
  }

  Future<void> _refresh() async {
    if (_refreshToken == null) throw Exception('not signed in');
    final res = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
        'client_id': SpotifyConfig.clientId,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('token refresh failed: ${res.body}');
    }
    _storeToken(jsonDecode(res.body) as Map<String, dynamic>);
    await _persist();
  }

  void _storeToken(Map<String, dynamic> j) {
    _accessToken = j['access_token'] as String?;
    if (j['refresh_token'] != null) _refreshToken = j['refresh_token'] as String;
    final expiresIn = (j['expires_in'] as num?)?.toInt() ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
  }

  Future<String> _validToken() async {
    if (_accessToken == null || DateTime.now().isAfter(_expiry)) {
      await _refresh();
    }
    return _accessToken!;
  }

  // ── Web API calls ────────────────────────────────────────────────────────

  Future<http.Response> _api(String method, String path,
      {Map<String, dynamic>? body}) async {
    final token = await _validToken();
    final uri = Uri.parse('https://api.spotify.com/v1$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    switch (method) {
      case 'PUT':
        return http.put(uri, headers: headers, body: jsonEncode(body ?? {}));
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      default:
        return http.get(uri, headers: headers);
    }
  }

  Future<List<SpotifyTrack>> search(String query) async {
    final String token;
    try {
      token = await _validToken();
    } catch (e) {
      // A token-refresh failure lands here, not below — surface it instead
      // of letting it masquerade as a network error.
      throw Exception('token refresh: $e');
    }
    // `market` matters: without it Spotify only returns tracks playable in
    // every market worldwide, which silently drops most regional catalogue.
    // Spotify deprecated the `from_token` shortcut in Nov 2024 (it now
    // 400s), so a real country code resolved from the account is used
    // instead — and omitted entirely if it can't be resolved, rather than
    // failing the whole search.
    final market = await _resolveMarket();
    // Spotify's search `limit` is capped at 10 (not the historical 1-50) —
    // 25 was rejected outright with 400 "Invalid limit".
    final uri = Uri.https('api.spotify.com', '/v1/search', {
      'type': 'track',
      'limit': '10',
      'market': ?market,
      'q': query,
    });
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw SpotifyAuthException.fromResponse(res.statusCode, res.body);
    }
    if (res.statusCode != 200) {
      throw Exception('search failed (${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['tracks']?['items'] as List?) ?? [];
    return items.map((t) => SpotifyTrack.fromJson(t)).toList();
  }

  /// Adds a track to the local playback queue without interrupting the
  /// current song.
  Future<void> addToQueue(String uri) async {
    if (!await ensureActiveDevice()) throw NoDeviceException();
    final res = await _api('POST',
        '/me/player/queue?uri=${Uri.encodeQueryComponent(uri)}');
    if (res.statusCode == 404) throw NoDeviceException();
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('queue failed (${res.statusCode})');
    }
  }

  /// Currently playing track plus what's queued up next, on this device.
  Future<List<SpotifyTrack>> queue() async {
    final res = await _api('GET', '/me/player/queue');
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['queue'] as List?) ?? [];
    return items
        .map((t) => SpotifyTrack.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// The signed-in account's own playlists.
  Future<List<SpotifyPlaylist>> myPlaylists() async {
    final res = await _api('GET', '/me/playlists?limit=50');
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw SpotifyAuthException.fromResponse(res.statusCode, res.body);
    }
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? [];
    return items
        .map((p) => SpotifyPlaylist.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Tracks inside a playlist (works for any playlist ID this account can
  /// see — own playlists, or a partner's if they're public/collaborative).
  /// Throws [SpotifyAuthException] on 401/403 — usually a stale token that
  /// predates a scope change and needs a fresh sign-in.
  Future<List<SpotifyTrack>> playlistTracks(String playlistId) async {
    final res = await _api(
        'GET', '/playlists/${Uri.encodeComponent(playlistId)}/tracks?limit=50');
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw SpotifyAuthException.fromResponse(res.statusCode, res.body);
    }
    if (res.statusCode != 200) {
      throw Exception('playlist load failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? [];
    return items
        .map((it) => (it as Map<String, dynamic>)['track'])
        .whereType<Map<String, dynamic>>()
        .map((t) => SpotifyTrack.fromJson(t))
        .toList();
  }

  /// Ensures a device is active — transfers playback to the first available
  /// one. Returns false if Spotify isn't open anywhere.
  Future<bool> ensureActiveDevice() async {
    final res = await _api('GET', '/me/player/devices');
    if (res.statusCode != 200) return false;
    final devices = (jsonDecode(res.body)['devices'] as List?) ?? [];
    if (devices.isEmpty) return false;
    if (devices.any((d) => d['is_active'] == true)) return true;
    final id = devices.first['id'];
    await _api('PUT', '/me/player', body: {
      'device_ids': [id],
      'play': false,
    });
    return true;
  }

  /// Plays a track from a position. Throws [NoDeviceException] if Spotify
  /// isn't open on any device.
  Future<void> play(String uri, {int positionMs = 0}) async {
    if (!await ensureActiveDevice()) throw NoDeviceException();
    final res = await _api('PUT', '/me/player/play',
        body: {'uris': [uri], 'position_ms': positionMs});
    if (res.statusCode == 404) throw NoDeviceException();
  }

  Future<void> resume() async {
    if (!await ensureActiveDevice()) throw NoDeviceException();
    await _api('PUT', '/me/player/play');
  }

  Future<void> pause() => _api('PUT', '/me/player/pause');

  Future<void> seek(int positionMs) =>
      _api('PUT', '/me/player/seek?position_ms=$positionMs');

  /// Current local playback state, or null if nothing is playing.
  Future<PlaybackState?> currentState() async {
    final res = await _api('GET', '/me/player');
    if (res.statusCode != 200 || res.body.isEmpty) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return PlaybackState(
      isPlaying: j['is_playing'] as bool? ?? false,
      positionMs: (j['progress_ms'] as num?)?.toInt() ?? 0,
      uri: j['item']?['uri'] as String?,
    );
  }
}

class NoDeviceException implements Exception {}

/// Thrown when the Spotify API rejects a request as unauthorized/forbidden
/// — most commonly a token issued before a scope change, which a fresh
/// sign-in fixes. Carries Spotify's own error message so it can be shown
/// to the user instead of guessed at.
class SpotifyAuthException implements Exception {
  final String? detail;
  SpotifyAuthException([this.detail]);

  /// Pulls Spotify's `{"error": {"message": "..."}}` body into a short
  /// human-readable string, falling back to the raw body if it's not JSON.
  factory SpotifyAuthException.fromResponse(int status, String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      final msg = j['error']?['message'] as String? ?? j['error'] as String?;
      if (msg != null) return SpotifyAuthException('$status: $msg');
    } catch (_) {}
    return SpotifyAuthException(
        '$status: ${body.isEmpty ? '(empty body)' : body}');
  }
}

class SpotifyPlaylist {
  final String id;
  final String name;
  final String imageUrl;
  final int trackCount;
  final String owner;

  SpotifyPlaylist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.trackCount,
    required this.owner,
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as List?) ?? [];
    return SpotifyPlaylist(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? 'Untitled',
      imageUrl: images.isEmpty ? '' : (images.first['url'] as String? ?? ''),
      trackCount: (j['tracks']?['total'] as num?)?.toInt() ?? 0,
      owner: j['owner']?['display_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'imageUrl': imageUrl,
        'trackCount': trackCount,
        'owner': owner,
      };

  factory SpotifyPlaylist.fromMap(Map<String, dynamic> m) => SpotifyPlaylist(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? 'Untitled',
        imageUrl: m['imageUrl'] as String? ?? '',
        trackCount: (m['trackCount'] as num?)?.toInt() ?? 0,
        owner: m['owner'] as String? ?? '',
      );
}

class PlaybackState {
  final bool isPlaying;
  final int positionMs;
  final String? uri;
  PlaybackState(
      {required this.isPlaying, required this.positionMs, this.uri});
}

class SpotifyTrack {
  final String uri;
  final String name;
  final String artist;
  final String imageUrl;
  final int durationMs;

  SpotifyTrack({
    required this.uri,
    required this.name,
    required this.artist,
    required this.imageUrl,
    required this.durationMs,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> j) {
    final artists = (j['artists'] as List?) ?? [];
    final images = (j['album']?['images'] as List?) ?? [];
    return SpotifyTrack(
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
