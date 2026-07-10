import 'dart:convert';

import 'package:http/http.dart' as http;

/// Search + playback lookup against the Internet Archive's public API —
/// a free, legal library of public-domain and Creative Commons films, TV
/// and documentaries. No API key needed.
class ArchiveSearchService {
  ArchiveSearchService._();

  static Future<List<ArchiveItem>> search(String query) async {
    final uri = Uri.https('archive.org', '/advancedsearch.php', {
      'q': '$query AND mediatype:(movies)',
      'fl[]': ['identifier', 'title', 'year', 'description'],
      'rows': '25',
      'page': '1',
      'output': 'json',
      'sort[]': 'downloads desc',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Archive.org search failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['response']?['docs'] as List?) ?? [];
    return docs
        .map((d) => ArchiveItem.fromJson(d as Map<String, dynamic>))
        .where((i) => i.identifier.isNotEmpty)
        .toList();
  }

  /// Picks the best directly-playable video file for an item — prefers
  /// mp4 (video_player handles it reliably), falls back to webm, and
  /// otherwise returns null (the item only has formats we can't stream,
  /// e.g. ogv/mkv-only uploads, or just images/audio).
  static Future<String?> bestVideoUrl(String identifier) async {
    final res = await http
        .get(Uri.https('archive.org', '/metadata/$identifier'));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (body['files'] as List?) ?? [];

    Map<String, dynamic>? pick(String ext) {
      final matches = files
          .cast<Map<String, dynamic>>()
          .where((f) =>
              (f['name'] as String? ?? '').toLowerCase().endsWith(ext))
          .toList();
      if (matches.isEmpty) return null;
      matches.sort((a, b) {
        final sa = int.tryParse('${a['size']}') ?? 0;
        final sb = int.tryParse('${b['size']}') ?? 0;
        return sb.compareTo(sa);
      });
      return matches.first;
    }

    final file = pick('.mp4') ?? pick('.webm');
    if (file == null) return null;
    final name = file['name'] as String;
    return 'https://archive.org/download/$identifier/${Uri.encodeComponent(name)}';
  }
}

class ArchiveItem {
  final String identifier;
  final String title;
  final String? year;
  final String? description;

  ArchiveItem({
    required this.identifier,
    required this.title,
    this.year,
    this.description,
  });

  String get thumbnailUrl => 'https://archive.org/services/img/$identifier';

  factory ArchiveItem.fromJson(Map<String, dynamic> j) => ArchiveItem(
        identifier: j['identifier'] as String? ?? '',
        title: j['title'] as String? ?? 'Untitled',
        year: j['year']?.toString(),
        description: j['description'] is List
            ? (j['description'] as List).join(' ')
            : j['description'] as String?,
      );
}
