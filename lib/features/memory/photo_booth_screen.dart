import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';

// ── Photo Booth — collections grid ───────────────────────────────────────

class PhotoBoothScreen extends ConsumerWidget {
  const PhotoBoothScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final collectionsAsync = ref.watch(photoCollectionsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);

    // Count uncollected photos
    final uncollected = (memoriesAsync.valueOrNull ?? [])
        .where((m) => m.collectionId == null)
        .length;

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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text('Photo Booth 📸',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      icon: Icon(Icons.create_new_folder_outlined,
                          color: accent, size: 24),
                      onPressed: () =>
                          _createCollectionDialog(context, ref, accent),
                      tooltip: 'New Album',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: collectionsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.rose)),
                  error: (e, _) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(
                              color: AppColors.textSecondary))),
                  data: (collections) {
                    final tiles = <Widget>[
                      // "Uncollected" tile always first
                      if (uncollected > 0)
                        _CollectionTile(
                          name: 'All Photos',
                          photoCount: uncollected,
                          coverUrl: (memoriesAsync.valueOrNull ?? [])
                              .where((m) => m.collectionId == null)
                              .firstOrNull
                              ?.imageUrl,
                          accent: accent,
                          onTap: () => _openUncollected(
                              context, ref, accent),
                        ).animate().fadeIn(),

                      // User-created collections
                      ...collections.asMap().entries.map((e) =>
                          _CollectionTile(
                            name: e.value.name,
                            photoCount: e.value.photoCount,
                            coverUrl: e.value.coverUrl,
                            accent: accent,
                            onTap: () => _openCollection(
                                context, ref, e.value, accent),
                          ).animate().fadeIn(
                              delay: Duration(
                                  milliseconds: e.key * 60))),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Create an album to organise event photos ♡',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            GradientButton(
                              label: 'Create Album',
                              width: 200,
                              onTap: () => _createCollectionDialog(
                                  context, ref, accent),
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
          ),
        ),
      ),
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
            await ref.read(firestoreServiceProvider).createCollection(coupleId, name);
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
        builder: (_) => _CollectionScreen(
          collection: col,
          accent: accent,
          filterCollectionId: col.id,
        ),
      ),
    );
  }

  void _openUncollected(
      BuildContext context, WidgetRef ref, Color accent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CollectionScreen(
          collection: null,
          accent: accent,
          filterCollectionId: null,
        ),
      ),
    );
  }
}

// ── Collection tile ───────────────────────────────────────────────────────

class _CollectionTile extends StatelessWidget {
  final String name;
  final int photoCount;
  final String? coverUrl;
  final Color accent;
  final VoidCallback onTap;

  const _CollectionTile({
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
            // Cover image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
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
            // Info
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

// ── Collection detail screen ──────────────────────────────────────────────

class _CollectionScreen extends ConsumerStatefulWidget {
  final PhotoCollection? collection;
  final Color accent;
  final String? filterCollectionId;

  const _CollectionScreen({
    required this.collection,
    required this.accent,
    required this.filterCollectionId,
  });

  @override
  ConsumerState<_CollectionScreen> createState() =>
      _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<_CollectionScreen> {
  bool _uploading = false;

  Future<void> _addPhoto() async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    HapticFeedback.lightImpact();
    try {
      final bytes = await picked.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes,
          folder: 'photo_booth');
      final memory = MemoryModel(
        id: const Uuid().v4(),
        uploaderUid: uid,
        imageUrl: url,
        createdAt: DateTime.now(),
        collectionId: widget.filterCollectionId,
      );
      await ref.read(firestoreServiceProvider).addMemory(coupleId, memory);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final photos = (memoriesAsync.valueOrNull ?? []).where((m) {
      if (widget.filterCollectionId == null) {
        return m.collectionId == null;
      }
      return m.collectionId == widget.filterCollectionId;
    }).toList();

    final title =
        widget.collection?.name ?? 'All Photos';

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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                    ),
                    _uploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.rose))
                        : IconButton(
                            icon: Icon(Icons.add_photo_alternate_outlined,
                                color: widget.accent),
                            onPressed: _addPhoto,
                            tooltip: 'Add Photo',
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📷',
                                style: TextStyle(fontSize: 56)),
                            const SizedBox(height: 14),
                            Text('No photos yet',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 8),
                            Text('Tap + to add photos to this album',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: () =>
                              _showFull(context, photos[i]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: photos[i].imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  Container(color: AppColors.bgCard),
                              errorWidget: (_, _, _) => Container(
                                color: AppColors.bgCard,
                                child: const Center(
                                  child: Text('📷',
                                      style: TextStyle(
                                          fontSize: 20)),
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                            delay: Duration(
                                milliseconds: i * 30)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFull(BuildContext context, MemoryModel memory) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(
            children: [
              SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: memory.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              if (memory.caption != null)
                Positioned(
                  bottom: 48,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(memory.caption!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ),
                ),
              Positioned(
                top: 48,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
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
