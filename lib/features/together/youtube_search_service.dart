import 'dart:convert';
import 'package:http/http.dart' as http;
import 'youtube_config.dart';

class YoutubeSearchResult {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  const YoutubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });
}

class YoutubeSearchService {
  static const _base = 'https://www.googleapis.com/youtube/v3/search';

  /// Real results only — throws on any API error rather than returning a
  /// fabricated/empty-looking success, so the UI can show what actually
  /// went wrong (bad key, quota exceeded, etc.) instead of silently
  /// showing "no results" for a broken key.
  static Future<List<YoutubeSearchResult>> search(String query) async {
    if (!YoutubeConfig.isConfigured) {
      throw StateError('YouTube search is not configured (missing API key).');
    }
    final uri = Uri.parse(_base).replace(queryParameters: {
      'part': 'snippet',
      'q': query,
      'type': 'video',
      'maxResults': '15',
      'key': YoutubeConfig.apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final message = body?['error']?['message'] as String? ?? 'HTTP ${res.statusCode}';
      throw Exception('YouTube search failed: $message');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? const [];
    return items.map((raw) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as Map<String, dynamic>;
      final snippet = item['snippet'] as Map<String, dynamic>;
      final thumbs = snippet['thumbnails'] as Map<String, dynamic>;
      final thumb = (thumbs['medium'] ?? thumbs['default']) as Map<String, dynamic>;
      return YoutubeSearchResult(
        videoId: id['videoId'] as String? ?? '',
        title: snippet['title'] as String? ?? '',
        channelTitle: snippet['channelTitle'] as String? ?? '',
        thumbnailUrl: thumb['url'] as String? ?? '',
      );
    }).where((r) => r.videoId.isNotEmpty).toList();
  }
}
