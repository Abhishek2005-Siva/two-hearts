/// Spotify Developer credentials for "Listen Together".
///
/// SETUP (one-time, done by you):
///   1. Go to https://developer.spotify.com/dashboard and create an app.
///   2. Copy its Client ID and build with it (see below).
///   3. In the app's settings, add this exact Redirect URI:
///        twohearts-spotify://callback
///   4. Both partners need Spotify **Premium** with the Spotify app
///      installed and opened at least once (Web API playback control needs
///      an active Spotify device). Playback control is Premium-only.
///
/// Provide the Client ID at build time:
///   flutter run --dart-define=SPOTIFY_CLIENT_ID=xxxxxxxx
///
/// Until it's set, the Listen Together screen shows a friendly setup notice
/// instead of trying to connect. No proprietary native SDK is required — we
/// talk to the Spotify Web API over HTTPS with an OAuth (PKCE) token.
class SpotifyConfig {
  /// Your Spotify app's Client ID. Leave empty to disable the feature.
  static const String clientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '',
  );

  /// Must match a Redirect URI registered in your Spotify dashboard.
  static const String redirectUri = 'twohearts-spotify://callback';

  /// The custom scheme part of [redirectUri], used by flutter_web_auth_2.
  static const String callbackScheme = 'twohearts-spotify';

  /// Scopes: control playback, read what's currently playing, and read
  /// playlists (own + collaborative) for the "both accounts' playlists"
  /// browser.
  static const List<String> scopes = [
    'user-modify-playback-state',
    'user-read-playback-state',
    'user-read-currently-playing',
    'user-read-private',
    'playlist-read-private',
    'playlist-read-collaborative',
    'streaming',
  ];

  static String get scopeString => scopes.join(' ');

  static bool get isConfigured => clientId.isNotEmpty;
}
