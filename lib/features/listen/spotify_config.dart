/// Spotify Developer credentials for "Listen Together".
///
/// SETUP (one-time, done by you):
///   1. Go to https://developer.spotify.com/dashboard and create an app.
///   2. Copy its Client ID into [clientId] below.
///   3. In the app's settings, add a Redirect URI that matches
///      [redirectUri] exactly (e.g. `twohearts://spotify-callback`).
///   4. For Android, add your app's SHA-1 fingerprint and the package name
///      `com.twohearts.two_hearts` under "Android Packages" in the Spotify
///      dashboard. (The redirect scheme `twohearts://` is already registered
///      in AndroidManifest.xml.)
///   5. Both partners must have Spotify **Premium** and the Spotify app
///      installed — full playback is Premium-only.
///
/// Until [clientId] is filled in, the Listen Together screen shows a friendly
/// "not set up yet" notice instead of trying to connect.
class SpotifyConfig {
  /// Your Spotify app's Client ID. Leave empty to disable the feature.
  static const String clientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '',
  );

  /// Must match a Redirect URI registered in your Spotify dashboard.
  static const String redirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'twohearts://spotify-callback',
  );

  /// Scopes we need: control playback + read the currently playing track.
  static const String scope =
      'app-remote-control,user-modify-playback-state,'
      'user-read-playback-state,user-read-currently-playing,streaming';

  static bool get isConfigured => clientId.isNotEmpty;
}
