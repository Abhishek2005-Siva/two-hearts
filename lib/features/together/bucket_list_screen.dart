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

// 4 visual styles — derived from id hash
enum _BookStyle { solid, twoTone, stripe, embossed }

class _BookProps {
  final Color color;
  final Color accentBand; // secondary color band
  final double widthFraction; // 0.55 – 0.92
  final double thickness; // 42 – 78 px
  final double rotationDeg; // –4 to +4 degrees
  final double xOffset; // –14 to +14 px
  final _BookStyle style;

  const _BookProps({
    required this.color,
    required this.accentBand,
    required this.widthFraction,
    required this.thickness,
    required this.rotationDeg,
    required this.xOffset,
    required this.style,
  });

  factory _BookProps.fromId(String id) {
    int h = id.codeUnits.fold(0, (int a, int c) => (a * 31 + c) & 0x7FFFFFFF);
    int next() {
      h = (h * 1664525 + 1013904223) & 0x7FFFFFFF;
      return h;
    }

    final ci = next() % _kBookColors.length;
    final ci2 = (ci + 3 + next() % 4) % _kBookColors.length;
    final wf = 0.55 + (next() % 370) / 1000.0;
    final th = 42.0 + (next() % 37).toDouble();
    final rot = ((next() % 80) - 40) / 10.0;
    final xOff = ((next() % 29) - 14).toDouble();
    final styleIdx = next() % 4;

    return _BookProps(
      color: _kBookColors[ci],
      accentBand: _kBookColors[ci2],
      widthFraction: wf.clamp(0.55, 0.92),
      thickness: th,
      rotationDeg: rot,
      xOffset: xOff,
      style: _BookStyle.values[styleIdx],
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

    // Amber lamp glow from top
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
    final shelfPositions = [
      size.height * 0.26,
      size.height * 0.52,
      size.height * 0.78,
    ];
    for (final y in shelfPositions) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 11),
        Paint()..color = const Color(0xFF3A2510),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 2),
        Paint()..color = const Color(0xFF6A4520).withValues(alpha: 0.6),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, y + 11, size.width, 10),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, y + 11, size.width, 10)),
      );
      _drawShelfBooks(canvas, size.width, y - 55, 55);
    }
  }

  void _drawShelfBooks(
      Canvas canvas, double width, double top, double height) {
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
  String? _animatingId;
  String? _throwingId;
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
    _knownIds = items.map((i) => i.id).toSet();
    if (newId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _animatingId = newId);
          Future.delayed(const Duration(milliseconds: 900),
              () { if (mounted) setState(() => _animatingId = null); });
        }
      });
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    setState(() => _throwingId = item.id);
                    await Future.delayed(const Duration(milliseconds: 500));
                    await ref.read(firestoreServiceProvider).updateBucketStatus(
                        coupleId, item.id, BucketStatus.done);
                    if (mounted) setState(() => _throwingId = null);
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
                    await ref.read(firestoreServiceProvider).updateBucketStatus(
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
          const Positioned.fill(
              child: CustomPaint(painter: _LibraryPainter())),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 120,
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
                        child: Text('The Library',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),

                // Book pile
                Expanded(
                  child: itemsAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.rose)),
                    error: (e, _) => Center(
                        child: Text('$e',
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                    data: (items) {
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
                                      color: Colors.white
                                          .withValues(alpha: 0.4),
                                      fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (active.isNotEmpty)
                              _ShelfRow(
                                items: active.reversed.toList(),
                                animatingId: _animatingId,
                                throwingId: _throwingId,
                                isDone: false,
                                onTap: (item) => _showItemOptions(context, item),
                              ),

                            if (done.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              Row(children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.12))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text('COMPLETED',
                                      style: TextStyle(
                                          color: Colors.amber.shade400,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.12))),
                              ]),
                              const SizedBox(height: 16),
                              _ShelfRow(
                                items: done.reversed.toList(),
                                animatingId: null,
                                throwingId: null,
                                isDone: true,
                                onTap: (item) => _showItemOptions(context, item),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Input
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16,
                      MediaQuery.of(context).padding.bottom + 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1007).withValues(alpha: 0.95),
                    border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08))),
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
                                color:
                                    Colors.white.withValues(alpha: 0.35),
                                fontSize: 14),
                            filled: true,
                            fillColor:
                                Colors.white.withValues(alpha: 0.07),
                            contentPadding:
                                const EdgeInsets.symmetric(
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
                                colors: [accent, AppColors.coral]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      accent.withValues(alpha: 0.4),
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

// ── Shelf row — books standing side-by-side, no gaps ──────────────────────

class _ShelfRow extends StatelessWidget {
  final List<BucketItem> items;
  final String? animatingId;
  final String? throwingId;
  final bool isDone;
  final void Function(BucketItem) onTap;

  const _ShelfRow({
    required this.items,
    required this.animatingId,
    required this.throwingId,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final props = _BookProps.fromId(item.id);
          // Book stands upright: thickness = width, heightFraction-derived height
          final bookW = props.thickness;
          final bookH = 120.0 + (props.widthFraction - 0.55) / (0.92 - 0.55) * 60.0;

          Widget book = GestureDetector(
            onTap: () => onTap(item),
            child: _BookBody(
              width: bookW,
              height: bookH,
              color: isDone
                  ? Color.lerp(props.color, Colors.grey, 0.55)!
                  : props.color,
              accentBand: isDone ? Colors.grey.shade600 : props.accentBand,
              style: props.style,
              title: item.title,
              isDone: isDone,
            ),
          );

          if (throwingId == item.id) {
            book = book
                .animate()
                .slideX(begin: 0, end: 2.5, duration: 480.ms, curve: Curves.easeIn)
                .rotate(begin: 0, end: -0.12, duration: 480.ms)
                .fadeOut(begin: 1.0, duration: 480.ms, curve: Curves.easeIn);
          } else if (animatingId == item.id) {
            book = book
                .animate()
                .slideY(begin: -4, duration: 750.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 150.ms);
          }

          return book;
        }).toList(),
      ),
    );
  }
}

