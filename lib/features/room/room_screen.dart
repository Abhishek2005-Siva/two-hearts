import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/character_avatar.dart';

// Book colors used in shelf painting
const List<Color> _kBookColors = [
  Color(0xFF8B4513),
  Color(0xFF2E6B3E),
  Color(0xFF1A3A6B),
  Color(0xFF7A2B5F),
];

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with TickerProviderStateMixin {
  bool _heartVisible = false;
  late AnimationController _heartCtrl;
  double _heartX = 0.5;
  String? _lastSignalId; // dedup — never show same signal twice

  // Partner mood overlay
  MoodType? _partnerMoodToShow;
  bool _partnerMoodVisible = false;
  MoodType? _lastKnownPartnerMood;

  // New: twinkle animation and day/night timer
  late AnimationController _twinkleCtrl;
  Timer? _timeTimer;

  /// Returns 0.0 (full day) → 1.0 (full night) based on current hour.
  double get _nightness {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 18) return 0.0;
    if (hour >= 18 && hour < 21) return (hour - 18) / 3.0;
    if (hour >= 21 || hour < 5) return 1.0;
    // hour >= 5 && hour < 6: ramp from 1.0 to 0.0
    return 1.0 - ((hour - 5) / 1.0);
  }

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3));
    _twinkleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _timeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _listenSignals();
  }

  void _listenSignals() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId == null) return;
      ref.read(firestoreServiceProvider).watchSignals(coupleId).listen((snap) {
        if (!mounted) return;
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final docId = doc.id;
          if (docId == _lastSignalId) return; // already shown this signal
          final data = doc.data() as Map<String, dynamic>;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && data['fromUid'] != uid) {
            _lastSignalId = docId;
            final type = data['type'] as String? ?? 'thinkingOfYou';
            final message = data['message'] as String?;
            _showSignal(type: type, message: message);
          }
        }
      });
    });
  }

  void _showSignal({required String type, String? message}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _heartVisible = true;
      _heartX = 0.3 + (0.4 * (DateTime.now().millisecond / 1000));
    });
    _heartCtrl.forward(from: 0);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _heartVisible = false);
    });

    final (emoji, text) = switch (type) {
      'goodMorning' => ('☀️', 'Good morning from your person!'),
      'goodNight' => ('🌙', 'Good night — sweet dreams ♡'),
      'gratitude' => ('🙏', 'Your person is grateful for you today ♡'),
      _ => ('♡', message ?? 'Thinking of you ♡'),
    };

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Text('$emoji  ', style: const TextStyle(fontSize: 18)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  void _showPartnerMoodPopup(MoodType mood) {
    setState(() {
      _partnerMoodToShow = mood;
      _partnerMoodVisible = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _partnerMoodVisible = false);
    });
  }

  void _sendThinkingOfYou() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('♡',
                  style: TextStyle(fontSize: 52, color: AppColors.rose)),
              const SizedBox(height: 12),
              Text('Thinking Of You',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('Send a little love to their screen',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                maxLength: 80,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Add a note (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Send ♡',
                onTap: () async {
                  final msg = ctrl.text.trim();
                  Navigator.pop(ctx);
                  await ref
                      .read(firestoreServiceProvider)
                      .sendThinkingOfYou(
                    coupleId,
                    message: msg.isEmpty ? null : msg,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('♡ Sent to your person'),
                      backgroundColor: AppColors.bgCard,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.all(16),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoodPicker() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final accent = ref.read(accentColorProvider);
    final currentMood = ref
        .read(moodsProvider)
        .valueOrNull
        ?.where((m) => m.uid == FirebaseAuth.instance.currentUser?.uid)
        .firstOrNull
        ?.mood;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(sheetCtx).viewInsets.bottom +
              MediaQuery.of(sheetCtx).padding.bottom +
              24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border:
              Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('How are you feeling?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Your partner will see your vibe ♡',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: MoodType.values.map((mood) {
                final selected = currentMood == mood;
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await ref
                        .read(firestoreServiceProvider)
                        .setMood(coupleId, mood);
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(colors: [
                              accent.withValues(alpha: 0.3),
                              AppColors.coral.withValues(alpha: 0.2)
                            ])
                          : null,
                      color:
                          selected ? null : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? accent
                            : AppColors.divider,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood.emoji,
                            style:
                                TextStyle(fontSize: selected ? 22 : 20)),
                        const SizedBox(width: 6),
                        Text(mood.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const _SettingsSheet(),
      ),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _twinkleCtrl.dispose();
    _timeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final moods = ref.watch(moodsProvider).valueOrNull ?? [];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final myMood =
        moods.where((m) => m.uid == myUid).firstOrNull?.mood;
    final partnerMoodEntry =
        moods.where((m) => m.uid != myUid).firstOrNull;
    final partnerMood = partnerMoodEntry?.mood;

    // Partner mood — show popup when it changes
    if (partnerMood != null &&
        partnerMood != _lastKnownPartnerMood) {
      _lastKnownPartnerMood = partnerMood;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPartnerMoodPopup(partnerMood);
      });
    }

    final nightness = _nightness;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Room background — photo behind the animated scene
          Positioned.fill(
            child: Image.asset(
              'assets/images/main_page_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Animated overlays (window, stars, curtains, fairy lights)
          AnimatedBuilder(
            animation: _twinkleCtrl,
            builder: (_, _) {
              return CustomPaint(
                size: size,
                painter: _RoomScenePainter(
                  nightness: nightness,
                  twinkle: _twinkleCtrl.value,
                  accent: accent,
                ),
              );
            },
          ),

          // 2. Main UI layout
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      const TwoHeartsLogo(size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          couple != null
                              ? '${me?.displayName.split(' ').first ?? '?'} & ${partner?.displayName.split(' ').first ?? '?'}'
                              : 'Two Hearts',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: nightness > 0.5
                                    ? AppColors.textPrimary
                                    : const Color(0xFF3A1A0A),
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.tune_rounded,
                            color: nightness > 0.5
                                ? AppColors.textSecondary
                                : const Color(0xFF7A4020)),
                        onPressed: () => _showSettings(context),
                      ),
                    ],
                  ),
                ),

                // Characters area — pushed to the lower portion
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Characters row
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // My character
                            GestureDetector(
                              onTap: _showMoodPicker,
                              child: _CharCol(
                                user: me,
                                color: accent,
                                isMe: true,
                                mood: myMood,
                                showTapHint: true,
                              ),
                            ),

                            // Center logo
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const TwoHeartsLogo(size: 26),
                                const SizedBox(height: 4),
                                Text(
                                  'together',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: nightness > 0.5
                                          ? accent
                                          : accent
                                              .withValues(alpha: 0.8),
                                      letterSpacing: 1.2),
                                ),
                              ],
                            ),

                            // Partner character with mood popup
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _CharCol(
                                  user: partner,
                                  color: AppColors.lavender,
                                  isMe: false,
                                  mood: partnerMood,
                                ),
                                if (_partnerMoodVisible &&
                                    _partnerMoodToShow != null)
                                  Positioned(
                                    top: -14,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _MoodPopup(
                                          mood: _partnerMoodToShow!),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08),

                      const SizedBox(height: 18),

                      // "Thinking of You" pill
                      _ThinkingOfYouPill(
                        accent: accent,
                        onTap: _sendThinkingOfYou,
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 16),

                      // Polaroid memory strip
                      if (memories.isNotEmpty)
                        _PolaroidStrip(
                          memories: memories,
                          nightness: nightness,
                        ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating heart animation (unchanged)
          if (_heartVisible)
            AnimatedBuilder(
              animation: _heartCtrl,
              builder: (_, _) {
                final t = _heartCtrl.value;
                return Positioned(
                  left: size.width * _heartX,
                  bottom: 100 + 300 * t,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.0 + t * 0.5,
                      child: const Text('♡',
                          style: TextStyle(
                              fontSize: 40, color: AppColors.rose)),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Room Scene Painter ────────────────────────────────────────────────────

class _RoomScenePainter extends CustomPainter {
  final double nightness;
  final double twinkle;
  final Color accent;

  const _RoomScenePainter({
    required this.nightness,
    required this.twinkle,
    required this.accent,
  });

  @override
  bool shouldRepaint(_RoomScenePainter old) =>
      old.nightness != nightness ||
      old.twinkle != twinkle ||
      old.accent != accent;

  Color _lerp(Color a, Color b) => Color.lerp(a, b, nightness)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();

    final floorTop = h * 0.78;

    // ── 3. WINDOW (top-right) ─────────────────────────────────────────────
    final winLeft = w * 0.60;
    final winTop = h * 0.04;
    final winWidth = w * 0.35;
    final winHeight = h * 0.32;
    final winRect =
        Rect.fromLTWH(winLeft, winTop, winWidth, winHeight);

    // Sky gradient inside window
    final skyTopDay = const Color(0xFF87CEEB);
    final skyTopNight = const Color(0xFF0A0A2A);
    final skyBotDay = const Color(0xFFB0D9F0);
    final skyBotNight = const Color(0xFF050510);

    final skyGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(skyTopDay, skyTopNight, nightness)!,
        Color.lerp(skyBotDay, skyBotNight, nightness)!,
      ],
    );
    paint
      ..shader = skyGrad.createShader(winRect)
      ..style = PaintingStyle.fill;
    canvas.drawRect(winRect, paint);
    paint.shader = null;

    // Stars at night
    if (nightness > 0.3) {
      final rng = math.Random(42);
      final starPaint = Paint()
        ..color =
            Colors.white.withValues(alpha: nightness * 0.9)
        ..style = PaintingStyle.fill;
      for (int i = 0; i < 15; i++) {
        final sx = winLeft + rng.nextDouble() * winWidth;
        final sy = winTop + rng.nextDouble() * winHeight * 0.7;
        final sr = 0.8 + rng.nextDouble() * 1.2;
        canvas.drawCircle(Offset(sx, sy), sr, starPaint);
      }
    }

    // Moon at night
    if (nightness > 0.4) {
      final moonPaint = Paint()
        ..color = Colors.white.withValues(alpha: nightness * 0.95)
        ..style = PaintingStyle.fill;
      final moonX = winLeft + winWidth * 0.78;
      final moonY = winTop + winHeight * 0.18;
      canvas.drawCircle(Offset(moonX, moonY), 9 * nightness, moonPaint);
      // Crescent cutout
      final cutPaint = Paint()
        ..color = Color.lerp(
            skyTopNight, const Color(0xFF0A0A2A), nightness)!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(moonX + 5, moonY - 3), 7 * nightness, cutPaint);
    }

    // Day glow rays from top of window
    if (nightness < 0.8) {
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: (1 - nightness) * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(winLeft + winWidth / 2, winTop),
              width: winWidth * 0.8,
              height: winHeight * 0.5),
          glowPaint);
      glowPaint.maskFilter = null;
    }

    // Night blue glow
    if (nightness > 0.2) {
      final nightGlowPaint = Paint()
        ..color = const Color(0xFF1040A0)
            .withValues(alpha: nightness * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
      canvas.drawRect(winRect, nightGlowPaint);
      nightGlowPaint.maskFilter = null;
    }

    // Window frame
    final frameColor =
        _lerp(const Color(0xFF8B5E3C), const Color(0xFF4A2A10));
    paint
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawRect(winRect, paint);

    // Cross dividers
    paint.strokeWidth = 2.5;
    canvas.drawLine(
        Offset(winLeft + winWidth / 2, winTop),
        Offset(winLeft + winWidth / 2, winTop + winHeight),
        paint);
    canvas.drawLine(
        Offset(winLeft, winTop + winHeight / 2),
        Offset(winLeft + winWidth, winTop + winHeight / 2),
        paint);
    paint.style = PaintingStyle.fill;

    // Window sill
    paint.color =
        _lerp(const Color(0xFFA07040), const Color(0xFF3A1A08));
    canvas.drawRect(
        Rect.fromLTWH(
            winLeft - 4, winTop + winHeight, winWidth + 8, 8),
        paint);

    // ── 4. SHELF (top-left) ───────────────────────────────────────────────
    final shelfLeft = w * 0.04;
    final shelfY = h * 0.20;
    final shelfWidth = w * 0.40;
    const shelfH = 8.0;

    // Shadow below shelf
    final shelfShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRect(
        Rect.fromLTWH(shelfLeft, shelfY + shelfH, shelfWidth, 8),
        shelfShadowPaint);
    shelfShadowPaint.maskFilter = null;

    // Shelf plank
    paint.color =
        _lerp(const Color(0xFF8B5E3C), const Color(0xFF3A1A08));
    canvas.drawRect(
        Rect.fromLTWH(shelfLeft, shelfY, shelfWidth, shelfH), paint);

    // Books on shelf
    final bookBaseY = shelfY - 2;
    final bookHeights = [32.0, 40.0, 28.0, 36.0];
    double bookX = shelfLeft + 8;
    for (int i = 0; i < 4; i++) {
      final bh = bookHeights[i];
      final bw = 14.0 + i * 2;
      paint.color = _lerp(
          _kBookColors[i],
          Color.lerp(_kBookColors[i], Colors.black, 0.5)!);
      canvas.drawRect(
          Rect.fromLTWH(bookX, bookBaseY - bh, bw, bh), paint);
      // Book spine highlight
      paint.color = Colors.white.withValues(alpha: 0.1);
      canvas.drawRect(
          Rect.fromLTWH(bookX, bookBaseY - bh, 2, bh), paint);
      bookX += bw + 4;
    }

    // Small frame on shelf
    final frameX = shelfLeft + shelfWidth * 0.70;
    final frameYy = shelfY - 30.0;
    paint
      ..color = _lerp(const Color(0xFFC0904A), const Color(0xFF5A3010))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(
        Rect.fromLTWH(frameX, frameYy, 22, 28), paint);
    paint
      ..color =
          _lerp(const Color(0xFFD4E8C2), const Color(0xFF102008))
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(frameX + 2.5, frameYy + 2.5, 17, 23), paint);

    // ── 5. LAMP (left side) ───────────────────────────────────────────────
    final lampX = w * 0.12;
    final shadeTop = h * 0.40;
    final shadeH = h * 0.09;
    final poleBottom = floorTop;
    final poleTop = shadeTop + shadeH;

    // Amber glow at night
    if (nightness > 0.1) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFFB347)
            .withValues(alpha: nightness * 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(
          Offset(lampX, shadeTop + shadeH / 2),
          80 * nightness,
          glowPaint);
      glowPaint.maskFilter = null;
    }

    // Pole
    paint.color =
        _lerp(const Color(0xFF6B4020), const Color(0xFF2A100A));
    canvas.drawRect(
        Rect.fromLTWH(lampX - 3, poleTop, 6, poleBottom - poleTop),
        paint);

    // Shade (trapezoid)
    final shadePath = Path()
      ..moveTo(lampX - 22, shadeTop + shadeH)
      ..lineTo(lampX + 22, shadeTop + shadeH)
      ..lineTo(lampX + 14, shadeTop)
      ..lineTo(lampX - 14, shadeTop)
      ..close();
    paint.color = nightness > 0.5
        ? const Color(0xFFD4820A).withValues(alpha: 0.9)
        : _lerp(const Color(0xFFF0C080), const Color(0xFFD4820A));
    canvas.drawPath(shadePath, paint);

    // Shade border
    paint
      ..color = _lerp(const Color(0xFFB07030), const Color(0xFF7A4010))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(shadePath, paint);
    paint.style = PaintingStyle.fill;

    // Base
    paint.color =
        _lerp(const Color(0xFF6B4020), const Color(0xFF2A100A));
    canvas.drawRect(
        Rect.fromLTWH(lampX - 12, poleBottom - 8, 24, 8), paint);

    // ── 6. FAIRY LIGHTS ───────────────────────────────────────────────────
    const numBulbs = 12;
    const stringY = 0.04;
    final stringPaint = Paint()
      ..color = _lerp(const Color(0xFFCCBBAA), const Color(0xFF443322))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw string as quadratic bezier
    final strPath = Path();
    strPath.moveTo(0, h * stringY);
    strPath.quadraticBezierTo(
        w / 2, h * stringY + 18, w, h * stringY);
    canvas.drawPath(strPath, stringPaint);

    // Bulbs
    for (int i = 0; i < numBulbs; i++) {
      final t = i / (numBulbs - 1);
      // Follow the bezier: approximate with quadratic formula
      final bx = (1 - t) * (1 - t) * 0.0 +
          2 * (1 - t) * t * (w / 2) +
          t * t * w;
      final bCtrlY = h * stringY + 18;
      final by = (1 - t) * (1 - t) * (h * stringY) +
          2 * (1 - t) * t * bCtrlY +
          t * t * (h * stringY);

      final isFlicker = (i % 3 == 0);
      double glowAlpha;
      if (nightness < 0.1) {
        glowAlpha = 0;
      } else if (isFlicker) {
        // Twinkle: oscillate between dim and bright using twinkle value
        glowAlpha =
            nightness * (0.4 + 0.6 * (math.sin(twinkle * 2 * math.pi + i) * 0.5 + 0.5));
      } else {
        glowAlpha = nightness * 0.85;
      }

      // Bulb glow halo at night
      if (glowAlpha > 0.05) {
        final haloPaint = Paint()
          ..color = const Color(0xFFFFEE88)
              .withValues(alpha: glowAlpha * 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(bx, by + 5), 10, haloPaint);
        haloPaint.maskFilter = null;
      }

      // Bulb body
      final bulbPaint = Paint()
        ..color = nightness < 0.1
            ? const Color(0xFFDDCCAA)
            : Color.lerp(
                const Color(0xFFAA9988),
                const Color(0xFFFFEE44),
                glowAlpha)!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(bx, by + 5), 3.5, bulbPaint);
    }

    // ── 8. PLANT (bottom-left) ────────────────────────────────────────────
    final plantX = w * 0.08;
    final potBottom = floorTop - 2;
    final potH = h * 0.06;
    final potW = w * 0.08;
    final potTop = potBottom - potH;

    // Pot trapezoid
    final potPath = Path()
      ..moveTo(plantX - potW * 0.35, potTop)
      ..lineTo(plantX + potW * 0.35, potTop)
      ..lineTo(plantX + potW * 0.5, potBottom)
      ..lineTo(plantX - potW * 0.5, potBottom)
      ..close();
    paint.color =
        _lerp(const Color(0xFFB05C34), const Color(0xFF4A1A0A));
    canvas.drawPath(potPath, paint);

    // Pot rim
    paint
      ..color = _lerp(const Color(0xFFC87040), const Color(0xFF5A2010))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(potPath, paint);
    paint.style = PaintingStyle.fill;

    // Leaves
    final leafColor =
        _lerp(const Color(0xFF3A8A3A), const Color(0xFF1A4010));
    paint.color = leafColor;

    // Left leaf
    final leaf1 = Path()
      ..moveTo(plantX, potTop)
      ..quadraticBezierTo(
          plantX - w * 0.06, potTop - h * 0.06,
          plantX - w * 0.04, potTop - h * 0.11)
      ..quadraticBezierTo(
          plantX - w * 0.01, potTop - h * 0.06,
          plantX, potTop);
    canvas.drawPath(leaf1, paint);

    // Center leaf
    final leaf2 = Path()
      ..moveTo(plantX, potTop)
      ..quadraticBezierTo(
          plantX, potTop - h * 0.12,
          plantX + w * 0.01, potTop - h * 0.14)
      ..quadraticBezierTo(
          plantX + w * 0.02, potTop - h * 0.09,
          plantX, potTop);
    canvas.drawPath(leaf2, paint);

    // Right leaf
    final leaf3 = Path()
      ..moveTo(plantX, potTop)
      ..quadraticBezierTo(
          plantX + w * 0.06, potTop - h * 0.07,
          plantX + w * 0.05, potTop - h * 0.12)
      ..quadraticBezierTo(
          plantX + w * 0.01, potTop - h * 0.07,
          plantX, potTop);
    canvas.drawPath(leaf3, paint);

    // Leaf highlights
    paint.color =
        _lerp(const Color(0xFF5AB85A), const Color(0xFF2A6018))
            .withValues(alpha: 0.5);
    final leafHL1 = Path()
      ..moveTo(plantX - w * 0.01, potTop - h * 0.01)
      ..quadraticBezierTo(
          plantX - w * 0.04, potTop - h * 0.05,
          plantX - w * 0.035, potTop - h * 0.09);
    final leafStroke = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(leafHL1, leafStroke);

    // ── 9. RUG (floor center) ─────────────────────────────────────────────
    final rugCx = w * 0.50;
    final rugCy = floorTop + h * 0.06;
    final rugRx = w * 0.28;
    final rugRy = h * 0.04;

    paint.color = accent.withValues(alpha: 0.15);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rugCx, rugCy),
            width: rugRx * 2,
            height: rugRy * 2),
        paint);

    paint
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rugCx, rugCy),
            width: rugRx * 2,
            height: rugRy * 2),
        paint);

    // Inner oval pattern
    paint.color = accent.withValues(alpha: 0.10);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rugCx, rugCy),
            width: rugRx * 1.2,
            height: rugRy * 1.2),
        paint);
    paint.style = PaintingStyle.fill;
  }
}

