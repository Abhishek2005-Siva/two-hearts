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
    if (coupleId == null) return;
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final id = const Uuid().v4();
      final bytes = await xfile.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes, folder: 'two_hearts/$coupleId');
      await ref.read(firestoreServiceProvider).addMemory(
        coupleId,
        MemoryModel(
          id: id,
          uploaderUid: uid,
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
      appBar: AppBar(
        title: const Text('Memory Wall'),
        actions: [
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _pickAndUpload,
            ),
        ],
      ),
      body: memoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (memories) {
          if (memories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined, size: 64, color: AppColors.warmGray),
                  const SizedBox(height: 12),
                  Text('Start adding memories ♡', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add First Memory'),
                  ),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: memories.length,
            itemBuilder: (context, i) => _MemoryCard(
              memory: memories[i],
              accent: accent,
              onTap: () => context.go('/memory/${memories[i].id}'),
              onFavorite: () async {
                final coupleId = ref.read(coupleIdProvider)!;
                await ref.read(firestoreServiceProvider).toggleFavoriteMemory(
                  coupleId, memories[i].id, !memories[i].favorite,
                );
              },
            ).animate().fadeIn(delay: Duration(milliseconds: i * 60)),
          );
        },
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
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: memory.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.softPeach,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
            if (memory.caption != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    memory.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onFavorite,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    memory.favorite ? Icons.favorite : Icons.favorite_border,
                    color: memory.favorite ? Colors.red : Colors.white,
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
