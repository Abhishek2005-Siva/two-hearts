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
  // null = show all memories; non-null = filter to a specific collection
  String? _activeCollectionId;

  Future<void> _showAddMemorySheet() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final picker = ImagePicker();
    // Open native gallery directly — pickMultipleMedia allows selecting both
    // photos and videos in a single unified picker session.
    final media = await picker.pickMultipleMedia();
    if (media.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      for (final xfile in media) {
        final id = const Uuid().v4();
        final path = xfile.path.toLowerCase();
        final isVideo = path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv');
        if (isVideo) {
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
        } else {
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
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _onLongPress(MemoryModel memory, String myUid, String coupleId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Add to collection option
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: AppColors.textPrimary),
              title: const Text('Add to collection',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showAddToCollectionSheet(memory, coupleId);
              },
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Deletion options
            if (memory.deletionRequestedBy == null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Request deletion',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.bgCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Request Deletion',
                          style: TextStyle(color: AppColors.textPrimary)),
                      content: const Text(
                        'Ask your partner to approve deleting this memory. It will only be removed when they agree.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref
                                .read(firestoreServiceProvider)
                                .requestMemoryDeletion(coupleId, memory.id);
                          },
                          child: const Text('Request',
                              style: TextStyle(color: AppColors.rose)),
                        ),
                      ],
                    ),
                  );
                },
              )
            else if (memory.deletionRequestedBy == myUid)
              ListTile(
                leading: const Icon(Icons.undo_rounded,
                    color: AppColors.textSecondary),
                title: const Text('Cancel deletion request',
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(firestoreServiceProvider)
                      .cancelMemoryDeletion(coupleId, memory.id);
                },
              )
            else
              ListTile(
                leading:
                    const Icon(Icons.check_circle_outline, color: AppColors.rose),
                title: const Text('Partner wants to delete — tap to approve',
                    style: TextStyle(color: AppColors.rose)),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(firestoreServiceProvider)
                      .approveMemoryDeletion(coupleId, memory.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddToCollectionSheet(MemoryModel memory, String coupleId) {
    final collections =
        ref.read(photoCollectionsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddToCollectionSheet(
        memory: memory,
        coupleId: coupleId,
        collections: collections,
        onAssign: (collectionId) async {
          await ref
              .read(firestoreServiceProvider)
              .assignToCollection(coupleId, memory.id, collectionId);
        },
        onCreateNew: (name) async {
          final col = await ref
              .read(firestoreServiceProvider)
              .createCollection(coupleId, name);
          await ref
              .read(firestoreServiceProvider)
              .assignToCollection(coupleId, memory.id, col.id);
        },
      ),
    );
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
              _CollectionsRow(
                activeCollectionId: _activeCollectionId,
                onSelect: (id) => setState(() => _activeCollectionId = id),
              ),
              Expanded(
                child: _MemoriesTab(
                  onLongPress: _onLongPress,
                  onUpload: _showAddMemorySheet,
                  activeCollectionId: _activeCollectionId,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Collections Row ───────────────────────────────────────────────────────

class _CollectionsRow extends ConsumerWidget {
  final String? activeCollectionId;
  final void Function(String?) onSelect;

  const _CollectionsRow({
    required this.activeCollectionId,
    required this.onSelect,
  });

  // Deterministic color from collection name hash
  Color _collectionColor(String name) {
    const palette = [
      Color(0xFFE57373), Color(0xFF81C784), Color(0xFF64B5F6),
      Color(0xFFFFB74D), Color(0xFFBA68C8), Color(0xFF4DB6AC),
      Color(0xFFF06292), Color(0xFFAED581),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(photoCollectionsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);
    final coupleId = ref.watch(coupleIdProvider);
    final accent = ref.watch(accentColorProvider);
    final collections = collectionsAsync.valueOrNull ?? [];
    final memories = memoriesAsync.valueOrNull ?? [];

    // Count memories per collection
    Map<String, int> counts = {};
    for (final m in memories) {
      if (m.collectionId != null) {
        counts[m.collectionId!] = (counts[m.collectionId!] ?? 0) + 1;
      }
    }

    if (collections.isEmpty && activeCollectionId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            children: [
              Text('Collections',
                  style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              if (activeCollectionId != null)
                GestureDetector(
                  onTap: () => onSelect(null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded,
                            size: 11, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('All',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ...collections.map((col) {
                final isActive = activeCollectionId == col.id;
                final color = _collectionColor(col.name);
                final count = counts[col.id] ?? 0;
                return GestureDetector(
                  onTap: () => onSelect(isActive ? null : col.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    margin: const EdgeInsets.only(right: 10, bottom: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? color.withValues(alpha: 0.25)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive ? color : AppColors.divider,
                        width: isActive ? 1.5 : 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.folder_rounded,
                            color: color, size: 22),
                        const Spacer(),
                        Text(
                          col.name,
                          style: TextStyle(
                            color: isActive
                                ? color
                                : AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('$count',
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }),
              // + New collection card
              GestureDetector(
                onTap: coupleId == null
                    ? null
                    : () => _showNewCollectionDialog(
                        context, ref, coupleId, accent),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.divider, width: 0.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded,
                          color: accent, size: 22),
                      const SizedBox(height: 4),
                      Text('New',
                          style: TextStyle(
                              color: accent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  void _showNewCollectionDialog(
      BuildContext context, WidgetRef ref, String coupleId, Color accent) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Collection',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Collection name…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.rose)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Create',
                style: TextStyle(
                    color: accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((name) {
      ctrl.dispose();
      if (name != null && (name as String).isNotEmpty) {
        ref
            .read(firestoreServiceProvider)
            .createCollection(coupleId, name)
            .ignore();
      }
    });
  }
}

// ── Add to Collection Sheet ───────────────────────────────────────────────

class _AddToCollectionSheet extends ConsumerWidget {
  final MemoryModel memory;
  final String coupleId;
  final List<PhotoCollection> collections;
  final Future<void> Function(String collectionId) onAssign;
  final Future<void> Function(String name) onCreateNew;

  const _AddToCollectionSheet({
    required this.memory,
    required this.coupleId,
    required this.collections,
    required this.onAssign,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Add to Collection',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (collections.isEmpty)
            const Text('No collections yet.',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: collections.length,
                separatorBuilder: (_, sep) =>
                    const Divider(color: AppColors.divider, height: 1),
                itemBuilder: (ctx, i) {
                  final col = collections[i];
                  final isCurrent = memory.collectionId == col.id;
                  return ListTile(
                    leading: Icon(Icons.folder_rounded,
                        color: accent),
                    title: Text(col.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary)),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle_rounded,
                            color: accent, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onAssign(col.id);
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _showNewCollectionAndAssign(context, ref, accent);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                    color: accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text('New collection',
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewCollectionAndAssign(
      BuildContext context, WidgetRef ref, Color accent) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('New Collection',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Collection name…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.rose)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text('Create',
                style: TextStyle(
                    color: accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((name) {
      ctrl.dispose();
      if (name != null && (name as String).isNotEmpty) {
        onCreateNew(name);
      }
    });
  }
}

// ── Memories Tab — masonry grid ───────────────────────────────────────────

class _MemoriesTab extends ConsumerWidget {
  final void Function(MemoryModel, String, String) onLongPress;
  final VoidCallback onUpload;
  final String? activeCollectionId;

  const _MemoriesTab({
    required this.onLongPress,
    required this.onUpload,
    this.activeCollectionId,
  });


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
      data: (allMemories) {
        // Filter by active collection if one is selected
        final memories = activeCollectionId == null
            ? allMemories
            : allMemories
                .where((m) => m.collectionId == activeCollectionId)
                .toList();

        if (allMemories.isEmpty) {
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

        if (memories.isEmpty) {
          return const Center(
            child: Text('No memories in this collection yet.',
                style: TextStyle(color: AppColors.textSecondary)),
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

  static String _videoThumb(String videoUrl) {
    if (videoUrl.contains('cloudinary.com')) {
      return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
    }
    return videoUrl;
  }

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
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _MasonryCard._videoThumb(memory.imageUrl),
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) =>
                            Container(color: Colors.black87),
                        errorWidget: (ctx, url, err) =>
                            Container(color: Colors.black87),
                      ),
                      const Center(
                        child: Icon(Icons.play_circle_outline,
                            color: Colors.white, size: 48),
                      ),
                    ],
                  )
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
