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

// Book colors used in shelf painting

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
          // Only show if this signal was explicitly sent TO me,
          // or (legacy) it wasn't sent BY me.
          final toUid = data['toUid'] as String?;
          final isForMe = toUid != null ? toUid == uid : data['fromUid'] != uid;
          if (uid != null && isForMe) {
            _lastSignalId = docId;
            final type = data['type'] as String? ?? 'thinkingOfYou';
            final message = data['message'] as String?;
            _showSignal(type: type, message: message);
            // Delete so it never re-shows on app reopen
            ref.read(firestoreServiceProvider)
                .deleteSignal(coupleId, docId)
                .ignore();
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
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('♡', style: TextStyle(fontSize: 52, color: AppColors.rose)),
              const SizedBox(height: 12),
              Text('Thinking Of You', style: Theme.of(ctx).textTheme.titleLarge),
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
                  await ref.read(firestoreServiceProvider).sendThinkingOfYou(
                    coupleId,
                    message: msg.isEmpty ? null : msg,
                    toUid: partner?.uid,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, color: Colors.white),
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
    final name = user?.displayName as String? ?? (isMe ? 'You' : '?');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mood bubble (floats above the name)
        if (mood != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Text(mood!.emoji, style: const TextStyle(fontSize: 18)),
          )
        else
          const SizedBox(height: 30),

        // Name label
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
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              shadows: [Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2))],
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

// ── Scrapbook Memory Strip ────────────────────────────────────────────────

class _PolaroidStrip extends StatelessWidget {
  final List<dynamic> memories;
  final double nightness;
  const _PolaroidStrip({required this.memories, required this.nightness});

