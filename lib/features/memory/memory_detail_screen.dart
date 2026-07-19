import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  final String memoryId;
  const MemoryDetailScreen({super.key, required this.memoryId});

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen>
    with ActivityAnnouncer {
  late PageController _pageCtrl;
  int _currentIndex = 0;
  final Set<String> _countedThisSession = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    announceActivity('Looking through Memories');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _countView(String memoryId) {
    if (_countedThisSession.contains(memoryId)) return;
    _countedThisSession.add(memoryId);
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;
    ref.read(firestoreServiceProvider).incrementMemoryView(coupleId, memoryId, uid).ignore();
  }

  void _showDetails(MemoryModel memory, String? partnerUid, String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemoryDetailsSheet(
        memory: memory,
        partnerUid: partnerUid,
        myUid: myUid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';
    final partnerUid = ref.watch(partnerUserProvider).valueOrNull?.uid;

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
    if (safeIndex < memories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _countView(memories[safeIndex].id);
      });
    }

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
                onTapUp: memory.isVideo ? null : (details) {
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
                  if (memory.isVideo)
                    _VideoPageItem(url: memory.imageUrl)
                  else
                  // Full-screen image with pinch-zoom
                  InteractiveViewer(
                    child: Hero(
                      tag: 'memory_${memory.id}',
                      child: CachedNetworkImage(
                        imageUrl: memory.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => Container(color: Colors.black),
                        errorWidget: (_, _, _) => Container(
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
                  if (partnerUid != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye_outlined,
                              color: Colors.white70, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            '${memories[safeIndex].viewCountOf(partnerUid)}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
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

          // Swipe-up-for-details handle. A dedicated small hit target (not a
          // gesture layered over the photo itself) so it never fights
          // InteractiveViewer's own pan/zoom for the vertical drag.
          if (safeIndex < memories.length)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showDetails(memories[safeIndex], partnerUid, myUid),
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) < -200) {
                    _showDetails(memories[safeIndex], partnerUid, myUid);
                  }
                },
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, 14, 0, MediaQuery.of(context).padding.bottom + 8),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_up_rounded,
                          color: Colors.white.withValues(alpha: 0.6), size: 22),
                      Text('Details',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline video player for the detail PageView ───────────────────────────

class _VideoPageItem extends StatefulWidget {
  final String url;
  const _VideoPageItem({required this.url});

  @override
  State<_VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends State<_VideoPageItem> {
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
          _ctrl.setLooping(true);
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
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rose));
    }
    return GestureDetector(
      onTap: () => setState(
          () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play()),
      child: Center(
        child: AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: VideoPlayer(_ctrl),
        ),
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

// ── Swipe-up details sheet: location, date/time, view count ──────────────

class _MemoryDetailsSheet extends StatelessWidget {
  final MemoryModel memory;
  final String? partnerUid;
  final String myUid;

  const _MemoryDetailsSheet({
    required this.memory,
    required this.partnerUid,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context) {
    final when = memory.takenAt ?? memory.createdAt;
    final myViews = memory.viewCountOf(myUid);
    final partnerViews = memory.viewCountOf(partnerUid);
    final totalViews = myViews + partnerViews;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Memory details',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label: DateFormat('EEEE, MMM d, yyyy · h:mm a').format(when),
          ),
          if (memory.location?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(icon: Icons.location_on_rounded, label: memory.location!),
          ],
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.remove_red_eye_rounded,
            label: partnerUid == null
                ? 'Viewed $totalViews time${totalViews == 1 ? '' : 's'}'
                : 'Viewed $totalViews time${totalViews == 1 ? '' : 's'} '
                    '(you: $myViews · them: $partnerViews)',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.4)),
        ),
      ],
    );
  }
}
