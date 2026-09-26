import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/delight/couple_character.dart';
import '../../core/delight/delight.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';
import '../../core/utils/image_compression_service.dart';
import '../../core/utils/motion_photo_service.dart';

enum _TypeFilter { all, photos, videos, favorites }

class MemoryWallScreen extends ConsumerStatefulWidget {
  const MemoryWallScreen({super.key});

  @override
  ConsumerState<MemoryWallScreen> createState() => _MemoryWallScreenState();
}

class _MemoryWallScreenState extends ConsumerState<MemoryWallScreen> {
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  // null = show all memories; non-null = filter to a specific collection
  String? _activeCollectionId;
  _TypeFilter _typeFilter = _TypeFilter.all;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Multi-select state
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  // Pinch-to-zoom grid density. 3 columns (bigger photos) is the min, 6
  // (smaller photos, more per screen) the max — persisted per-device so
  // the zoom level sticks between sessions, same pattern as the Comfort
  // settings' SharedPreferences use.
  static const _gridColumnsPrefsKey = 'memory_grid_columns';
  static const _minGridColumns = 3;
  static const _maxGridColumns = 6;
  int _gridColumns = 3;
  int _gestureBaseColumns = 3;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt(_gridColumnsPrefsKey);
      if (saved != null && mounted) {
        setState(() => _gridColumns = saved.clamp(_minGridColumns, _maxGridColumns));
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureBaseColumns = _gridColumns;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Pinch OUT (fingers moving apart, scale > 1) should mean bigger
    // photos, i.e. FEWER columns — hence dividing, not multiplying.
    final target =
        (_gestureBaseColumns / details.scale).round().clamp(_minGridColumns, _maxGridColumns);
    if (target != _gridColumns) {
      setState(() => _gridColumns = target);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_gridColumnsPrefsKey, _gridColumns));
  }

  Future<void> _showAddMemorySheet() async {
    final coupleId = ref.read(coupleIdProvider);
    final authUser = FirebaseAuth.instance.currentUser;
    if (coupleId == null || authUser == null) return;
    final picker = ImagePicker();
    // Open native gallery directly — pickMultipleMedia allows selecting both
    // photos and videos in a single unified picker session.
    // Deliberately NOT passing maxWidth/maxHeight/imageQuality: those make
    // image_picker decode-and-re-encode the photo, which would silently
    // strip a Motion Photo's trailing video data before it ever reaches
    // this code. Compression now happens ourselves afterward, on the still
    // frame only, via compressImageBytesForUpload — same place every other
    // upload path in this app (share-import, letters) already does it.
    final media = await picker.pickMultipleMedia();
    if (media.isEmpty || !mounted) return;
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = media.length;
    });
    // Capture service and ids NOW before any awaits so navigation away
    // doesn't cause ref access errors mid-upload.
    final firestoreService = ref.read(firestoreServiceProvider);
    final uploaderUid = authUser.uid;

    // Upload every selected item concurrently rather than one-at-a-time —
    // each memory lands on the wall (via the live Firestore listener) the
    // moment its own upload finishes, instead of everything after the first
    // item queuing behind it. A sequential loop made picking 5+ photos take
    // roughly 5x as long as the slowest single upload for no reason.
    final errors = <String>[];
    var photoCount = 0;
    var videoCount = 0;
    await Future.wait(media.map((xfile) async {
      try {
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
          await firestoreService.addMemory(
            coupleId,
            MemoryModel(
              id: id,
              uploaderUid: uploaderUid,
              imageUrl: url,
              createdAt: DateTime.now(),
              isVideo: true,
            ),
          );
          videoCount++;
        } else {
          final rawBytes = await xfile.readAsBytes();
          // Look for an Android Motion Photo clip in the ORIGINAL bytes
          // before compressing the still — compression re-encodes the JPEG
          // and would destroy the trailing video data.
          final motionBytes = await extractMotionPhotoVideo(rawBytes);
          final stillBytes = await compressImageBytesForUpload(rawBytes);
          final url = await CloudinaryService.uploadImage(stillBytes, folder: 'two_hearts/$coupleId');
          String? motionVideoUrl;
          if (motionBytes != null) {
            final dir = await getTemporaryDirectory();
            final tmp = File('${dir.path}/${const Uuid().v4()}.mp4');
            await tmp.writeAsBytes(motionBytes);
            motionVideoUrl = await CloudinaryService.uploadVideo(tmp, folder: 'two_hearts/$coupleId');
            await tmp.delete().catchError((_) => tmp);
          }
          await firestoreService.addMemory(
            coupleId,
            MemoryModel(
              id: id,
              uploaderUid: uploaderUid,
              imageUrl: url,
              motionVideoUrl: motionVideoUrl,
              createdAt: DateTime.now(),
            ),
          );
          photoCount++;
        }
        if (mounted) {
          // A new memory joins the wall — petals & a polaroid drift up.
          // Fired per-item now (not once after the whole batch), since
          // items finish at different times when uploaded in parallel.
          DelightHaptics.thud();
          FloatingStickers.burst(context,
              stickers: const ['🌸', '✨', '📸'], count: 7);
        }
      } catch (e) {
        // Previously a bare try/finally around the whole loop — one upload
        // failure (Cloudinary error, file too large, no network) threw
        // silently and the sheet just closed, looking like nothing
        // happened, and also killed every upload still queued behind it.
        // Now each item fails independently and the rest still land.
        errors.add(e.toString());
      } finally {
        if (mounted) setState(() => _uploadDone++);
      }
    }));

    // One notification for the whole batch ("X added N photos and M
    // videos"), not one per file — see notifyBulkMemoryUpload.
    firestoreService.notifyBulkMemoryUpload(coupleId, photos: photoCount, videos: videoCount).ignore();

    if (mounted && errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.length == media.length
              ? "Couldn't upload: ${errors.first}"
              : "${errors.length} of ${media.length} didn't upload: ${errors.first}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _onSelectToggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectMode() => setState(() { _selectMode = false; _selectedIds.clear(); });

  void _addSelectedToCollection(String coupleId) {
    final ids = Set<String>.from(_selectedIds);
    _exitSelectMode();
    final collections = ref.read(photoCollectionsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddToCollectionSheet(
        memory: MemoryModel(id: ids.first, uploaderUid: '', imageUrl: '', createdAt: DateTime.now()),
        coupleId: coupleId,
        collections: collections,
        onAssign: (collectionId) async {
          final svc = ref.read(firestoreServiceProvider);
          for (final id in ids) {
            await svc.assignToCollection(coupleId, id, collectionId);
          }
        },
        onCreateNew: (name) async {
          final svc = ref.read(firestoreServiceProvider);
          final col = await svc.createCollection(coupleId, name);
          for (final id in ids) {
            await svc.assignToCollection(coupleId, id, col.id);
          }
        },
      ),
    );
  }

  Future<void> _removeSelectedFromCollection(String coupleId) async {
    final ids = Set<String>.from(_selectedIds);
    _exitSelectMode();
    await ref.read(firestoreServiceProvider).removeFromCollection(coupleId, ids.toList());
  }

  Future<void> _deleteSelected(String coupleId) async {
    final ids = Set<String>.from(_selectedIds);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete these photos?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          ids.length == 1
              ? "They'll need to approve it before it's actually gone."
              : "${ids.length} photos — they'll need to approve each one before it's actually gone.",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ask to delete', style: TextStyle(color: AppColors.rose)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    _exitSelectMode();
    final svc = ref.read(firestoreServiceProvider);
    for (final id in ids) {
      await svc.requestMemoryDeletion(coupleId, id);
    }
  }

  // Bulk "share to other apps" — the multi-select equivalent of the detail
  // screen's single-item "Forward to Chat"/"Save to Photos", but for
  // sharing outside the app entirely (share_plus's system share sheet).
  // Each selected item is downloaded to a temp file first (share_plus needs
  // a real file path, not a URL), with a progress dialog so a multi-photo
  // share doesn't look hung on a slow connection.
  Future<void> _shareSelected() async {
    final ids = Set<String>.from(_selectedIds);
    final memories = ref.read(memoriesProvider).value ?? const <MemoryModel>[];
    final selected = memories.where((m) => ids.contains(m.id)).toList();
    _exitSelectMode();
    if (selected.isEmpty || !mounted) return;

    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ShareProgressDialog(progress: progress, total: selected.length),
    );

    final tempFiles = <XFile>[];
    try {
      final dir = await getTemporaryDirectory();
      for (final memory in selected) {
        try {
          final response = await http.get(Uri.parse(memory.imageUrl));
          if (response.statusCode == 200) {
            final ext = memory.isVideo ? 'mp4' : 'jpg';
            final file = File('${dir.path}/${const Uuid().v4()}.$ext');
            await file.writeAsBytes(response.bodyBytes);
            tempFiles.add(XFile(file.path));
          }
        } catch (_) {
          // Skip whatever fails to download — share the rest.
        }
        progress.value++;
      }
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (tempFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't download those to share."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    await Share.shareXFiles(tempFiles);
    for (final f in tempFiles) {
      File(f.path).delete().catchError((_) => File(f.path));
    }
  }

  void _onLongPress(MemoryModel memory, String myUid, String coupleId) {
    if (!_selectMode) {
      setState(() {
        _selectMode = true;
        _selectedIds.add(memory.id);
      });
      return;
    }
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
            // Pin option — pinned memories sort first on the wall.
            ListTile(
              leading: Icon(
                  memory.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: AppColors.textPrimary),
              title: Text(memory.pinned ? 'Unpin' : 'Pin to top',
                  style: const TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(firestoreServiceProvider)
                    .togglePinMemory(coupleId, memory.id, !memory.pinned)
                    .ignore();
              },
            ),
            const Divider(color: AppColors.divider, height: 1),
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
    final coupleId = ref.read(coupleIdProvider) ?? '';
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
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                child: _selectMode
                    ? Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppColors.textPrimary),
                            onPressed: _exitSelectMode,
                          ),
                          Text('${_selectedIds.length} selected',
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      )
                    : _searching
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  autofocus: true,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: const InputDecoration(
                                    hintText: 'Search caption or place…',
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _query = v.trim()),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textMuted),
                                onPressed: () => setState(() {
                                  _searching = false;
                                  _query = '';
                                  _searchCtrl.clear();
                                }),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Memories',
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                            ?.copyWith(fontSize: 26)),
                                    const SizedBox(height: 2),
                                    const Text(
                                        'Relive the little moments that mean everything.',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.search_rounded,
                                    color: AppColors.textPrimary),
                                onPressed: () =>
                                    setState(() => _searching = true),
                              ),
                              if (_uploading)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_uploadTotal > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Text('$_uploadDone/$_uploadTotal',
                                              style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12)),
                                        ),
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value: _uploadTotal > 0
                                                ? _uploadDone / _uploadTotal
                                                : null,
                                            color: AppColors.rose),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: AppColors.textPrimary),
                                  onPressed: _showAddMemorySheet,
                                ),
                            ],
                          ),
              ),
              Expanded(
                // One continuous scroll — the hero card and collections
                // scroll away, the filter row pins once reached, and the
                // memory grid keeps scrolling underneath it, all as a
                // single page rather than a grid scrolling inside a
                // fixed-chrome shell.
                //
                // Pinch-to-zoom wraps the whole scroll view rather than
                // just the grid — Flutter's ScaleGestureRecognizer only
                // actually claims the gesture arena for genuine multi-touch
                // pinches, so single-finger scrolling underneath is
                // unaffected (the same technique this app already uses for
                // InteractiveViewer elsewhere).
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  child: CustomScrollView(
                    slivers: [
                    // Deliberately NOT gated on _selectMode — entering
                    // select mode (long-press) used to also remove these
                    // sections from the sliver list, which shrank the
                    // scrollable content above the grid and made the grid
                    // visibly jump/shift ("scrolls down a bit" right when
                    // you long-press). Only the top app-bar row and the
                    // bottom action bar change for select mode; the
                    // scrollable content itself now stays exactly as it was.
                    if (!_searching) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
                      const SliverToBoxAdapter(child: _HeroSnapshotCard()),
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
                      const SliverToBoxAdapter(child: _PartnerMostViewedCard()),
                      const SliverToBoxAdapter(child: SizedBox(height: 4)),
                      SliverToBoxAdapter(
                        child: _CollectionsRow(
                          activeCollectionId: _activeCollectionId,
                          onSelect: (id) =>
                              setState(() => _activeCollectionId = id),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyFilterHeaderDelegate(
                          child: _TypeFilterRow(
                            value: _typeFilter,
                            onChanged: (v) => setState(() => _typeFilter = v),
                          ),
                        ),
                      ),
                    ],
                    _MemoriesTab(
                      onLongPress: _onLongPress,
                      onUpload: _showAddMemorySheet,
                      activeCollectionId: _activeCollectionId,
                      typeFilter: _typeFilter,
                      query: _query,
                      selectMode: _selectMode,
                      selectedIds: _selectedIds,
                      onSelectToggle: _onSelectToggle,
                      columns: _gridColumns,
                    ),
                    ],
                  ),
                ),
              ),
              if (_selectMode && _selectedIds.isNotEmpty)
                Container(
                  color: AppColors.bgCard,
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_selectedIds.length} selected',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Only a real collection can have photos removed
                            // from it — "Liked" is derived from favorite,
                            // not a collectionId assignment.
                            if (_activeCollectionId != null &&
                                _activeCollectionId != _kLikedCollectionId)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _BulkActionPill(
                                  label: 'Remove from Collection',
                                  color: AppColors.bgCardLight,
                                  textColor: AppColors.textPrimary,
                                  onTap: coupleId.isNotEmpty
                                      ? () => _removeSelectedFromCollection(coupleId)
                                      : null,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _BulkActionPill(
                                label: 'Add to Collection',
                                gradient: const LinearGradient(
                                    colors: [AppColors.rose, AppColors.coral]),
                                textColor: Colors.white,
                                onTap: coupleId.isNotEmpty
                                    ? () => _addSelectedToCollection(coupleId)
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _BulkActionPill(
                                label: 'Share',
                                color: AppColors.bgCardLight,
                                textColor: AppColors.textPrimary,
                                onTap: _shareSelected,
                              ),
                            ),
                            _BulkActionPill(
                              label: 'Delete',
                              color: AppColors.bgCardLight,
                              textColor: AppColors.rose,
                              onTap: coupleId.isNotEmpty ? () => _deleteSelected(coupleId) : null,
                            ),
                          ],
                        ),
                      ),
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

