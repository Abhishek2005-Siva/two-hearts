import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/delight/couple_character.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/theme/app_theme.dart';
import 'youtube_config.dart';
import 'youtube_search_service.dart';

/// Search-and-watch YouTube page — deliberately not a curated channel
/// list. Specific "free TV channel" stream/video IDs (Pluto TV, Vevo's
/// genre channels, etc.) go stale and can't be verified from this
/// environment; the two things that are actually durable and legitimate
/// are the real YouTube Data API (for search, needs your own API key —
/// see youtube_config.dart) and YouTube's own official embeddable iframe
/// player (for playback, needs no key at all). Pasting a direct link
/// always works regardless of whether search is configured.
class YoutubeWatchScreen extends ConsumerStatefulWidget {
  const YoutubeWatchScreen({super.key});

  @override
  ConsumerState<YoutubeWatchScreen> createState() => _YoutubeWatchScreenState();
}

class _YoutubeWatchScreenState extends ConsumerState<YoutubeWatchScreen>
    with ActivityAnnouncer {
  final _searchCtrl = TextEditingController();
  late final YoutubePlayerController _player;
  bool _playerLoaded = false;
  String? _error;
  bool _searching = false;
  List<YoutubeSearchResult> _results = [];
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    announceActivity('Watching YouTube');
    _player = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _player.close();
    super.dispose();
  }

  Future<void> _playUrlOrQuery() async {
    final input = _searchCtrl.text.trim();
    if (input.isEmpty) return;
    final videoId = YoutubePlayerController.convertUrlToId(input);
    if (videoId != null && videoId.isNotEmpty) {
      // It's a direct link — just play it, no API key needed.
      await _playVideoId(videoId);
      return;
    }
    await _search(input);
  }

  Future<void> _search(String query) async {
    if (!YoutubeConfig.isConfigured) {
      setState(() => _error =
          "Search isn't set up yet (needs a YouTube API key) — paste a direct video link instead");
      return;
    }
    FocusScope.of(context).unfocus();
    final requestId = ++_searchRequestId;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await YoutubeSearchService.search(query);
      if (requestId != _searchRequestId || !mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) _error = 'No results for "$query"';
      });
    } catch (e) {
      if (requestId != _searchRequestId || !mounted) return;
      setState(() {
        _searching = false;
        _error = "Couldn't search: $e";
      });
    }
  }

  Future<void> _playVideoId(String videoId) async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _playerLoaded = true;
    });
    await _player.loadVideoById(videoId: videoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Watch on YouTube'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_playerLoaded) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: YoutubePlayer(controller: _player),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: CoupleCharacter(
                        character: CoupleCharacterId.combo, pose: 'idle', height: 46),
                    ),
                  ] else
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.bgCardLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.smart_display_outlined,
                              color: AppColors.textMuted, size: 40),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _playUrlOrQuery(),
                          decoration: InputDecoration(
                            hintText: 'Search YouTube, or paste a link…',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColors.bgCardLight,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SquishyTap(
                        onTap: _playUrlOrQuery,
                        style: TapAnimationStyle.bounce,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient:
                                const LinearGradient(colors: [AppColors.rose, AppColors.coral]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
                  ] else if (!YoutubeConfig.isConfigured) ...[
                    const SizedBox(height: 8),
                    const Text(
                      "Search needs a YouTube API key (see youtube_config.dart) — "
                      'pasting a direct link always works though.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SquishyTap(
                            onTap: () => _playVideoId(r.videoId),
                            style: TapAnimationStyle.pulse,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.bgCardLight,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: r.thumbnailUrl,
                                      width: 110,
                                      height: 62,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(r.channelTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppColors.textMuted, fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.play_circle_fill_rounded,
                                      color: AppColors.rose, size: 26),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
