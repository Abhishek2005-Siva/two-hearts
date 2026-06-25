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

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesProvider);
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
                          onTap: () => context.go('/memory/${memories[i].id}'),
                          onFavorite: () async {
                            final coupleId = ref.read(coupleIdProvider);
                            if (coupleId == null) return;
                            await ref.read(firestoreServiceProvider).toggleFavoriteMemory(
                                coupleId, memories[i].id, !memories[i].favorite);
                          },
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
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _MemoryCard({
    required this.memory,
    required this.accent,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: memory.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.bgCard,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))),
              errorWidget: (_, __, ___) => Container(color: AppColors.bgCard,
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
    );
  }
}
