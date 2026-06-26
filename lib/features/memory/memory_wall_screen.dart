import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
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
      // I want to request deletion
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
      // I requested — offer to cancel
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
      // Partner requested — approve or reject
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
    final memoriesAsync = ref.watch(memoriesProvider);
    final accent = ref.watch(accentColorProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';

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
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: const Text('Memory Wall'),
                actions: [
                  _uploading
                      ? const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Center(child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))))
                      : IconButton(
                          icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textPrimary),
                          onPressed: _pickAndUpload,
                        ),
                ],
              ),
              memoriesAsync.when(
                loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: AppColors.rose))),
                error: (e, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.textSecondary)))),
                data: (memories) {
                  if (memories.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📸', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            const Text('Your memories will live here',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                            const SizedBox(height: 24),
                            GradientButton(
                              label: 'Add First Memory',
                              width: 200,
                              onTap: _pickAndUpload,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _MemoryCard(
                          memory: memories[i],
                          accent: accent,
                          myUid: myUid,
                          onTap: () => context.go('/memory/${memories[i].id}'),
                          onFavorite: () async {
                            if (coupleId.isEmpty) return;
                            await ref.read(firestoreServiceProvider).toggleFavoriteMemory(
                                coupleId, memories[i].id, !memories[i].favorite);
                          },
                          onLongPress: coupleId.isNotEmpty
                              ? () => _onLongPress(memories[i], myUid, coupleId)
                              : null,
                        ).animate().fadeIn(delay: Duration(milliseconds: i * 50)),
                        childCount: memories.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryModel memory;
  final Color accent;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onLongPress;

  const _MemoryCard({
    required this.memory,
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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: 'memory_${memory.id}',
        child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: memory.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.bgCard,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))),
              errorWidget: (context, url, error) => Container(color: AppColors.bgCard,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
            ),
            if (memory.caption != null)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Text(memory.caption!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            // Deletion request badge
            if (hasDeletionRequest)
              Positioned(
                bottom: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: partnerRequested
                        ? Colors.orange.withValues(alpha: 0.9)
                        : Colors.red.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    partnerRequested ? '🗑 Delete?' : '🗑 Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: onFavorite,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: Icon(
                    memory.favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: memory.favorite ? AppColors.rose : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ), // Hero
    );
  }
}
