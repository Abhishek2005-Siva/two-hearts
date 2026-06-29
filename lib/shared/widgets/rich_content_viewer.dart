import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/models/content_block.dart';

class RichContentViewer extends StatelessWidget {
  final List<ContentBlock> blocks;
  const RichContentViewer({super.key, required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((block) => _buildBlock(context, block)).toList(),
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    switch (block.type) {
      case BlockType.text:
        final fontSize = switch (block.textSize) {
          TextSize.small => 12.0,
          TextSize.body => 15.0,
          TextSize.heading => 20.0,
          TextSize.title => 26.0,
          null => 15.0,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(block.text ?? '', style: TextStyle(fontSize: fontSize)),
        );
      case BlockType.voice:
        return _VoicePlayerBlock(block: block);
      case BlockType.image:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: block.mediaUrl ?? '', fit: BoxFit.cover),
          ),
        );
      case BlockType.video:
        return _VideoBlock(block: block);
      case BlockType.link:
        return _LinkBlock(block: block);
    }
  }
}

class _VoicePlayerBlock extends StatefulWidget {
  final ContentBlock block;
  const _VoicePlayerBlock({required this.block});
  @override
  State<_VoicePlayerBlock> createState() => _VoicePlayerBlockState();
}

class _VoicePlayerBlockState extends State<_VoicePlayerBlock> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white12, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          onPressed: () async {
            if (_playing) {
              await _player.pause();
            } else {
              await _player.play(UrlSource(widget.block.mediaUrl ?? ''));
            }
          },
        ),
        Expanded(
            child: Slider(
          value: _pos.inSeconds.toDouble(),
          max: _total.inSeconds > 0 ? _total.inSeconds.toDouble() : 1,
          onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
        )),
        Text(_fmt(_total), style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _VideoBlock extends StatefulWidget {
  final ContentBlock block;
  const _VideoBlock({required this.block});
  @override
  State<_VideoBlock> createState() => _VideoBlockState();
}

class _VideoBlockState extends State<_VideoBlock> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.block.mediaUrl ?? ''))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_ctrl!.value.isPlaying) {
          _ctrl!.pause();
        } else {
          _ctrl!.play();
        }
        setState(() {});
      },
      child: AspectRatio(
        aspectRatio: _ctrl?.value.isInitialized == true ? _ctrl!.value.aspectRatio : 16 / 9,
        child: _ctrl?.value.isInitialized == true
            ? VideoPlayer(_ctrl!)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _LinkBlock extends StatelessWidget {
  final ContentBlock block;
  const _LinkBlock({required this.block});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(block.linkUrl ?? '')),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          const Icon(Icons.link, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.linkTitle != null)
                Text(block.linkTitle!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(block.linkUrl ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
            ],
          )),
        ]),
      ),
    );
  }
}