  @override
  Widget build(BuildContext context) {
    final items = memories.take(7).toList();
    // Warm cork/kraft background
    final boardColor = Color.lerp(
      const Color(0xFFEDD9B8), const Color(0xFFC8B898), nightness)!;

    return Container(
      height: 215,
      decoration: BoxDecoration(
        color: boardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle cork grain texture
          Positioned.fill(
            child: CustomPaint(painter: _CorkPainter(nightness: nightness)),
          ),
          // Scrollable photos
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 12),
            itemCount: items.length + 1,
            itemBuilder: (ctx, i) {
              if (i < items.length) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _PolaroidCard(
                      memory: items[i], index: i, nightness: nightness),
                );
              }
              // Handwritten sticky note at the end
              return Padding(
                padding: const EdgeInsets.only(right: 18, top: 8),
                child: GestureDetector(
                  onTap: () => ctx.push('/memory'),
                  child: _StickyNote(nightness: nightness),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Cork grain background painter
class _CorkPainter extends CustomPainter {
  final double nightness;
  const _CorkPainter({required this.nightness});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // fixed seed for stable look
    final dotColor = Color.lerp(
      const Color(0xFFD4B890), const Color(0xFFB09070), nightness)!;
    final paint = Paint()..color = dotColor.withValues(alpha: 0.35);
    // Scattered tiny dots to mimic cork texture
    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.8 + rng.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CorkPainter old) => old.nightness != nightness;
}

// ── Polaroid Card ─────────────────────────────────────────────────────────

// Each index gets a unique decoration combination
class _DecoScheme {
  final String primary;   // 'thumbtack' | 'tape' | 'clothespin'
  final Color primaryColor;
  final String? extra;    // optional extra deco: 'heart' | 'sparkle' | 'flower' | 'stamp' | 'doodle'
  final String? sideNote; // tiny handwritten-style label
  const _DecoScheme(this.primary, this.primaryColor, {this.extra, this.sideNote});
}

const _kDecoSchemes = [
  _DecoScheme('thumbtack', Color(0xFFE8735A), extra: 'heart'),           // 0 rose pin + heart
  _DecoScheme('tape', Color(0xFFB8D4C0), extra: 'sparkle'),              // 1 sage tape + sparkle
  _DecoScheme('thumbtack', Color(0xFF9B8FD4), extra: 'flower'),          // 2 lavender pin + flower
  _DecoScheme('tape', Color(0xFFE8C49A), extra: 'stamp'),                // 3 peach tape + stamp
  _DecoScheme('clothespin', Color(0xFF8FB4D4), extra: 'doodle'),         // 4 sky clothespin + doodle
  _DecoScheme('thumbtack', Color(0xFFD4849A), extra: 'heart'),           // 5 dusty pink pin + heart
  _DecoScheme('tape', Color(0xFFD4C4A0), extra: 'sparkle', sideNote: '♡'), // 6 kraft tape + note
];

class _PolaroidCard extends StatelessWidget {
  final dynamic memory;
  final int index;
  final double nightness;
  const _PolaroidCard(
      {required this.memory, required this.index, required this.nightness});

  @override
  Widget build(BuildContext context) {
    final angles = [-0.05, 0.04, -0.02, 0.06, -0.03, 0.05, -0.04];
    final angle = angles[index % angles.length];
    final bgColor = Color.lerp(const Color(0xFFFFFDF8), const Color(0xFFF5EDE0), nightness)!;
    final shadowOpacity = 0.22 + nightness * 0.18;
    final scheme = _kDecoSchemes[index % _kDecoSchemes.length];

    return GestureDetector(
      onTap: () => context.push('/memory/${memory.id}'),
      child: SizedBox(
        width: 118,
        height: 178,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Polaroid frame ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  height: 156,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: shadowOpacity),
                        blurRadius: 14,
                        offset: const Offset(2, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Photo area
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: memory.imageUrl?.isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: memory.imageUrl as String,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, _) => Container(
                                        color: const Color(0xFFE0CEB8)),
                                    errorWidget: (_, _, _) => Container(
                                      color: const Color(0xFFE0CEB8),
                                      child: const Icon(Icons.image_outlined,
                                          color: Colors.grey, size: 24),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFFE0CEB8),
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.grey, size: 24),
                                  ),
                          ),
                        ),
                      ),
                      // Bottom caption strip
                      SizedBox(
                        height: 30,
                        child: Center(
                          child: memory.title?.isNotEmpty == true
                              ? Text(
                                  memory.title as String,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF8A7060),
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Primary decoration ──
            if (scheme.primary == 'thumbtack')
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _Thumbtack(color: scheme.primaryColor),
                ),
              )
            else if (scheme.primary == 'tape')
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Center(
                  child: Transform.rotate(
                    angle: angle * -1.2,
                    child: _WashiTape(color: scheme.primaryColor),
                  ),
                ),
              )
            else if (scheme.primary == 'clothespin')
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: _Clothespin(color: scheme.primaryColor),
                ),
              ),

            // ── Extra decoration ──
            if (scheme.extra == 'heart')
              Positioned(
                bottom: 36,
                right: -6,
                child: Transform.rotate(
                  angle: 0.3,
                  child: Text('♡',
                      style: TextStyle(
                          fontSize: 18,
                          color: scheme.primaryColor.withValues(alpha: 0.9))),
                ),
              )
            else if (scheme.extra == 'sparkle')
              Positioned(
                bottom: 38,
                left: -4,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Text('✦',
                      style: TextStyle(
                          fontSize: 14,
                          color: scheme.primaryColor.withValues(alpha: 0.85))),
                ),
              )
            else if (scheme.extra == 'flower')
              Positioned(
                bottom: 34,
                right: -8,
                child: Text('✿',
                    style: TextStyle(
                        fontSize: 16,
                        color: scheme.primaryColor.withValues(alpha: 0.85))),
              )
            else if (scheme.extra == 'stamp')
              Positioned(
                bottom: 34,
                right: 4,
                child: Transform.rotate(
                  angle: 0.1,
                  child: CustomPaint(
                    size: const Size(22, 22),
                    painter: _StampPainter(color: scheme.primaryColor),
                  ),
                ),
              )
            else if (scheme.extra == 'doodle')
              Positioned(
                bottom: 36,
                left: -4,
                child: Transform.rotate(
                  angle: -0.15,
                  child: Text('★',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.primaryColor.withValues(alpha: 0.8))),
                ),
              ),

            // ── Side note ──
            if (scheme.sideNote != null)
              Positioned(
                top: 60,
                right: -10,
                child: Transform.rotate(
                  angle: math.pi / 2,
                  child: Text(
                    scheme.sideNote!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD4849A),
                      fontStyle: FontStyle.italic,
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

// ── Decoration Widgets ────────────────────────────────────────────────────

class _Thumbtack extends StatelessWidget {
  final Color color;
  const _Thumbtack({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _ThumbTackPainter(color: color)),
    );
  }
}

class _ThumbTackPainter extends CustomPainter {
  final Color color;
  const _ThumbTackPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Pin head shadow
    final shadowP = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx, cy + 2), 7, shadowP);

    // Pin head
    final headP = Paint()..color = color;
    canvas.drawCircle(Offset(cx, cy), 7, headP);

    // Highlight
    final hlP = Paint()..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(cx - 2, cy - 2), 3, hlP);

    // Pin needle
    final needleP = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy + 6), Offset(cx, cy + 12), needleP);
  }

  @override
  bool shouldRepaint(_ThumbTackPainter old) => old.color != color;
}

