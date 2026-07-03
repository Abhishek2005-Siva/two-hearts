import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/models/content_block.dart';
import '../../core/utils/cloudinary_service.dart';

class RichContentEditor extends StatefulWidget {
  final List<ContentBlock> initialBlocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final Color textColor;
  final Color hintColor;

  const RichContentEditor({
    super.key,
    required this.initialBlocks,
    required this.onChanged,
    this.textColor = Colors.white,
    this.hintColor = Colors.white38,
  });

  @override
  State<RichContentEditor> createState() => _RichContentEditorState();
}

class _RichContentEditorState extends State<RichContentEditor> {
  late List<ContentBlock> _blocks;
  // map block id -> TextEditingController for text blocks
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.initialBlocks);
    if (_blocks.isEmpty) _blocks.add(ContentBlock.newText());
    for (final b in _blocks) {
      if (b.type == BlockType.text) {
        _controllers[b.id] = TextEditingController(text: b.text ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    // Sync text controllers back to blocks before notifying
    _blocks = _blocks.map((b) {
      if (b.type == BlockType.text && _controllers.containsKey(b.id)) {
        return b.copyWith(text: _controllers[b.id]!.text);
      }
      return b;
    }).toList();
    widget.onChanged(List.from(_blocks));
  }

  void _addBlock(ContentBlock block) {
    setState(() {
      _blocks.add(block);
      if (block.type == BlockType.text) {
        _controllers[block.id] = TextEditingController(text: block.text ?? '');
      }
    });
    _notify();
  }

  void _removeBlock(String id) {
    setState(() {
      _blocks.removeWhere((b) => b.id == id);
      _controllers.remove(id)?.dispose();
    });
    _notify();
  }

  void _updateBlock(ContentBlock updated) {
    setState(() {
      final idx = _blocks.indexWhere((b) => b.id == updated.id);
      if (idx >= 0) _blocks[idx] = updated;
    });
    _notify();
  }

  // ── Add text block ──────────────────────────────────────────────────────

  void _addTextBlock({TextSize size = TextSize.body}) {
    final block = ContentBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.text,
      text: '',
      textSize: size,
    );
    _addBlock(block);
  }

  // ── Add image / video ────────────────────────────────────────────────────

  Future<void> _addImageBlock() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    // Add placeholder block first
    final placeholder = ContentBlock(
      id: id,
      type: BlockType.image,
      mediaUrl: null,
    );
    _addBlock(placeholder);
    try {
      final bytes = await xf.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes);
      _updateBlock(placeholder.copyWith(mediaUrl: url));
    } catch (e) {
      _removeBlock(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    }
  }

  Future<void> _addVideoBlock() async {
    final picker = ImagePicker();
    final xf = await picker.pickVideo(source: ImageSource.gallery);
    if (xf == null) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final placeholder = ContentBlock(
      id: id,
      type: BlockType.video,
      mediaUrl: null,
    );
    _addBlock(placeholder);
    try {
      final url = await CloudinaryService.uploadVideo(File(xf.path));
      _updateBlock(placeholder.copyWith(mediaUrl: url));
    } catch (e) {
      _removeBlock(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video upload failed: $e')),
        );
      }
    }
  }

  // ── Add link ─────────────────────────────────────────────────────────────

  Future<void> _addLinkBlock() async {
    final urlCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C0F18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Link',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Link title (optional)',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
    urlCtrl.dispose();
    titleCtrl.dispose();
    if (result != true || urlCtrl.text.trim().isEmpty) return;
    _addBlock(ContentBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.link,
      linkUrl: urlCtrl.text.trim(),
      linkTitle: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
    ));
  }

  // ── Voice recording ───────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    // Show recording UI via bottom sheet
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _VoiceRecorderSheet(
        onComplete: (filePath, duration) async {
          final placeholder = ContentBlock(
            id: id,
            type: BlockType.voice,
            mediaUrl: null,
            durationSeconds: duration,
          );
          _addBlock(placeholder);
          try {
            final url = await CloudinaryService.uploadAudio(File(filePath));
            _updateBlock(placeholder.copyWith(mediaUrl: url));
          } catch (e) {
            _removeBlock(id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Audio upload failed: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._blocks.map((b) => _buildBlock(b)),
        const SizedBox(height: 8),
        _BlockToolbar(
          onAddText: () => _addTextBlock(),
          onAddHeading: () => _addTextBlock(size: TextSize.heading),
          onAddVoice: _startVoiceRecording,
          onAddImage: _addImageBlock,
          onAddVideo: _addVideoBlock,
          onAddLink: _addLinkBlock,
        ),
      ],
    );
  }

  Widget _buildBlock(ContentBlock block) {
    switch (block.type) {
      case BlockType.text:
        return _TextBlockEditor(
          key: ValueKey(block.id),
          block: block,
          controller: _controllers[block.id]!,
          textColor: widget.textColor,
          hintColor: widget.hintColor,
          onChanged: () => _notify(),
          onDelete: () => _removeBlock(block.id),
          onSizeChanged: (size) => _updateBlock(block.copyWith(textSize: size)),
        );
      case BlockType.voice:
        return _VoiceBlockEditor(
          key: ValueKey(block.id),
          block: block,
          onDelete: () => _removeBlock(block.id),
        );
      case BlockType.image:
        return _ImageBlockEditor(
          key: ValueKey(block.id),
          block: block,
          onDelete: () => _removeBlock(block.id),
        );
      case BlockType.video:
        return _VideoBlockEditor(
          key: ValueKey(block.id),
          block: block,
          onDelete: () => _removeBlock(block.id),
        );
      case BlockType.link:
        return _LinkBlockEditor(
          key: ValueKey(block.id),
          block: block,
          onDelete: () => _removeBlock(block.id),
        );
    }
  }
}

