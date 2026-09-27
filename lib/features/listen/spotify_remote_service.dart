import 'package:flutter/services.dart';

/// Controls whatever's playing in the Spotify app on THIS phone via
/// Android's system MediaSession framework — no Spotify API/OAuth
/// involved at all. This is the same OS-level mechanism Bluetooth headset
/// buttons, car head units, and Android Auto already use to control
/// Spotify, since any well-behaved Android media app exposes transport
/// controls through it.
///
/// Deliberately local-only: there is no way to reach into a partner's
/// phone, search Spotify's catalog, or browse playlists through this
/// mechanism — those all require the real Spotify Web API, which this is
/// the replacement for (see CLAUDE.md's "Listen Together" section for why
/// that tradeoff was made). See SpotifyListenerService.kt for the Android
/// side.
class SpotifyRemoteService {
  SpotifyRemoteService._();
  static final instance = SpotifyRemoteService._();

  static const _channel = MethodChannel('two_hearts/spotify_remote');

  /// Whether this app is currently enabled as a Notification Listener —
  /// the permission Android bundles MediaSession access under. There's no
  /// narrower permission just for reading media sessions.
  Future<bool> isAccessGranted() async =>
      (await _channel.invokeMethod<bool>('isEnabled')) ?? false;

  /// Step 1 of granting access on Android 13+: deep-links straight to this
  /// app's own "App info" page (skips hunting for it in the full app
  /// list). From there the person still has to tap the ⋮ overflow menu and
  /// confirm "Allow restricted settings" themselves — Android deliberately
  /// makes that one tap impossible for any app to trigger on its own,
  /// since the whole point of the protection is stopping apps from
  /// silently granting themselves sensitive permissions like this one.
  Future<void> openAppInfoSettings() => _channel.invokeMethod('openAppInfo');

  /// Step 2: Android's system "Notification access" settings page, where
  /// the actual toggle for this app lives (only actionable once step 1's
  /// restriction has been lifted).
  Future<void> openAccessSettings() => _channel.invokeMethod('openSettings');

  /// Launches Spotify if installed (returns true), or its Play Store
  /// listing if not (returns false).
  Future<bool> openSpotify() async =>
      (await _channel.invokeMethod<bool>('openSpotify')) ?? false;

  Future<void> playPause() => _channel.invokeMethod('playPause');
  Future<void> skipNext() => _channel.invokeMethod('skipNext');
  Future<void> skipPrevious() => _channel.invokeMethod('skipPrevious');

  /// Current now-playing state, or null if Spotify has no active media
  /// session right now (not open, or never played anything this launch).
  Future<SpotifyNowPlaying?> getState() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('getState');
    if (raw == null) return null;
    return SpotifyNowPlaying.fromMap(raw);
  }
}

class SpotifyNowPlaying {
  final String? title;
  final String? artist;
  final String? album;
  final int durationMs;
  final int positionMs;
  final bool isPlaying;
  final String? artUri;

  SpotifyNowPlaying({
    this.title,
    this.artist,
    this.album,
    required this.durationMs,
    required this.positionMs,
    required this.isPlaying,
    this.artUri,
  });

  factory SpotifyNowPlaying.fromMap(Map<String, dynamic> m) => SpotifyNowPlaying(
        title: m['title'] as String?,
        artist: m['artist'] as String?,
        album: m['album'] as String?,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
        isPlaying: m['isPlaying'] as bool? ?? false,
        artUri: m['artUri'] as String?,
      );
}
