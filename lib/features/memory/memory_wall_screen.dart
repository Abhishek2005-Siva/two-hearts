import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

class MemoryWallScreen extends ConsumerStatefulWidget {
  const MemoryWallScreen({super.key});

  @override
  ConsumerState<MemoryWallScreen> createState() => _MemoryWallScreenState();
}

class _MemoryWallScreenState extends ConsumerState<MemoryWallScreen> {
  bool _uploading = false;

  Future<void> _showAddMemorySheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('📷', style: TextStyle(fontSize: 24)),
              title: const Text('Photos',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos();
              },
            ),
            ListTile(
              leading: const Text('🎥', style: TextStyle(fontSize: 24)),
              title: const Text('Videos',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final xfile in images) {
        final id = const Uuid().v4();
        final bytes = await xfile.readAsBytes();
        final url = await CloudinaryService.uploadImage(bytes, folder: 'two_hearts/$coupleId');
        await ref.read(firestoreServiceProvider).addMemory(
          coupleId,
          MemoryModel(
            id: id,
            uploaderUid: authUser.uid,
            imageUrl: url,
            createdAt: DateTime.now(),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickVideo() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final id = const Uuid().v4();
      final url = await CloudinaryService.uploadVideo(
        File(xfile.path),
        folder: 'two_hearts/$coupleId',
      );
      await ref.read(firestoreServiceProvider).addMemory(
        coupleId,
        MemoryModel(
          id: id,
          uploaderUid: authUser.uid,
          imageUrl: url,
          createdAt: DateTime.now(),
          isVideo: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onLongPress(MemoryModel memory, String myUid, String coupleId) {
    if (memory.deletionRequestedBy == null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Request Deletion', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Ask your partner to approve deleting this memory. It will only be removed when they agree.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(firestoreServiceProvider)
                    .requestMemoryDeletion(coupleId, memory.id);
              },
              child: const Text('Request', style: TextStyle(color: AppColors.rose)),
            ),
          ],
        ),
      );
    } else if (memory.deletionRequestedBy == myUid) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cancel Request?', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'This will withdraw your deletion request.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(firestoreServiceProvider)
                    .cancelMemoryDeletion(coupleId, memory.id);
              },
              child: const Text('Cancel Request', style: TextStyle(color: AppColors.rose)),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Partner Wants to Delete', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Your partner has requested to delete this memory. Do you agree?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(firestoreServiceProvider)
                    .cancelMemoryDeletion(coupleId, memory.id);
              },
              child: const Text('Reject', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(firestoreServiceProvider)
                    .approveMemoryDeletion(coupleId, memory.id);
              },
              child: const Text('Delete It', style: TextStyle(color: AppColors.rose)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.bgGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar row
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Memories',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (_uploading)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.rose)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.textPrimary),
                        onPressed: _showAddMemorySheet,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _MemoriesTab(
                  onLongPress: _onLongPress,
                  onUpload: _showAddMemorySheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Memories Tab — masonry grid ───────────────────────────────────────────

class _MemoriesTab extends ConsumerWidget {
  final void Function(MemoryModel, String, String) onLongPress;
  final VoidCallback onUpload;

  const _MemoriesTab({required this.onLongPress, required this.onUpload});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final accent = ref.watch(accentColorProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';

    return memoriesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.rose)),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.textSecondary))),
      data: (memories) {
        if (memories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📸', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('Your memories will live here',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Add First Memory',
                  width: 200,
                  onTap: onUpload,
                ),
              ],
            ),
          );
        }

        // Two-column masonry: split memories into left and right columns
        final leftItems = <MemoryModel>[];
        final rightItems = <MemoryModel>[];
        for (var i = 0; i < memories.length; i++) {
          if (i.isEven) {
            leftItems.add(memories[i]);
          } else {
            rightItems.add(memories[i]);
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MasonryColumn(
                  items: leftItems,
                  startIndex: 0,
                  stepIndex: 2,
                  allItems: memories,
                  accent: accent,
                  myUid: myUid,
                  coupleId: coupleId,
                  onLongPress: onLongPress,
                  ref: ref,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MasonryColumn(
                  items: rightItems,
                  startIndex: 1,
                  stepIndex: 2,
                  allItems: memories,
                  accent: accent,
                  myUid: myUid,
                  coupleId: coupleId,
                  onLongPress: onLongPress,
                  ref: ref,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MasonryColumn extends StatelessWidget {
  final List<MemoryModel> items;
  final int startIndex;
  final int stepIndex;
  final List<MemoryModel> allItems;
  final Color accent;
  final String myUid;
  final String coupleId;
  final void Function(MemoryModel, String, String) onLongPress;
  final WidgetRef ref;

  const _MasonryColumn({
    required this.items,
    required this.startIndex,
    required this.stepIndex,
    required this.allItems,
    required this.accent,
    required this.myUid,
    required this.coupleId,
    required this.onLongPress,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final localIndex = entry.key;
        final memory = entry.value;
        final globalIndex = startIndex + localIndex * stepIndex;
        // Alternate aspect ratios: tall (1.4 height factor) and short (0.8)
        final isTall = localIndex.isEven;
        final aspectRatio = isTall ? 0.72 : 1.25; // width/height
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MasonryCard(
            memory: memory,
            aspectRatio: aspectRatio,
            accent: accent,
            myUid: myUid,
            onTap: () {
              if (memory.isVideo) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => _FullscreenVideoPlayer(url: memory.imageUrl),
                ));
              } else {
                context.go('/memory/${memory.id}');
              }
            },
            onFavorite: () async {
              if (coupleId.isEmpty) return;
              await ref.read(firestoreServiceProvider).toggleFavoriteMemory(
                  coupleId, memory.id, !memory.favorite);
            },
            onLongPress: coupleId.isNotEmpty
                ? () => onLongPress(memory, myUid, coupleId)
                : null,
          ).animate().fadeIn(delay: Duration(milliseconds: globalIndex * 50)),
        );
      }).toList(),
    );
  }
}