// ── Text block editor ─────────────────────────────────────────────────────

class _TextBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final TextEditingController controller;
  final Color textColor;
  final Color hintColor;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final ValueChanged<TextSize> onSizeChanged;

  const _TextBlockEditor({
    super.key,
    required this.block,
    required this.controller,
    this.textColor = Colors.white,
    this.hintColor = Colors.white38,
    required this.onChanged,
    required this.onDelete,
    required this.onSizeChanged,
  });

  double get _fontSize {
    switch (block.textSize ?? TextSize.body) {
      case TextSize.small:   return 12;
      case TextSize.body:    return 15;
      case TextSize.heading: return 20;
      case TextSize.title:   return 26;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showSizeMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: TextField(
          controller: controller,
          maxLines: null,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) {
            // backspace at start of empty block deletes it
          },
          style: TextStyle(
            color: textColor,
            fontSize: _fontSize,
            height: 1.6,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            hintText: _hintText,
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: _fontSize,
            ),
          ),
        ),
      ),
    );
  }

  String get _hintText {
    switch (block.textSize ?? TextSize.body) {
      case TextSize.title:   return 'Title…';
      case TextSize.heading: return 'Heading…';
      case TextSize.small:   return 'Small text…';
      case TextSize.body:    return 'Write something…';
    }
  }

  void _showSizeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C0F18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Text Size',
                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SizeButton(label: 'S', size: TextSize.small, current: block.textSize, onTap: (s) { Navigator.pop(context); onSizeChanged(s); }),
                _SizeButton(label: 'B', size: TextSize.body, current: block.textSize, onTap: (s) { Navigator.pop(context); onSizeChanged(s); }),
                _SizeButton(label: 'H', size: TextSize.heading, current: block.textSize, onTap: (s) { Navigator.pop(context); onSizeChanged(s); }),
                _SizeButton(label: 'T', size: TextSize.title, current: block.textSize, onTap: (s) { Navigator.pop(context); onSizeChanged(s); }),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(context); onDelete(); },
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text('Remove block', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  final String label;
  final TextSize size;
  final TextSize? current;
  final ValueChanged<TextSize> onTap;

  const _SizeButton({
    required this.label,
    required this.size,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == size;
    return GestureDetector(
      onTap: () => onTap(size),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected ? Colors.pinkAccent.withValues(alpha: 0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.pinkAccent : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.pinkAccent : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )),
      ),
    );
  }
}

// ── Voice block editor ────────────────────────────────────────────────────

class _VoiceBlockEditor extends StatefulWidget {
  final ContentBlock block;
  final VoidCallback onDelete;

  const _VoiceBlockEditor({super.key, required this.block, required this.onDelete});

  @override
  State<_VoiceBlockEditor> createState() => _VoiceBlockEditorState();
}