// ── Mood Popup ────────────────────────────────────────────────────────────

class _MoodPopup extends StatelessWidget {
  final MoodType mood;
  const _MoodPopup({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mood.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(mood.label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.3);
  }
}

// ── Char Col ──────────────────────────────────────────────────────────────

class _CharCol extends StatelessWidget {
  final dynamic user;
  final Color color;
  final bool isMe;
  final MoodType? mood;
  final bool showTapHint;

  const _CharCol({
    this.user,
    required this.color,
    required this.isMe,
    this.mood,
    this.showTapHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        user?.displayName as String? ?? (isMe ? 'You' : '?');
    final gender = user?.gender as String?;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CharacterAvatar(color: color, name: name, size: 86, gender: gender),
            if (mood != null)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.divider, width: 0.5),
                  ),
                  child: Text(mood!.emoji,
                      style: const TextStyle(fontSize: 16)),
                ),
              ),
            if (showTapHint)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mood_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [color, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            name.split(' ').first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              shadows: [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showTapHint)
          Text('tap to set mood',
              style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.75),
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Thinking Of You Pill ──────────────────────────────────────────────────

class _ThinkingOfYouPill extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _ThinkingOfYouPill(
      {required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.75),
              AppColors.coral.withValues(alpha: 0.65),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('♡',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.1)),
            const SizedBox(width: 8),
            const Text(
              'Thinking of You',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Polaroid Strip ────────────────────────────────────────────────────────

class _PolaroidStrip extends StatelessWidget {
  final List<dynamic> memories;
  final double nightness;
  const _PolaroidStrip(
      {required this.memories, required this.nightness});

  @override
  Widget build(BuildContext context) {
    final items = memories.take(8).toList();
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: items.length + 1,
        itemBuilder: (ctx, i) {
          if (i < items.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _PolaroidCard(
                  memory: items[i], nightness: nightness),
            );
          }
          // "See all" tile
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => ctx.push('/memory'),
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.divider, width: 1),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        color: AppColors.textMuted, size: 22),
                    SizedBox(height: 6),
                    Text(
                      'See all',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Polaroid Card ─────────────────────────────────────────────────────────

class _PolaroidCard extends StatelessWidget {
  final dynamic memory;
  final double nightness;
  const _PolaroidCard(
      {required this.memory, required this.nightness});

  @override
  Widget build(BuildContext context) {
    final rotationRad =
        ((memory.id.hashCode % 16) - 8) / 100.0;
    final bgColor = Color.lerp(
        Colors.white, const Color(0xFFF5EAD8), nightness)!;
    final shadowOpacity = 0.15 + nightness * 0.25;

    return GestureDetector(
      onTap: () => context.push('/memory/${memory.id}'),
      child: Transform.rotate(
        angle: rotationRad,
        child: Container(
          width: 80,
          height: 100,
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: shadowOpacity),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: memory.imageUrl?.isNotEmpty == true
                ? CachedNetworkImage(
                    imageUrl: memory.imageUrl as String,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: const Color(0xFFDDCCBB)),
                    errorWidget: (_, _, _) => Container(
                      color: const Color(0xFFDDCCBB),
                      child: const Icon(Icons.image_outlined,
                          color: Colors.grey, size: 18),
                    ),
                  )
                : Container(
                    color: const Color(0xFFDDCCBB),
                    child: const Icon(Icons.image_outlined,
                        color: Colors.grey, size: 18),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Settings Sheet ────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).valueOrNull;
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Your colour',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kCoupleAccents.map((a) {
              final color = a['color'] as Color;
              final selected =
                  couple?.themeColor == color.toARGB32();
              return GestureDetector(
                onTap: () async {
                  if (couple != null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateCoupleTheme(
                            couple.id, color.toARGB32());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 12)
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 22)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/auth');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.divider, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded,
                      color: AppColors.textMuted, size: 20),
                  SizedBox(width: 12),
                  Text('Sign out',
                      style: TextStyle(
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
