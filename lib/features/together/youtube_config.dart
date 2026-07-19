/// YouTube Data API v3 credentials for in-app search on the Watch on
/// YouTube page.
///
/// SETUP (one-time, done by you):
///   1. Go to https://console.cloud.google.com/, create a project (or use
///      an existing one).
///   2. Enable the "YouTube Data API v3" for that project.
///   3. Create an API key (APIs & Services → Credentials → Create
///      Credentials → API key). Restrict it to the YouTube Data API v3.
///   4. Free tier is 10,000 quota units/day; a search costs 100 units, so
///      that's 100 searches/day — plenty for a two-person app.
///
/// Provide the key at build time:
///   flutter run --dart-define=YOUTUBE_API_KEY=xxxxxxxx
///
/// Until it's set, the search tab shows a friendly setup notice — pasting
/// a direct YouTube link to watch still always works regardless, since
/// that path needs no API key at all (it uses the embeddable iframe
/// player directly, not the Data API).
class YoutubeConfig {
  static const String apiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => apiKey.isNotEmpty;
}