class _VoiceBlockEditorState extends State<_VoiceBlockEditor> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
    } else {
      final url = widget.block.mediaUrl;
      if (url == null) return;
      await _player.play(UrlSource(url));
      setState(() => _playing = true);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = widget.block.mediaUrl == null;
    final dur = widget.block.durationSeconds ?? 0;
    final minutes = dur ~/ 60;
    final seconds = (dur % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_rounded, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: uploading
                ? Row(children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pinkAccent),
                    ),
                    const SizedBox(width: 8),
                    const Text('Uploading…', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ])
                : Row(children: [
                    Text('Voice note', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('$minutes:$seconds',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
          ),
          if (!uploading)
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.pinkAccent,
                  size: 18,
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onDelete,
            child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Image block editor ────────────────────────────────────────────────────

class _ImageBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final VoidCallback onDelete;

  const _ImageBlockEditor({super.key, required this.block, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: block.mediaUrl == null
                ? Container(
                    height: 150,
                    color: Colors.white10,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.pinkAccent,
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: block.mediaUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: Colors.white10,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video block editor ────────────────────────────────────────────────────

class _VideoBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final VoidCallback onDelete;

  const _VideoBlockEditor({super.key, required this.block, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 160,
              color: Colors.black87,
              child: block.mediaUrl == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.pinkAccent),
                    )
                  : const Center(
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: Colors.white70, size: 48),
                    ),
            ),
          ),
          if (block.mediaUrl != null)
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.videocam_rounded,
                    color: Colors.white30, size: 28),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Link block editor ─────────────────────────────────────────────────────

class _LinkBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final VoidCallback onDelete;

  const _LinkBlockEditor({super.key, required this.block, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: Colors.pinkAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.linkTitle ?? block.linkUrl ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (block.linkTitle != null && block.linkUrl != null)
                  Text(
                    block.linkUrl!,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Block toolbar ─────────────────────────────────────────────────────────

class _BlockToolbar extends StatelessWidget {
  final VoidCallback onAddText;
  final VoidCallback onAddHeading;
  final VoidCallback onAddVoice;
  final VoidCallback onAddImage;
  final VoidCallback onAddVideo;
  final VoidCallback onAddLink;

  const _BlockToolbar({
    required this.onAddText,
    required this.onAddHeading,
    required this.onAddVoice,
    required this.onAddImage,
    required this.onAddVideo,
    required this.onAddLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolBtn(label: 'T', tooltip: 'Text', onTap: onAddText),
            const SizedBox(width: 4),
            _ToolBtn(label: 'H', tooltip: 'Heading', onTap: onAddHeading),
            const SizedBox(width: 4),
            _ToolBtn(icon: Icons.mic_rounded, tooltip: 'Voice', onTap: onAddVoice),
            const SizedBox(width: 4),
            _ToolBtn(icon: Icons.photo_rounded, tooltip: 'Image', onTap: onAddImage),
            const SizedBox(width: 4),
            _ToolBtn(icon: Icons.videocam_rounded, tooltip: 'Video', onTap: onAddVideo),
            const SizedBox(width: 4),
            _ToolBtn(icon: Icons.link_rounded, tooltip: 'Link', onTap: onAddLink),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolBtn({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 18)
              : Text(label ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
        ),
      ),
    );
  }
}

// ── Voice recorder bottom sheet ───────────────────────────────────────────

class _VoiceRecorderSheet extends StatefulWidget {
  final void Function(String filePath, int durationSeconds) onComplete;

  const _VoiceRecorderSheet({required this.onComplete});

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final _recorder = FlutterSoundRecorder();

  int _elapsed = 0;
  Timer? _timer;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _recorder.openRecorder().then((_) => _startRecording());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
    _filePath = path;
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _recorder.stopRecorder();
    if (_filePath != null && mounted) {
      widget.onComplete(_filePath!, _elapsed);
      Navigator.pop(context);
    }
  }

  void _cancel() async {
    _timer?.cancel();
    await _recorder.stopRecorder();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed ~/ 60;
    final seconds = (_elapsed % 60).toString().padLeft(2, '0');

    return Container(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24, MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C0F18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Pulsing mic icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.pinkAccent, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Recording…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _cancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Stop',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