// ── Book body — renders the spine face with one of 4 visual styles ─────────

class _BookBody extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final Color accentBand;
  final _BookStyle style;
  final String title;
  final bool isDone;

  const _BookBody({
    required this.width,
    required this.height,
    required this.color,
    required this.accentBand,
    required this.style,
    required this.title,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _BookPainter(
        color: color,
        accentBand: accentBand,
        style: style,
        title: title,
        isDone: isDone,
        spineWidth: width,
      ),
    );
  }
}

class _BookPainter extends CustomPainter {
  final Color color;
  final Color accentBand;
  final _BookStyle style;
  final String title;
  final bool isDone;
  final double spineWidth;

  const _BookPainter({
    required this.color,
    required this.accentBand,
    required this.style,
    required this.title,
    required this.isDone,
    required this.spineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final light = Color.lerp(color, Colors.white, 0.18)!;
    final dark = Color.lerp(color, Colors.black, 0.38)!;

    // ── Base gradient — left (spine face) to right edge ────────────────────
    final bodyRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          colors: [light, color, dark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bodyRect),
    );

    // ── Page-edge strip at bottom (pages seen from above) ──────────────────
    final pageH = 6.0;
    canvas.drawRect(
      Rect.fromLTWH(0, h - pageH, w, pageH),
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFF5EDD8).withValues(alpha: 0.9),
            const Color(0xFFE8D8C0).withValues(alpha: 0.9),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, h - pageH, w, pageH)),
    );
    // Fine vertical lines to simulate page edges
    final linePaint = Paint()
      ..color = const Color(0xFFD4C4A8).withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (double x = 2; x < w - 2; x += 2.5) {
      canvas.drawLine(Offset(x, h - pageH), Offset(x, h - 0.5), linePaint);
    }

    // ── Style-specific decoration ──────────────────────────────────────────
    switch (style) {
      case _BookStyle.solid:
        _paintSolid(canvas, w, h);
      case _BookStyle.twoTone:
        _paintTwoTone(canvas, w, h);
      case _BookStyle.stripe:
        _paintStripe(canvas, w, h);
      case _BookStyle.embossed:
        _paintEmbossed(canvas, w, h);
    }

    // ── Title text — rotated 90° to read bottom-to-top along spine ─────────
    _paintTitle(canvas, w, h);

    // ── Done checkmark near top ─────────────────────────────────────────────
    if (isDone) {
      final tp = TextPainter(
        text: TextSpan(
          text: '✓',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade300,
            shadows: [
              Shadow(
                  color: Colors.amber.shade900.withValues(alpha: 0.6),
                  blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, 6));
    }

    // ── Right-edge shadow (between books) ──────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(w - 6, 0, 6, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTWH(w - 6, 0, 6, h)),
    );
  }

  // Solid — thin accent stripe at top
  void _paintSolid(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 3),
        Paint()..color = Colors.white.withValues(alpha: 0.15));
    // Accent band across top quarter
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.18),
      Paint()..color = accentBand.withValues(alpha: 0.55),
    );
  }

  // Two-tone — top 35% accent color, bottom main color
  void _paintTwoTone(Canvas canvas, double w, double h) {
    final splitY = h * 0.35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, splitY),
        const Radius.circular(2),
      ),
      Paint()..color = accentBand.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, splitY - 1, w, 2),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  // Stripe — diagonal accent stripe across the spine face
  void _paintStripe(Canvas canvas, double w, double h) {
    final stripeW = w * 0.5;
    final path = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(stripeW, h * 0.25)
      ..lineTo(stripeW, h * 0.65)
      ..lineTo(0, h * 0.65)
      ..close();
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(2)));
    canvas.drawPath(path, Paint()..color = accentBand.withValues(alpha: 0.4));
    canvas.restore();
  }

  // Embossed — small centered plate
  void _paintEmbossed(Canvas canvas, double w, double h) {
    final plateH = h * 0.4;
    final plateW = w * 0.7;
    final plateRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.45),
          width: plateW,
          height: plateH),
      const Radius.circular(3),
    );
    canvas.drawRRect(
        plateRect,
        Paint()
          ..color = Color.lerp(color, Colors.white, 0.22)!.withValues(alpha: 0.9));
    canvas.drawRRect(
        plateRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 2),
        Paint()..color = Colors.white.withValues(alpha: 0.15));
  }

  void _paintTitle(Canvas canvas, double w, double h) {
    final isDoneOpacity = isDone ? 0.45 : 0.92;
    final fontSize = spineWidth > 52 ? 12.0 : 10.0;
    // Available length for text = book height minus top/bottom pads
    final topPad = isDone ? 22.0 : 10.0;
    final bottomPad = 14.0; // above page-edge strip
    final maxLen = h - topPad - bottomPad;

    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: isDoneOpacity),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLen);

    // Rotate canvas: translate to bottom-left of text area, rotate -90°
    canvas.save();
    canvas.translate(w / 2, h - bottomPad);
    canvas.rotate(-math.pi / 2);
    tp.paint(canvas, Offset(-math.min(tp.width, maxLen) / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BookPainter old) =>
      old.color != color ||
      old.style != style ||
      old.title != title ||
      old.isDone != isDone;
}
