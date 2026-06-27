import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

// ── Deterministic book palette ────────────────────────────────────────────

const _kBookColors = [
  Color(0xFF8B2323), // deep red
  Color(0xFF2F5F3F), // forest green
  Color(0xFF9E7B1A), // mustard / dark gold
  Color(0xFF1A2F5C), // navy
  Color(0xFF7A4A2A), // tan / leather
  Color(0xFF6B1A2F), // burgundy
  Color(0xFF3D4A5C), // slate
  Color(0xFF4A2F1A), // dark brown
  Color(0xFF2C4A3E), // dark teal
  Color(0xFF5C3D2E), // chocolate
];

class _BookProps {
  final Color color;
  final double widthFraction;
  final double thickness;
  final double rotationDeg;
  final double xOffset;

  const _BookProps({
    required this.color,
    required this.widthFraction,
    required this.thickness,
    required this.rotationDeg,
    required this.xOffset,
  });

  factory _BookProps.fromId(String id) {
    int h = id.codeUnits.fold(0, (int a, int c) => (a * 31 + c) & 0x7FFFFFFF);
    int next() {
      h = (h * 1664525 + 1013904223) & 0x7FFFFFFF;
      return h;
    }

    final colorIdx = next() % _kBookColors.length;
    final wf = 0.62 + (next() % 300) / 1000.0;
    final th = 30.0 + (next() % 22).toDouble();
    final rot = ((next() % 80) - 40) / 10.0;
    final xOff = ((next() % 25) - 12).toDouble();

    return _BookProps(
      color: _kBookColors[colorIdx],
      widthFraction: wf.clamp(0.62, 0.92),
      thickness: th,
      rotationDeg: rot,
      xOffset: xOff,
    );
  }
}

// ── Library background painter ─────────────────────────────────────────────

class _LibraryPainter extends CustomPainter {
  const _LibraryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Dark warm background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1007), Color(0xFF0D0805)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Warm amber glow from top-center (lamp light)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, -size.height * 0.1),
        width: size.width * 1.2,
        height: size.height * 0.7,
      ),
      Paint()
        ..color = const Color(0xFFFF8C00).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );

    // Shelf planks
    const shelfColor = Color(0xFF3A2510);
    const shelfShadow = Color(0xFF000000);
    final shelfPositions = [
      size.height * 0.26,
      size.height * 0.52,
      size.height * 0.78,
    ];
    for (final y in shelfPositions) {
      // Plank
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 11),
        Paint()..color = shelfColor,
      );
      // Edge highlight
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 2),
        Paint()..color = const Color(0xFF6A4520).withValues(alpha: 0.6),
      );
      // Drop shadow below plank
      canvas.drawRect(
        Rect.fromLTWH(0, y + 11, size.width, 10),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              shelfShadow.withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, y + 11, size.width, 10)),
      );

      // Blurred books on shelf
      _drawShelfBooks(canvas, size.width, y - 55, 55);
    }
  }

  void _drawShelfBooks(Canvas canvas, double width, double top, double height) {
    final rng = math.Random(top.toInt());
    double x = 6;
    while (x < width - 10) {
      final w = 10.0 + rng.nextDouble() * 16;
      final h = height * (0.5 + rng.nextDouble() * 0.5);
      final colorIdx = rng.nextInt(_kBookColors.length);
      canvas.drawRect(
        Rect.fromLTWH(x, top + (height - h), w, h),
        Paint()
          ..color = _kBookColors[colorIdx].withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      x += w + 1 + rng.nextDouble() * 4;
    }
  }

  @override
  bool shouldRepaint(_LibraryPainter _) => false;
}

// ── Main screen ────────────────────────────────────────────────────────────

class BucketListScreen extends ConsumerStatefulWidget {
  const BucketListScreen({super.key});

