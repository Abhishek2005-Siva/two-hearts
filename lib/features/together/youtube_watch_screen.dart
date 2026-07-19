import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/presence/activity_announcer.dart';
import '../../core/theme/app_theme.dart';

/// Paste-and-watch YouTube page — deliberately not a curated channel list.
/// Specific "free TV channel" stream/video IDs (Pluto TV, Vevo's genre
/// channels, etc.) go stale and can't be verified from this environment;
/// the one thing that's actually durable and legitimate is YouTube's own
/// official embeddable iframe player, which plays whatever public URL you
/// give it — a Vevo channel's live stream, any public video, anything.
class YoutubeWatchScreen extends ConsumerStatefulWidget {
  const YoutubeWatchScreen({super.key});

  @override
  ConsumerState<YoutubeWatchScreen> createState() => _YoutubeWatchScreenState();
}

class _YoutubeWatchScreenState extends ConsumerState<YoutubeWatchScreen>
    with ActivityAnnouncer {
  final _urlCtrl = TextEditingController();
  late final YoutubePlayerController _player;
  bool _loaded = false;
  String? _error;

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
    _urlCtrl.dispose();
    _player.close();
    super.dispose();
  }

  Future<void> _play() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final videoId = YoutubePlayerController.convertUrlToId(url);
    if (videoId == null || videoId.isEmpty) {
      setState(() => _error = "That doesn't look like a YouTube link");
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      _loaded = true;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste any public YouTube link — a live channel, a video, '
                'a Vevo/Trace stream — and watch it here.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _play(),
                      decoration: InputDecoration(
                        hintText: 'Paste a YouTube link…',
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
                    onTap: _play,
                    style: TapAnimationStyle.bounce,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.rose, AppColors.coral]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              if (_loaded)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(controller: _player),
                  ),
                )
              else
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
            ],
          ),
        ),
      ),
    );
  }
}
