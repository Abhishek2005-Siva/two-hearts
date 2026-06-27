import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class BucketListScreen extends ConsumerStatefulWidget {
  const BucketListScreen({super.key});

  @override
  ConsumerState<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends ConsumerState<BucketListScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late AnimationController _cloudCtrl;

  @override
  void initState() {
    super.initState();
    _cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _cloudCtrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _ctrl.clear();
    HapticFeedback.lightImpact();
    await ref.read(firestoreServiceProvider).addBucketItem(
      coupleId,
      BucketItem(
        id: const Uuid().v4(),
        title: title,
        createdAt: DateTime.now(),
        addedBy: uid,
      ),
    );
    // Scroll to bottom after adding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleDone(BucketItem item) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    HapticFeedback.selectionClick();
    final next = item.status == BucketStatus.done
        ? BucketStatus.someday
        : BucketStatus.done;
    await ref
        .read(firestoreServiceProvider)
        .updateBucketStatus(coupleId, item.id, next);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(bucketListProvider).valueOrNull ?? [];
    final accent = ref.watch(accentColorProvider);
    final doneCount = items.where((i) => i.status == BucketStatus.done).length;
    final size = MediaQuery.of(context).size;

    // Active items shown top of ladder, done items at bottom
    final active = items.where((i) => i.status != BucketStatus.done).toList();
    final done = items.where((i) => i.status == BucketStatus.done).toList();
    final all = [...active, ...done];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Sky gradient background ────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A4E),   // deep midnight
                  Color(0xFF0D0D2B),
                  Color(0xFF08081A),
                ],
              ),
            ),
          ),

          // ── Animated floating clouds ───────────────────────────────────
          AnimatedBuilder(
            animation: _cloudCtrl,
            builder: (_, _) {
              final t = _cloudCtrl.value;
              return Stack(
                children: [
                  _Cloud(x: (-0.3 + t * 1.3) % 1.0, y: 0.08, opacity: 0.18, scale: 1.4, w: size.width),
                  _Cloud(x: (0.6 + t * 0.8) % 1.0, y: 0.15, opacity: 0.12, scale: 1.0, w: size.width),
                  _Cloud(x: (0.1 + t * 1.1) % 1.0, y: 0.24, opacity: 0.1, scale: 0.8, w: size.width),
                  _Cloud(x: (0.8 + t * 0.9) % 1.0, y: 0.32, opacity: 0.08, scale: 1.2, w: size.width),
                  _Cloud(x: (-0.1 + t * 0.7) % 1.0, y: 0.42, opacity: 0.07, scale: 0.9, w: size.width),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bucket List 🪜',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            if (items.isNotEmpty)
                              Text(
                                '$doneCount of ${items.length} climbed',
                                style: TextStyle(
                                    color: accent, fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Add input pinned at top ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5),
                          ),
                          child: TextField(
                            controller: _ctrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a dream to your ladder…',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => _add(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _add,
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(colors: [accent, AppColors.coral]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 10,
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

                // ── Ladder scroll area ────────────────────────────────────
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌟',
                                  style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 16),
                              Text(
                                'Your ladder awaits',
                                style: TextStyle(
                                    color: accent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add your first dream above\nand start climbing together ♡',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 14, height: 1.6),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
                          child: _LadderWidget(
                            items: all,
                            accent: accent,
                            activeCount: active.length,
                            onToggle: _toggleDone,
                          ),
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

// ── Cloud widget ──────────────────────────────────────────────────────────

class _Cloud extends StatelessWidget {
  final double x; // 0..1 fraction of width
  final double y; // 0..1 fraction of height
  final double opacity;
  final double scale;
  final double w;

  const _Cloud({
    required this.x,
    required this.y,
    required this.opacity,
    required this.scale,
    required this.w,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Positioned(
      left: x * w - 80,
      top: y * h,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: const _CloudShape(),
        ),
      ),
    );
  }
}

class _CloudShape extends StatelessWidget {
  const _CloudShape();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 60,
      child: CustomPaint(painter: _CloudPainter()),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    // Draw a simple cloud from overlapping circles
    final circles = [
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.65, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.95, size.height * 0.6),
    ];
    final radii = [28.0, 36.0, 38.0, 30.0, 24.0, 22.0];
    for (int i = 0; i < circles.length; i++) {
      canvas.drawCircle(circles[i], radii[i], paint);
    }
    // Fill bottom gap
    canvas.drawRect(
      Rect.fromLTRB(
        circles.first.dx - radii.first,
        size.height * 0.55,
        circles.last.dx + radii.last,
        size.height,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CloudPainter _) => false;
}

// ── Ladder widget ─────────────────────────────────────────────────────────

class _LadderWidget extends StatelessWidget {
  final List<BucketItem> items;
  final Color accent;
  final int activeCount;
  final Future<void> Function(BucketItem) onToggle;

  const _LadderWidget({
    required this.items,
    required this.accent,
    required this.activeCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Ladder rails sit centered; rungs connect them
    const railWidth = 6.0;
    const railGap = 130.0; // gap between left and right rails
    const stepHeight = 90.0;
    final totalHeight = items.length * stepHeight + 60;

    return Center(
      child: SizedBox(
        width: double.infinity,
        height: max(totalHeight, 300),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Left rail
            Positioned(
              left: MediaQuery.of(context).size.width / 2 - railGap / 2 - railWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(
                width: railWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.3),
                      accent.withValues(alpha: 0.8),
                      accent.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(railWidth),
                ),
              ),
            ),
            // Right rail
            Positioned(
              left: MediaQuery.of(context).size.width / 2 + railGap / 2 - railWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(
                width: railWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.3),
                      accent.withValues(alpha: 0.8),
                      accent.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(railWidth),
                ),
              ),
            ),

            // Steps (rungs + cards)
            ...List.generate(items.length, (i) {
              final item = items[i];
              final isDone = item.status == BucketStatus.done;
              final topOffset = i * stepHeight + 20.0;
              final stepNum = isDone ? null : (activeCount - (i < activeCount ? i : 0));

              return Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                child: _LadderStep(
                  item: item,
                  stepNumber: stepNum,
                  isDone: isDone,
                  accent: accent,
                  railGap: railGap,
                  onToggle: () => onToggle(item),
                ).animate().fadeIn(
                  delay: Duration(milliseconds: i * 60),
                  duration: const Duration(milliseconds: 300),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LadderStep extends StatelessWidget {
  final BucketItem item;
  final int? stepNumber;
  final bool isDone;
  final Color accent;
  final double railGap;
  final VoidCallback onToggle;

  const _LadderStep({
    required this.item,
    this.stepNumber,
    required this.isDone,
    required this.accent,
    required this.railGap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The rung (horizontal bar)
        Container(
          height: 6,
          margin: EdgeInsets.symmetric(
            horizontal: (MediaQuery.of(context).size.width - railGap) / 2 - 3,
          ),
          decoration: BoxDecoration(
            color: isDone
                ? accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 6),
        // Step card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDone
                    ? accent.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDone
                      ? accent.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Step number / check
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDone
                          ? LinearGradient(colors: [accent, AppColors.coral])
                          : null,
                      color: isDone ? null : Colors.white.withValues(alpha: 0.1),
                      border: isDone
                          ? null
                          : Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.0),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : Text(
                              stepNumber != null ? '$stepNumber' : '✓',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: isDone
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Icon(
                    isDone
                        ? Icons.redo_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isDone
                        ? Colors.white.withValues(alpha: 0.3)
                        : accent.withValues(alpha: 0.6),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