class _WashiTape extends StatelessWidget {
  final Color color;
  const _WashiTape({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(painter: _WashiPatternPainter(color: color)),
    );
  }
}

class _WashiPatternPainter extends CustomPainter {
  final Color color;
  const _WashiPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle stripe pattern on washi tape
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (double x = 6; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_WashiPatternPainter old) => false;
}

class _Clothespin extends StatelessWidget {
  final Color color;
  const _Clothespin({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 22,
      child: CustomPaint(painter: _ClothespinPainter(color: color)),
    );
  }
}

class _ClothespinPainter extends CustomPainter {
  final Color color;
  const _ClothespinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wood = Color.lerp(color, const Color(0xFFD4A870), 0.5)!;
    final dark = Color.lerp(color, Colors.black, 0.3)!;

    // Left arm
    final leftPath = Path()
      ..moveTo(w * 0.1, 0)
      ..lineTo(w * 0.4, 0)
      ..lineTo(w * 0.45, h)
      ..lineTo(w * 0.05, h)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = wood);
    canvas.drawPath(leftPath, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // Right arm
    final rightPath = Path()
      ..moveTo(w * 0.6, 0)
      ..lineTo(w * 0.9, 0)
      ..lineTo(w * 0.95, h)
      ..lineTo(w * 0.55, h)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = wood);
    canvas.drawPath(rightPath, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // Spring coil
    final springP = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.4), width: w * 0.35, height: h * 0.5),
      springP,
    );
  }

  @override
  bool shouldRepaint(_ClothespinPainter old) => old.color != color;
}

class _StampPainter extends CustomPainter {
  final Color color;
  const _StampPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final borderP = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Dashed stamp border
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)));
    // Draw dashes manually
    final metric = path.computeMetrics().first;
    final total = metric.length;
    double dist = 0;
    while (dist < total) {
      final seg = metric.extractPath(dist, dist + 3);
      canvas.drawPath(seg, borderP);
      dist += 6;
    }
    // Heart inside — drawn with two arcs + a path
    final hx = size.width / 2;
    final hy = size.height / 2 + 1;
    final hr = size.width * 0.22;
    final heartPath = Path()
      ..moveTo(hx, hy + hr * 1.2)
      ..cubicTo(hx - hr * 2.2, hy - hr * 0.5, hx - hr * 2.2, hy - hr * 2.2, hx, hy - hr * 0.8)
      ..cubicTo(hx + hr * 2.2, hy - hr * 2.2, hx + hr * 2.2, hy - hr * 0.5, hx, hy + hr * 1.2)
      ..close();
    canvas.drawPath(heartPath, Paint()..color = color.withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(_StampPainter old) => old.color != color;
}

// ── Sticky Note ───────────────────────────────────────────────────────────

class _StickyNote extends StatelessWidget {
  final double nightness;
  const _StickyNote({required this.nightness});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.04,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5C2),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Fold corner
            Positioned(
              bottom: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _FoldPainter(),
              ),
            ),
            // Text content
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 14, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'little\nmemories,\nbig\nmeaning',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B5A3A),
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.1,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text('♡', style: TextStyle(fontSize: 14, color: Color(0xFFD4849A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE8D88A));
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFC8B860).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(_FoldPainter old) => false;
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
