import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../core/firebase/models.dart';
import '../../core/presence/activity_announcer.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// How long to wait before telling the partner "they're going through your
/// photos" again. Photo viewing is high-frequency, so an unthrottled
/// notification would spam them and cost a Firestore write per tap. The
/// timestamp lives in local SharedPreferences rather than Firestore, so the
/// throttle check itself costs zero reads.
const kReminiscingThrottle = Duration(hours: 6);
const _kReminiscingPrefKey = 'last_reminiscing_notify_ms';

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
  // Tap-and-hold on a Motion Photo plays its short embedded clip, mirroring
  // iOS's own Live Photo interaction — released, it snaps back to the
  // still. Only one can play at a time (there's only one visible page).
  String? _playingMotionId;

  void _startMotionPreview(String memoryId) {
    HapticFeedback.selectionClick();
    setState(() => _playingMotionId = memoryId);
  }

  void _stopMotionPreview() {
    if (_playingMotionId != null) setState(() => _playingMotionId = null);
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    announceActivity('Looking through Memories');
    _maybeNotifyReminiscing();
  }

  /// Sends the partner a soft "they're missing you" nudge when someone opens
  /// the photos — at most once per [kReminiscingThrottle].
  Future<void> _maybeNotifyReminiscing() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kReminiscingPrefKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastMs < kReminiscingThrottle.inMilliseconds) return;
    await prefs.setInt(_kReminiscingPrefKey, now);
    if (!mounted) return;
    ref.read(firestoreServiceProvider).notifyReminiscing(coupleId).ignore();
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

  void _showComments(MemoryModel memory, String myUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(memoryId: memory.id, myUid: myUid),
    );
  }

  Future<void> _forwardToChat(MemoryModel memory) async {
    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;
    await ref.read(firestoreServiceProvider).sendMessage(
          coupleId,
          MessageModel(
            id: const Uuid().v4(),
            senderId: uid,
            content: memory.imageUrl,
            type: memory.isVideo ? MessageType.video : MessageType.image,
            sentAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent to chat ♡'), behavior: SnackBarBehavior.floating),
    );
  }

  // Streams the download instead of a plain http.get so a large video's
  // save-to-photos can show real byte-level progress instead of sitting on
  // an indeterminate spinner until the whole file lands.
  Future<Uint8List> _downloadWithProgress(String url, ValueNotifier<double?> progress) async {
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode})');
      }
      final total = response.contentLength;
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        progress.value = (total != null && total > 0) ? bytes.length / total : null;
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }

  Future<void> _exportToDevice(MemoryModel memory) async {
    final messenger = ScaffoldMessenger.of(context);
    final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
    if (!hasAccess) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Photo library access is needed to save this.'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    if (!mounted) return;
    final progress = ValueNotifier<double?>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadProgressDialog(progress: progress, label: 'Saving to your photos…'),
    );
    try {
      final bytes = await _downloadWithProgress(memory.imageUrl, progress);
      if (memory.isVideo) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${const Uuid().v4()}.mp4');
        await file.writeAsBytes(bytes);
        await Gal.putVideo(file.path, album: 'Two Hearts');
        await file.delete().catchError((_) => file);
      } else {
        await Gal.putImageBytes(bytes, album: 'Two Hearts');
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Saved to your photos ♡'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(
        content: Text("Couldn't save: $e"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showMoreActions(MemoryModel memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.textPrimary),
              title: const Text('Forward to Chat',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _forwardToChat(memory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded, color: AppColors.textPrimary),
              title: const Text('Save to Photos',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _exportToDevice(memory);
              },
            ),
          ],
        ),
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

              final hasMotion = !memory.isVideo && memory.motionVideoUrl != null;
              final playingMotion = hasMotion && _playingMotionId == memory.id;

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
                onLongPressStart:
                    hasMotion ? (_) => _startMotionPreview(memory.id) : null,
                onLongPressEnd: hasMotion ? (_) => _stopMotionPreview() : null,
                onLongPressCancel: hasMotion ? _stopMotionPreview : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                  if (memory.isVideo)
                    _VideoPageItem(url: memory.imageUrl)
                  else if (playingMotion)
                    _MotionPhotoLoop(url: memory.motionVideoUrl!)
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
                  if (hasMotion && !playingMotion)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 56,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.motion_photos_on_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 5),
                              Text('Press and hold to play',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                            ],
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

          // Top bar: back + counter. Also doubles as the "swipe down to open
          // comments" hit target — mirrors the swipe-up-for-Details handle
          // below, and lives outside the photo Stack for the same reason
          // that one does: InteractiveViewer's own pan/zoom would otherwise
          // fight a vertical drag layered directly over the image.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (safeIndex < memories.length &&
                    (details.primaryVelocity ?? 0) > 200) {
                  _showComments(memories[safeIndex], myUid);
                }
              },
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
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          '${safeIndex + 1} / ${memories.length}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      onPressed: () => _showMoreActions(memories[safeIndex]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Comments — a small persistent pill, expanding into a sheet on
          // tap (see _showComments/_CommentsSheet), or via swiping down
          // anywhere on the top bar above, rather than a fixed inline
          // block, so it doesn't compete with the swipe-up Details handle
          // or the deletion banner for the same bottom-of-screen space on
          // every single memory.
          if (safeIndex < memories.length)
            Positioned(
              left: 12,
              bottom: MediaQuery.of(context).padding.bottom + 64,
              child: _CommentsPill(
                memoryId: memories[safeIndex].id,
                onTap: () => _showComments(memories[safeIndex], myUid),
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

// Plays a Motion Photo's short embedded clip while a finger holds it down —
// muted (it's a still-photo stand-in, not a video with its own sound) and
// looping in case the hold outlasts the clip's few seconds.
class _MotionPhotoLoop extends StatefulWidget {
  final String url;
  const _MotionPhotoLoop({required this.url});

  @override
  State<_MotionPhotoLoop> createState() => _MotionPhotoLoopState();
}

class _MotionPhotoLoopState extends State<_MotionPhotoLoop> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0)
      ..setLooping(true)
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
    if (!_initialized) return Container(color: Colors.black);
    return Center(
      child: AspectRatio(
        aspectRatio: _ctrl.value.aspectRatio,
        child: VideoPlayer(_ctrl),
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

  static const _seekAmount = Duration(seconds: 10);

  Future<void> _seek(Duration delta) async {
    final target = _ctrl.value.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _ctrl.value.duration ? _ctrl.value.duration : target);
    HapticFeedback.lightImpact();
    await _ctrl.seekTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.rose));
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _ctrl.value.aspectRatio,
            child: VideoPlayer(_ctrl),
          ),
        ),
        // Three tap zones over the whole video: left third seeks back,
        // right third seeks forward, the middle third toggles play/pause —
        // same layout convention as most video apps.
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _seek(-_seekAmount),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(
                      () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play()),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _seek(_seekAmount),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          child: VideoProgressIndicator(
            _ctrl,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: AppColors.rose,
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
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

// ── Comments — small pill + expandable sheet ──────────────────────────────

class _CommentsPill extends ConsumerWidget {
  final String memoryId;
  final VoidCallback onTap;
  const _CommentsPill({required this.memoryId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(memoryCommentsProvider(memoryId)).valueOrNull?.length ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(count == 0 ? 'Comment' : '$count comment${count == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String memoryId;
  final String myUid;
  const _CommentsSheet({required this.memoryId, required this.myUid});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final coupleId = ref.read(coupleIdProvider);
    if (text.isEmpty || coupleId == null) return;
    _ctrl.clear();
    await ref.read(firestoreServiceProvider).addMemoryComment(coupleId, widget.memoryId, text);
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(memoryCommentsProvider(widget.memoryId)).valueOrNull ?? [];
    final partnerName =
        ref.watch(partnerUserProvider).valueOrNull?.displayName.split(' ').first ?? 'Them';
    String nameFor(String? uid) => uid == widget.myUid ? 'You' : partnerName;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ],
            ),
          ),
          const Text('Comments',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Flexible(
            child: comments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No comments yet ♡',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bgCardLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nameFor(c['uid'] as String?),
                                  style: const TextStyle(
                                      color: AppColors.rose,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(c['text'] as String? ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bgCardLight,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.rose),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Shown while saving a memory to the device's photos — real byte-level
// progress via _downloadWithProgress's streamed response, falling back to
// an indeterminate bar when the server didn't send a Content-Length.
class _DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<double?> progress;
  final String label;

  const _DownloadProgressDialog({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: AppColors.bgCardLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.rose),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(height: 10),
                  Text('${(value * 100).clamp(0, 100).round()}%',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