  @override
  ConsumerState<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends ConsumerState<BucketListScreen> {
  final _textCtrl = TextEditingController();
  String? _animatingId; // last added book plays fall animation
  Set<String> _knownIds = {};

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _onItemsUpdated(List<BucketItem> items) {
    final newId = items
        .map((i) => i.id)
        .where((id) => !_knownIds.contains(id))
        .lastOrNull;
    if (newId != null) {
      _knownIds = items.map((i) => i.id).toSet();
      // Schedule animation flag reset after animation completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _animatingId = newId);
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) setState(() => _animatingId = null);
          });
        }
      });
    } else {
      _knownIds = items.map((i) => i.id).toSet();
    }
  }

  Future<void> _addItem() async {
    final title = _textCtrl.text.trim();
    if (title.isEmpty) return;

    final coupleId = ref.read(coupleIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (coupleId == null || uid == null) return;

    final item = BucketItem(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      addedBy: uid,
    );

    _textCtrl.clear();
    HapticFeedback.mediumImpact();
    await ref.read(firestoreServiceProvider).addBucketItem(coupleId, item);
  }

  void _showItemOptions(BuildContext context, BucketItem item) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final isDone = item.status == BucketStatus.done;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              if (item.note != null) ...[
                const SizedBox(height: 6),
                Text(item.note!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
              ],
              const SizedBox(height: 20),
              if (!isDone)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('✓', style: TextStyle(fontSize: 22)),
                  title: const Text('Mark as done',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    HapticFeedback.lightImpact();
                    await ref
                        .read(firestoreServiceProvider)
                        .updateBucketStatus(coupleId, item.id, BucketStatus.done);
                  },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh_rounded,
                      color: AppColors.textSecondary),
                  title: const Text('Mark as not done',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await ref
                        .read(firestoreServiceProvider)
                        .updateBucketStatus(
                            coupleId, item.id, BucketStatus.someday);
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.rose),
                title: const Text('Remove',
                    style: TextStyle(color: AppColors.rose)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await ref
                      .read(firestoreServiceProvider)
                      .deleteBucketItem(coupleId, item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final itemsAsync = ref.watch(bucketListProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Library background (full screen)
          const Positioned.fill(
            child: CustomPaint(painter: _LibraryPainter()),
          ),

          // Warm desk-surface vignette at bottom
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC1C1007)],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'The Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Book pile
                Expanded(
                  child: itemsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.rose)),
                    error: (e, _) => Center(
                        child: Text('$e',
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                    data: (items) {
                      // Detect newly added books
                      _onItemsUpdated(items);

                      final active = items
                          .where((i) => i.status != BucketStatus.done)
                          .toList();
                      final done = items
                          .where((i) => i.status == BucketStatus.done)
                          .toList();

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📚',
                                  style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 16),
                              const Text('The shelves are empty',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text('Add your first dream below ♡',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (active.isNotEmpty) ...[
                              // Active books — newest on top (reversed)
                              ...active.reversed.map((item) => _BookWidget(
                                    key: ValueKey(item.id),
                                    item: item,
                                    isDone: false,
                                    isNew: item.id == _animatingId,
                                    onTap: () => _showItemOptions(context, item),
                                  )),
                            ],

                            if (done.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              // Divider label
                              Row(children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withValues(alpha: 0.12))),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('COMPLETED',
                                      style: TextStyle(
                                          color: Colors.amber.shade400,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white.withValues(alpha: 0.12))),
                              ]),
                              const SizedBox(height: 16),
                              ...done.reversed.map((item) => _BookWidget(
                                    key: ValueKey('done_${item.id}'),
                                    item: item,
                                    isDone: true,
                                    isNew: false,
                                    onTap: () => _showItemOptions(context, item),
                                  )),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Add book input
                Container(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1007).withValues(alpha: 0.95),
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'A new dream for the shelf…',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 14),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.07),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _addItem,
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accent, AppColors.coral],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single book widget ─────────────────────────────────────────────────────

class _BookWidget extends StatelessWidget {
  final BucketItem item;
  final bool isDone;
  final bool isNew;
  final VoidCallback onTap;

  const _BookWidget({
    super.key,
    required this.item,
    required this.isDone,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final props = _BookProps.fromId(item.id);
    final baseColor = isDone
        ? Color.lerp(props.color, Colors.grey, 0.55)!
        : props.color;

    Widget book = LayoutBuilder(
      builder: (ctx, constraints) {
        final bookWidth = constraints.maxWidth * props.widthFraction;
        return Center(
          child: Transform.translate(
            offset: Offset(props.xOffset, 0),
            child: Transform.rotate(
              angle: props.rotationDeg * math.pi / 180,
              child: _Spine(
                width: bookWidth,
                thickness: props.thickness,
                color: baseColor,
                title: item.title,
                isDone: isDone,
              ),
            ),
          ),
        );
      },
    );

    book = GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(height: props.thickness + 8, child: book),
      ),
    );

    if (isNew) {
      return book
          .animate()
          .slideY(
            begin: -4,
            duration: 750.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 150.ms);
    }
    return book;
  }
}

class _Spine extends StatelessWidget {
  final double width;
  final double thickness;
  final Color color;
  final String title;
  final bool isDone;

  const _Spine({
    required this.width,
    required this.thickness,
    required this.color,
    required this.title,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.18)!;
    final dark = Color.lerp(color, Colors.black, 0.35)!;

    return Container(
      width: width,
      height: thickness,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [light, color, dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(0, 5),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top highlight band
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          // Bottom shadow band
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
                height: 3,
                color: Colors.black.withValues(alpha: 0.4)),
          ),
          // Thin accent stripe (1/5 from left)
          Positioned(
            left: width * 0.12,
            top: 4,
            bottom: 4,
            child: Container(
              width: 3,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          // Title text
          Padding(
            padding: EdgeInsets.fromLTRB(
                width * 0.2, 0, isDone ? 32 : 12, 0),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isDone ? 0.45 : 0.92),
                  fontSize: thickness > 40 ? 13.5 : 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  shadows: const [
                    Shadow(
                        color: Colors.black54,
                        blurRadius: 3,
                        offset: Offset(0, 1)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Done checkmark
          if (isDone)
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  '✓',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          color: Colors.amber.shade900.withValues(alpha: 0.6),
                          blurRadius: 4),
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
