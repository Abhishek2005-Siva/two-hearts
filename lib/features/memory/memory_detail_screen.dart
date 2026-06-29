import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String memoryId;
  const MemoryDetailScreen({super.key, required this.memoryId});

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  late PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';

    if (memoriesAsync.isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final memories = memoriesAsync.valueOrNull ?? [];

    if (memories.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    // Find initial page on first build
    final initialIndex = memories.indexWhere((m) => m.id == widget.memoryId);
    if (initialIndex != -1 && _pageCtrl.positions.isEmpty) {
      _currentIndex = initialIndex;
      _pageCtrl = PageController(initialPage: initialIndex);
    }

    // Clamp current index
    final safeIndex = _currentIndex.clamp(0, memories.length - 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable fullscreen photos
          PageView.builder(
            controller: _pageCtrl,
            itemCount: memories.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (ctx, i) {
              final memory = memories[i];
              final hasDeletion = memory.deletionRequestedBy != null;
              final iRequested =
                  hasDeletion && memory.deletionRequestedBy == myUid;
              final partnerRequested =
                  hasDeletion && memory.deletionRequestedBy != myUid;

              return GestureDetector(
                onTapUp: (details) {
                  final width = MediaQuery.of(context).size.width;
                  if (details.localPosition.dx < width / 2) {
                    _pageCtrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  } else {
                    _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                  // Full-screen image with pinch-zoom
                  InteractiveViewer(
                    child: Hero(
                      tag: 'memory_${memory.id}',
                      child: CachedNetworkImage(
                        imageUrl: memory.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(color: Colors.black),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white54, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Caption gradient + text
                  if (memory.caption != null)
                    Positioned(
                      bottom: hasDeletion ? 108 : 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          40,
                          24,
                          hasDeletion
                              ? 12
                              : MediaQuery.of(context).padding.bottom + 24,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        child: Text(
                          memory.caption!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.5),
                        ),
                      ),
                    ),

                  // Deletion banner
                  if (hasDeletion)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.of(context).padding.bottom + 16,
                        ),
                        color: Colors.black.withValues(alpha: 0.7),
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
            },
          ),

          // Top bar: back + counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  4, MediaQuery.of(context).padding.top + 4, 16, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  if (memories.length > 1)
                    Text(
                      '${safeIndex + 1} / ${memories.length}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                ],
              ),
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
            await ref
                .read(firestoreServiceProvider)
                .cancelMemoryDeletion(coupleId, memoryId);
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

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
          style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await ref
                      .read(firestoreServiceProvider)
                      .cancelMemoryDeletion(coupleId, memoryId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Keep It',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await ref
                      .read(firestoreServiceProvider)
                      .approveMemoryDeletion(coupleId, memoryId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
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