class _MasonryCard extends StatelessWidget {
  final MemoryModel memory;
  final double aspectRatio;
  final Color accent;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onLongPress;

  const _MasonryCard({
    required this.memory,
    required this.aspectRatio,
    required this.accent,
    required this.myUid,
    required this.onTap,
    required this.onFavorite,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasDeletionRequest = memory.deletionRequestedBy != null;
    final partnerRequested = hasDeletionRequest && memory.deletionRequestedBy != myUid;
    final dateStr = DateFormat('MMM d, yyyy').format(memory.createdAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: 'memory_${memory.id}',
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (memory.isVideo)
                  Container(color: Colors.black87,
                      child: const Center(
                          child: Icon(Icons.play_circle_outline,
                              color: Colors.white70, size: 48)))
                else
                  CachedNetworkImage(
                    imageUrl: memory.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        color: AppColors.bgCard,
                        child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.rose))),
                    errorWidget: (context, url, error) => Container(
                        color: AppColors.bgCard,
                        child: const Icon(Icons.broken_image_outlined,
                            color: AppColors.textMuted)),
                  ),
                // Bottom gradient overlay
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (memory.caption != null)
                          Text(memory.caption!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        Text(dateStr,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                // Deletion badge
                if (hasDeletionRequest)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: partnerRequested
                            ? Colors.orange.withValues(alpha: 0.9)
                            : Colors.red.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        partnerRequested ? '🗑 Delete?' : '🗑 Pending',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Favorite button
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.black38, shape: BoxShape.circle),
                      child: Icon(
                        memory.favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: memory.favorite ? AppColors.rose : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fullscreen Video Player ───────────────────────────────────────────────

class _FullscreenVideoPlayer extends StatefulWidget {
  final String url;
  const _FullscreenVideoPlayer({required this.url});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                  });
                },
                child: AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),
              )
            : const CircularProgressIndicator(color: AppColors.rose),
      ),
    );
  }
}