// ── Hero "Random Snapshot" card ───────────────────────────────────────────

String _timeAgo(DateTime from) {
  final days = DateTime.now().difference(from).inDays;
  if (days <= 0) return 'today';
  if (days < 30) return '$days day${days == 1 ? '' : 's'} ago';
  if (days < 365) {
    final months = (days / 30).round();
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  final years = (days / 365).round();
  return '$years year${years == 1 ? '' : 's'} ago';
}

class _HeroSnapshotCard extends ConsumerStatefulWidget {
  const _HeroSnapshotCard();

  @override
  ConsumerState<_HeroSnapshotCard> createState() => _HeroSnapshotCardState();
}

class _HeroSnapshotCardState extends ConsumerState<_HeroSnapshotCard> {
  final _rng = math.Random();
  int _seed = 0;

  void _shuffle() {
    HapticFeedback.selectionClick();
    setState(() => _seed = _rng.nextInt(1 << 31));
  }

  @override
  Widget build(BuildContext context) {
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final accent = ref.watch(accentColorProvider);
    if (memories.isEmpty) return const SizedBox.shrink();

    final pick = memories[_seed.abs() % memories.length];
    final when = pick.takenAt ?? pick.createdAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.22), AppColors.bgCard],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: accent, size: 14),
                      const SizedBox(width: 6),
                      Text('RANDOM SNAPSHOT',
                          style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('A moment from ${_timeAgo(when)}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.textMuted, size: 13),
                      const SizedBox(width: 4),
                      Text(DateFormat('h:mm a').format(when),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.textMuted, size: 13),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            DateFormat('MMM d, yyyy').format(when),
                            if (pick.location != null && pick.location!.isNotEmpty)
                              pick.location!,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SquishyTap(
                    onTap: _shuffle,
                    style: TapAnimationStyle.spin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [accent, AppColors.coral]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shuffle_rounded,
                              color: Colors.white, size: 15),
                          const SizedBox(width: 6),
                          const Text('Surprise me',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => context.push('/memory/${pick.id}'),
              child: Transform.rotate(
                angle: 0.06,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 118,
                      padding: const EdgeInsets.fromLTRB(5, 5, 5, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDF8),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(2, 6)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: CachedNetworkImage(
                          imageUrl: pick.isVideo
                              ? _videoThumb(pick.imageUrl)
                              : pick.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              Container(color: AppColors.bgCardLight),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: SquishyTap(
                        onTap: _shuffle,
                        style: TapAnimationStyle.spin,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.bgMid,
                            border: Border.all(color: accent, width: 1.5),
                          ),
                          child: Icon(Icons.refresh_rounded,
                              color: accent, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Partner's most-viewed highlight ───────────────────────────────────────
// A real signal, not a fabricated one — MemoryModel.viewCounts already
// tracks per-uid view counts (incremented once per detail-screen session
// per memory, see incrementMemoryView). This just surfaces whichever
// memory the partner has actually opened the most. Shows nothing if they
// haven't viewed anything yet, rather than picking an arbitrary "most
// viewed: 0" memory.
class _PartnerMostViewedCard extends ConsumerWidget {
  const _PartnerMostViewedCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final accent = ref.watch(accentColorProvider);
    if (partner == null || memories.isEmpty) return const SizedBox.shrink();

    MemoryModel? top;
    var topCount = 0;
    for (final m in memories) {
      final count = m.viewCountOf(partner.uid);
      if (count > topCount) {
        top = m;
        topCount = count;
      }
    }
    if (top == null) return const SizedBox.shrink();
    final partnerName = partner.displayName.split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: GestureDetector(
        onTap: () => context.push('/memory/${top!.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CachedNetworkImage(
                    imageUrl: top.isVideo ? _videoThumb(top.imageUrl) : top.imageUrl,
                    fit: BoxFit.cover,
                    // Only one dimension — see the grid tile fix below for
                    // why setting both distorts non-square photos.
                    memCacheWidth: 88,
                    errorWidget: (_, _, _) => Container(color: AppColors.bgCardLight),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$partnerName's most-viewed",
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text('Opened this $topCount time${topCount == 1 ? '' : 's'} ♡',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              Icon(Icons.favorite_rounded, color: accent, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

String _videoThumb(String videoUrl) {
  if (videoUrl.contains('cloudinary.com')) {
    return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
  }
  return videoUrl;
}

// ── Collections Row — each card shows a 4-photo collage from that album ──

const _kLikedCollectionId = '__liked__';

class _BulkActionPill extends StatelessWidget {
  final String label;
  final Color? color;
  final Gradient? gradient;
  final Color textColor;
  final VoidCallback? onTap;

  const _BulkActionPill({
    required this.label,
    this.color,
    this.gradient,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

// Shown while a bulk share/export downloads each selected item — a count-
// based "X of Y" bar rather than a spinner, so a multi-photo share doesn't
// look hung on a slow connection.
class _ShareProgressDialog extends StatelessWidget {
  final ValueNotifier<int> progress;
  final int total;

  const _ShareProgressDialog({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, done, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Preparing to share…',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? null : done / total,
                    minHeight: 8,
                    backgroundColor: AppColors.bgCardLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.rose),
                  ),
                ),
                const SizedBox(height: 10),
                Text('$done of $total',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            );
          },
        ),
      ),
    );
  }
}

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

  IconData _collectionIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('trip') || lower.contains('travel')) {
      return Icons.flight_rounded;
    }
    if (lower.contains('college') || lower.contains('school') ||
        lower.contains('uni')) {
      return Icons.school_rounded;
    }
    if (lower.contains('cutie') || lower.contains('cute') ||
        lower.contains('love')) {
      return Icons.nightlight_round;
    }
    if (lower.contains('family')) return Icons.home_rounded;
    if (lower.contains('food')) return Icons.restaurant_rounded;
    return Icons.folder_rounded;
  }

  /// Same 4 photos every rebuild (seeded by the collection id) until the
  /// underlying photo list actually changes — a real random pick, but a
  /// stable-looking one instead of reshuffling on every rebuild.
  List<String> _collageFor(String seedKey, List<MemoryModel> photos) {
    if (photos.isEmpty) return const [];
    final urls = photos.map((m) => m.isVideo ? _videoThumb(m.imageUrl) : m.imageUrl).toList();
    final rng = math.Random(seedKey.hashCode ^ urls.length);
    urls.shuffle(rng);
    return urls.take(4).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(photoCollectionsProvider);
    final memoriesAsync = ref.watch(memoriesProvider);
    final coupleId = ref.watch(coupleIdProvider);
    final accent = ref.watch(accentColorProvider);
    final collections = collectionsAsync.valueOrNull ?? [];
    final memories = memoriesAsync.valueOrNull ?? [];

    final photosByCollection = <String, List<MemoryModel>>{};
    for (final m in memories) {
      if (m.collectionId != null) {
        photosByCollection.putIfAbsent(m.collectionId!, () => []).add(m);
      }
    }
    final liked = memories.where((m) => m.favorite).toList();

    if (collections.isEmpty && activeCollectionId == null && liked.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Text('Collections', style: Theme.of(context).textTheme.titleLarge),
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
                )
              else if (collections.isNotEmpty)
                GestureDetector(
                  onTap: () => _showAllCollectionsSheet(
                      context, ref, coupleId, accent, collections, photosByCollection),
                  child: Text('See all',
                      style: TextStyle(
                          color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (liked.isNotEmpty)
                _CollectionCard(
                  title: 'Liked',
                  count: liked.length,
                  color: AppColors.rose,
                  icon: Icons.favorite_rounded,
                  collage: _collageFor(_kLikedCollectionId, liked),
                  isActive: activeCollectionId == _kLikedCollectionId,
                  onTap: () => onSelect(
                      activeCollectionId == _kLikedCollectionId ? null : _kLikedCollectionId),
                ),
              ...collections.map((col) {
                final photos = photosByCollection[col.id] ?? [];
                return _CollectionCard(
                  title: col.name,
                  count: photos.length,
                  color: _collectionColor(col.name),
                  icon: _collectionIcon(col.name),
                  collage: _collageFor(col.id, photos),
                  isActive: activeCollectionId == col.id,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(activeCollectionId == col.id ? null : col.id);
                  },
                );
              }),
              // + New collection card
              GestureDetector(
                onTap: coupleId == null
                    ? null
                    : () => _showNewCollectionDialog(
                        context, ref, coupleId, accent),
                child: Container(
                  width: 96,
                  margin: const EdgeInsets.only(right: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.add_rounded, color: accent, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text('New album',
                          style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
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

  /// The "See all" popup — every collection in one scrollable list, each
  /// with rename/delete, rather than only being browsable via the
  /// horizontally-scrolling card row above.
  void _showAllCollectionsSheet(
    BuildContext context,
    WidgetRef ref,
    String? coupleId,
    Color accent,
    List<PhotoCollection> collections,
    Map<String, List<MemoryModel>> photosByCollection,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75),
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(sheetCtx).padding.bottom + 20),
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
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('All Collections',
                style: Theme.of(sheetCtx).textTheme.displayMedium?.copyWith(fontSize: 19)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: collections.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AppColors.divider, height: 1),
                itemBuilder: (_, i) {
                  final col = collections[i];
                  final count = photosByCollection[col.id]?.length ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _collectionColor(col.name).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_collectionIcon(col.name), color: _collectionColor(col.name)),
                    ),
                    title: Text(col.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('$count photo${count == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onSelect(col.id);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                      onPressed: () => _showCollectionActionsSheet(context, ref, coupleId, col),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionActionsSheet(
      BuildContext context, WidgetRef ref, String? coupleId, PhotoCollection col) {
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
              leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              title: const Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (coupleId != null) _showRenameCollectionDialog(context, ref, coupleId, col);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
              title: const Text('Delete collection', style: TextStyle(color: AppColors.rose)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (coupleId == null) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.bgCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete this collection?',
                        style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text(
                        'The photos stay in Memories — this only removes the album.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete', style: TextStyle(color: AppColors.rose)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(firestoreServiceProvider).deleteCollection(coupleId, col.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameCollectionDialog(
      BuildContext context, WidgetRef ref, String coupleId, PhotoCollection col) {
    final ctrl = TextEditingController(text: col.name);
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Collection', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Collection name…',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.rose)),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((name) {
      ctrl.dispose();
      if (name != null && name.isNotEmpty && name != col.name) {
        ref.read(firestoreServiceProvider).renameCollection(coupleId, col.id, name).ignore();
      }
    });
  }
}

class _CollectionCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final List<String> collage;
  final bool isActive;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.collage,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.pulse,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: 128,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        transform: Matrix4.identity()
          ..scaleByDouble(isActive ? 1.04 : 1.0, isActive ? 1.04 : 1.0, 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (collage.isEmpty)
                Container(color: color.withValues(alpha: 0.35))
              else
                _CollagePhotoGrid(urls: collage, tint: color),
              // Darken for legibility
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                    Text(count == 1 ? '1 memory' : '$count memories',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10.5)),
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

/// A 2x2 collage of (up to) 4 photos — the collection's "folder cover".
/// Fewer than 4 photos just repeats the tint color for the empty slots.
class _CollagePhotoGrid extends StatelessWidget {
  final List<String> urls;
  final Color tint;
  const _CollagePhotoGrid({required this.urls, required this.tint});

  @override
  Widget build(BuildContext context) {
    Widget cell(int i) {
      if (i >= urls.length) return ColoredBox(color: tint.withValues(alpha: 0.3));
      return CachedNetworkImage(
        imageUrl: urls[i],
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(color: tint.withValues(alpha: 0.3)),
        errorWidget: (_, _, _) => ColoredBox(color: tint.withValues(alpha: 0.3)),
      );
    }

    return Column(
      children: [
        Expanded(child: Row(children: [Expanded(child: cell(0)), Expanded(child: cell(1))])),
        Expanded(child: Row(children: [Expanded(child: cell(2)), Expanded(child: cell(3))])),
      ],
    );
  }
}

// ── Type filter chips ─────────────────────────────────────────────────────

class _TypeFilterRow extends StatelessWidget {
  final _TypeFilter value;
  final ValueChanged<_TypeFilter> onChanged;
  const _TypeFilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(_TypeFilter f, IconData icon, String label) {
      final selected = value == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SquishyTap(
          onTap: () => onChanged(f),
          style: TapAnimationStyle.pulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.rose.withValues(alpha: 0.22) : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.rose : AppColors.divider,
                  width: selected ? 1.2 : 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected ? AppColors.rose : AppColors.textMuted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: selected ? AppColors.rose : AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip(_TypeFilter.all, Icons.grid_view_rounded, 'All'),
            chip(_TypeFilter.photos, Icons.image_outlined, 'Photos'),
            chip(_TypeFilter.videos, Icons.play_circle_outline_rounded, 'Videos'),
            chip(_TypeFilter.favorites, Icons.favorite_border_rounded, 'Favorites'),
          ],
        ),
      ),
    );
  }
}

/// Pins the type-filter row to the top once scrolled to, Google-Photos
/// style, while the hero card and collections above it scroll away.
class _StickyFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyFilterHeaderDelegate({required this.child});

  static const _height = 52.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyFilterHeaderDelegate oldDelegate) => oldDelegate.child != child;
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

// ── Memories grid — grouped by date, like a real timeline ─────────────────

class _MemoriesTab extends ConsumerWidget {
  final void Function(MemoryModel, String, String) onLongPress;
  final VoidCallback onUpload;
  final String? activeCollectionId;
  final _TypeFilter typeFilter;
  final String query;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(String) onSelectToggle;
  final int columns;

  const _MemoriesTab({
    required this.onLongPress,
    required this.onUpload,
    this.activeCollectionId,
    required this.typeFilter,
    required this.query,
    required this.selectMode,
    required this.selectedIds,
    required this.onSelectToggle,
    required this.columns,
  });

  Map<String, List<MemoryModel>> _groupByDate(List<MemoryModel> memories) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final map = <String, List<MemoryModel>>{};
    for (final m in memories) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      final diff = today.difference(d).inDays;
      final key = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : DateFormat('MMM d, yyyy').format(d);
      map.putIfAbsent(key, () => []).add(m);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesAsync = ref.watch(memoriesProvider);
    final density = ref.watch(layoutDensityProvider);
    final accent = ref.watch(accentColorProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final coupleId = ref.watch(coupleIdProvider) ?? '';

    return memoriesAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: AppColors.rose)),
      ),
      error: (e, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
      ),
      data: (allMemories) {
        var memories = activeCollectionId == null
            ? allMemories
            : activeCollectionId == _kLikedCollectionId
                ? allMemories.where((m) => m.favorite).toList()
                : allMemories
                    .where((m) => m.collectionId == activeCollectionId)
                    .toList();

        switch (typeFilter) {
          case _TypeFilter.all:
            break;
          case _TypeFilter.photos:
            memories = memories.where((m) => !m.isVideo).toList();
          case _TypeFilter.videos:
            memories = memories.where((m) => m.isVideo).toList();
          case _TypeFilter.favorites:
            memories = memories.where((m) => m.favorite).toList();
        }

        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          memories = memories.where((m) {
            return (m.caption?.toLowerCase().contains(q) ?? false) ||
                (m.location?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        if (allMemories.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoupleCharacter(
                    character: CoupleCharacterId.combo, pose: 'excited', height: 110),
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
            ),
          );
        }

        if (memories.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text('No memories match this filter.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }

        // Pinned memories get their own leading section instead of being
        // sorted into the date groups — "important ones come first,"
        // literally, rather than just reordered within their own day.
        final pinned = memories.where((m) => m.pinned).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final unpinned = memories.where((m) => !m.pinned).toList();
        final groups = {
          if (pinned.isNotEmpty) '📌 Pinned': pinned,
          ..._groupByDate(unpinned),
        };

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
              16 * density.factor, 8 * density.factor, 16 * density.factor, 24 * density.factor),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              groups.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (ctx, i) {
                      final memory = entry.value[i];
                      return _MemoryTile(
                        memory: memory,
                        accent: accent,
                        myUid: myUid,
                        selectMode: selectMode,
                        selected: selectedIds.contains(memory.id),
                        onTap: selectMode
                            ? () => onSelectToggle(memory.id)
                            // Videos used to open a separate bare-bones
                            // player with none of the swipe/comments/
                            // forward/export/progress-bar features below —
                            // now both media types go through the same
                            // detail screen.
                            : () => context.push('/memory/${memory.id}'),
                        onFavorite: selectMode
                            ? () {}
                            : () async {
                                if (coupleId.isEmpty) return;
                                await ref
                                    .read(firestoreServiceProvider)
                                    .toggleFavoriteMemory(coupleId, memory.id,
                                        !memory.favorite);
                              },
                        onLongPress: coupleId.isNotEmpty
                            ? () => onLongPress(memory, myUid, coupleId)
                            : null,
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 30));
                    },
                  ),
                ],
              ),
            );
          }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final MemoryModel memory;
  final Color accent;
  final String myUid;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onLongPress;

  const _MemoryTile({
    required this.memory,
    required this.accent,
    required this.myUid,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onFavorite,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasDeletionRequest = memory.deletionRequestedBy != null;
    final partnerRequested = hasDeletionRequest && memory.deletionRequestedBy != myUid;
    final timeStr = DateFormat('h:mm a').format(memory.createdAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: 'memory_${memory.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (memory.isVideo)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _videoThumb(memory.imageUrl),
                      fit: BoxFit.cover,
                      // See the Calendar day-tile fix for why this matters:
                      // every grid tile decoding a full-res image at once
                      // is what makes a photo grid feel slow to load. Only
                      // one dimension, though — both together stretches
                      // non-square source images to fit exactly, which is
                      // what made thumbnails look distorted.
                      memCacheWidth: 220,
                      placeholder: (ctx, url) =>
                          Container(color: Colors.black87),
                      errorWidget: (ctx, url, err) =>
                          Container(color: Colors.black87),
                    ),
                    const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 34),
                    ),
                  ],
                )
              else
                CachedNetworkImage(
                  imageUrl: memory.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 220,
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
              // Bottom gradient overlay — time + location
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
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
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600)),
                      if (memory.location != null && memory.location!.isNotEmpty)
                        Text(memory.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 9.5)),
                    ],
                  ),
                ),
              ),
              // Motion Photo badge — purely indicative here (no autoplay in
              // a small grid cell); tap-and-hold to actually play it lives
              // in the detail screen.
              if (memory.motionVideoUrl != null)
                Positioned(
                  top: hasDeletionRequest ? 26 : 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.motion_photos_on_rounded,
                            color: Colors.white, size: 11),
                        SizedBox(width: 2),
                        Text('MOTION',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                      ],
                    ),
                  ),
                ),
              // Deletion badge
              if (hasDeletionRequest)
                Positioned(
                  top: 6, left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: partnerRequested
                          ? Colors.orange.withValues(alpha: 0.9)
                          : Colors.red.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      partnerRequested ? '🗑' : '🗑…',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              // Favorite button (hidden in select mode)
              if (!selectMode)
                Positioned(
                  top: 6, right: 6,
                  child: SquishyTap(
                    onTap: onFavorite,
                    cuteStickers: memory.favorite ? null : const ['💖'],
                    style: TapAnimationStyle.heartBeat,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                          color: Colors.black38, shape: BoxShape.circle),
                      child: Icon(
                        memory.favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: memory.favorite ? AppColors.rose : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              // Selection overlay
              if (selectMode)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.rose.withValues(alpha: 0.35)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              if (selectMode)
                Positioned(
                  top: 6, right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.rose : Colors.black38,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 13)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

