import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';
import 'photo_booth_screen.dart';

class MemoryWallScreen extends ConsumerStatefulWidget {
  const MemoryWallScreen({super.key});

  @override
  ConsumerState<MemoryWallScreen> createState() => _MemoryWallScreenState();
}

class _MemoryWallScreenState extends ConsumerState<MemoryWallScreen>
    with SingleTickerProviderStateMixin {
  bool _uploading = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
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
    final accent = ref.watch(accentColorProvider);

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
                        onPressed: _pickAndUpload,
                      ),
                  ],
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: AppColors.textMuted,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Memories'),
                  Tab(text: 'Photo Booth'),
                ],
              ),
              const SizedBox(height: 4),
              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _MemoriesTab(
                      onLongPress: _onLongPress,
                      onUpload: _pickAndUpload,
                    ),
                    const _PhotoBoothTab(),
                  ],
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
            onTap: () => context.go('/memory/${memory.id}'),
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

// ── Photo Booth Tab ───────────────────────────────────────────────────────

class _PhotoBoothTab extends ConsumerWidget {
  const _PhotoBoothTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse PhotoBoothScreen's body by embedding its content
    // PhotoBoothScreen is a full Scaffold; we embed its content directly
    return const _PhotoBoothTabContent();
  }
}

class _PhotoBoothTabContent extends ConsumerWidget {
  const _PhotoBoothTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final collectionsAsync = ref.watch(photoCollectionsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);

    final uncollected = (memoriesAsync.valueOrNull ?? [])
        .where((m) => m.collectionId == null)
        .length;

    return Column(
      children: [
        // New album button row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: Icon(Icons.create_new_folder_outlined,
                    color: accent, size: 18),
                label: Text('New Album',
                    style: TextStyle(color: accent, fontSize: 13)),
                onPressed: () =>
                    _createCollectionDialog(context, ref, accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: collectionsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.rose)),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(
                        color: AppColors.textSecondary))),
            data: (collections) {
              final tiles = <Widget>[
                if (uncollected > 0)
                  _CollectionTileWidget(
                    name: 'All Photos',
                    photoCount: uncollected,
                    coverUrl: (memoriesAsync.valueOrNull ?? [])
                        .where((m) => m.collectionId == null)
                        .firstOrNull
                        ?.imageUrl,
                    accent: accent,
                    onTap: () =>
                        _openUncollected(context, ref, accent),
                  ).animate().fadeIn(),
                ...collections.asMap().entries.map((e) =>
                    _CollectionTileWidget(
                      name: e.value.name,
                      photoCount: e.value.photoCount,
                      coverUrl: e.value.coverUrl,
                      accent: accent,
                      onTap: () =>
                          _openCollection(context, ref, e.value, accent),
                    ).animate().fadeIn(
                        delay:
                            Duration(milliseconds: e.key * 60))),
              ];

              if (tiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📸',
                          style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No albums yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Create an album to organise event photos ♡',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        label: 'Create Album',
                        width: 200,
                        onTap: () =>
                            _createCollectionDialog(context, ref, accent),
                      ),
                    ],
                  ),
                );
              }

              return GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
                children: tiles,
              );
            },
          ),
        ),
      ],
    );
  }

  void _createCollectionDialog(
      BuildContext context, WidgetRef ref, Color accent) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Album',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Album name…',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          onSubmitted: (_) async {
            final name = ctrl.text.trim();
            if (name.isEmpty) return;
            final coupleId = ref.read(coupleIdProvider);
            if (coupleId == null) return;
            Navigator.pop(dialogCtx);
            await ref
                .read(firestoreServiceProvider)
                .createCollection(coupleId, name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final coupleId = ref.read(coupleIdProvider);
              if (coupleId == null) return;
              Navigator.pop(dialogCtx);
              await ref
                  .read(firestoreServiceProvider)
                  .createCollection(coupleId, name);
            },
            child: Text('Create', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  void _openCollection(BuildContext context, WidgetRef ref,
      PhotoCollection col, Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          child: _CollectionScreenWrapper(
            collection: col,
            accent: accent,
            filterCollectionId: col.id,
          ),
        ),
      ),
    );
  }

  void _openUncollected(BuildContext context, WidgetRef ref, Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          child: _CollectionScreenWrapper(
            collection: null,
            accent: accent,
            filterCollectionId: null,
          ),
        ),
      ),
    );
  }
}

// Thin wrapper so we can reuse PhotoBoothScreen's _CollectionScreen logic
// by opening the existing PhotoBoothScreen route instead
class _CollectionScreenWrapper extends StatelessWidget {
  final PhotoCollection? collection;
  final Color accent;
  final String? filterCollectionId;

  const _CollectionScreenWrapper({
    required this.collection,
    required this.accent,
    required this.filterCollectionId,
  });

  @override
  Widget build(BuildContext context) {
    // Navigate to the photo booth screen passing the collection
    // Since _CollectionScreen is private in photo_booth_screen.dart,
    // we push the PhotoBoothScreen and let users navigate from there.
    // For a better UX, open PhotoBoothScreen directly.
    return const PhotoBoothScreen();
  }
}

// ── Collection Tile Widget (local copy for tab) ───────────────────────────

class _CollectionTileWidget extends StatelessWidget {
  final String name;
  final int photoCount;
  final String? coverUrl;
  final Color accent;
  final VoidCallback onTap;

  const _CollectionTileWidget({
    required this.name,
    required this.photoCount,
    this.coverUrl,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.bgCard,
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, _) =>
                            Container(color: AppColors.bgCardLight),
                        errorWidget: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '$photoCount photo${photoCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.bgCardLight,
        child: const Center(
          child: Text('📷', style: TextStyle(fontSize: 32)),
        ),
      );
}
