import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class MemoryDetailScreen extends ConsumerWidget {
  final String memoryId;
  const MemoryDetailScreen({super.key, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';

    // While loading show spinner
    if (memoriesAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final memories = memoriesAsync.valueOrNull ?? [];
    final memory = memories.cast<dynamic>().firstWhere(
      (m) => m.id == memoryId,
      orElse: () => null,
    );

    // Memory was deleted — go back instead of blank screen
    if (memory == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasDeletion = memory.deletionRequestedBy != null;
    final iRequested = hasDeletion && memory.deletionRequestedBy == myUid;
    final partnerRequested = hasDeletion && memory.deletionRequestedBy != myUid;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'memory_${memory.id}',
            child: CachedNetworkImage(imageUrl: memory.imageUrl, fit: BoxFit.cover),
          ),
          if (memory.caption != null)
            Positioned(
              bottom: hasDeletion ? 108 : 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24, 24, 24,
                  hasDeletion ? 12 : MediaQuery.of(context).padding.bottom + 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  memory.caption!,
                  style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                ),
              ),
            ),

          // Deletion request banner
          if (hasDeletion)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                ),
                child: iRequested
                    ? _MyRequestBanner(
                        coupleId: coupleId,
                        memoryId: memory.id,
                        ref: ref,
                      )
                    : partnerRequested
                        ? _PartnerRequestBanner(
                            coupleId: coupleId,
                            memoryId: memory.id,
                            ref: ref,
                          )
                        : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyRequestBanner extends StatelessWidget {
  final String coupleId;
  final String memoryId;
  final WidgetRef ref;

  const _MyRequestBanner({
    required this.coupleId,
    required this.memoryId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('🗑', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Waiting for partner to approve deletion',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: () async {
            await ref.read(firestoreServiceProvider).cancelMemoryDeletion(coupleId, memoryId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

// No longer stores BuildContext as a field — gets it from build()
class _PartnerRequestBanner extends StatelessWidget {
  final String coupleId;
  final String memoryId;
  final WidgetRef ref;

  const _PartnerRequestBanner({
    required this.coupleId,
    required this.memoryId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🗑 Your partner wants to delete this',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await ref.read(firestoreServiceProvider).cancelMemoryDeletion(coupleId, memoryId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Keep It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await ref.read(firestoreServiceProvider).approveMemoryDeletion(coupleId, memoryId);
                  // Navigator.pop is called automatically when memory disappears and
                  // MemoryDetailScreen detects memory == null via addPostFrameCallback
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Delete It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
