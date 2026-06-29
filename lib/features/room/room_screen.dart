import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  void _sendThinkingOfYou() async {
    final coupleId = ref.read(coupleIdProvider);
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null) return;
    HapticFeedback.mediumImpact();
    await ref.read(firestoreServiceProvider).sendThinkingOfYou(
      coupleId,
      toUid: partner?.uid,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('♡ Sent to your person'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
    }
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

  /// Builds the full-screen Stack overlay with character name labels and tap areas.
  Widget _buildCharacterOverlay(
    BuildContext context,
    dynamic me,
    dynamic partner,
    MoodType? myMood,
    Color accent,
    Size size,
  ) {
    // Determine which side each user is on based on gender.
    // Male character is on the LEFT, female character is on the RIGHT.
    final isMeMale = me?.gender == 'male';
    final myName = (me?.displayName as String? ?? 'You').split(' ').first;
    final partnerName = (partner?.displayName as String? ?? '?').split(' ').first;

    // Positions for each side
    const maleLeft = 0.10;
    const maleTop = 0.50;
    const femaleRight = 0.08;
    const femaleTop = 0.53;

    // My position
    final myLeft = isMeMale ? size.width * maleLeft : null;
    final myRight = isMeMale ? null : size.width * femaleRight;
    final myTop = isMeMale ? size.height * maleTop : size.height * femaleTop;

    // Partner position
    final partnerLeft = isMeMale ? null : size.width * maleLeft;
    final partnerRight = isMeMale ? size.width * femaleRight : null;
    final partnerTop = isMeMale ? size.height * femaleTop : size.height * maleTop;

    // Tap area size covering the character body
    const tapW = 90.0;
    const tapH = 160.0;

    return Stack(
      children: [
        // Invisible tap area for my character body
        Positioned(
          left: myLeft != null ? myLeft - 10 : null,
          right: myRight != null ? myRight - 10 : null,
          top: myTop - 80,
          child: GestureDetector(
            onTap: _showMoodPicker,
            child: Container(
              width: tapW,
              height: tapH,
              color: Colors.transparent,
            ),
          ),
        ),

        // Invisible tap area for partner character body (also opens my mood picker)
        Positioned(
          left: partnerLeft != null ? partnerLeft - 10 : null,
          right: partnerRight != null ? partnerRight - 10 : null,
          top: partnerTop - 80,
          child: GestureDetector(
            onTap: _showMoodPicker,
            child: Container(
              width: tapW,
              height: tapH,
              color: Colors.transparent,
            ),
          ),
        ),

        // My mood bubble (above my name)
        if (myMood != null)
          Positioned(
            left: myLeft,
            right: myRight,
            top: myTop - 38,
            child: _NameMoodBubble(mood: myMood),
          ),

        // Partner mood bubble (above partner name)
        if (_partnerMoodVisible && _partnerMoodToShow != null)
          Positioned(
            left: partnerLeft,
            right: partnerRight,
            top: partnerTop - 38,
            child: _NameMoodBubble(mood: _partnerMoodToShow!),
          ),

        // My name label
        Positioned(
          left: myLeft,
          right: myRight,
          top: myTop,
          child: GestureDetector(
            onTap: _showMoodPicker,
            child: _CharNameLabel(name: myName, color: accent),
          ),
        ),

        // Partner name label
        Positioned(
          left: partnerLeft,
          right: partnerRight,
          top: partnerTop,
          child: GestureDetector(
            onTap: _showMoodPicker,
            child: _CharNameLabel(name: partnerName, color: AppColors.lavender),
          ),
        ),
      ],
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
    final activeMoods = (ref.watch(moodsProvider).valueOrNull ?? [])
        .where((m) => !m.isExpired)
        .toList();
    final moods = activeMoods;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final myMood = moods.where((m) => m.uid == myUid).firstOrNull?.mood;
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

          // 3. Character name labels + tap areas overlaid on full screen
          _buildCharacterOverlay(context, me, partner, myMood, accent, size),

          // 4. Floating heart animation (unchanged)
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

// ── Character Name Label ─────────────────────────────────────────────────

class _CharNameLabel extends StatelessWidget {
  final String name;
  final Color color;
  const _CharNameLabel({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
          Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}

// ── Name Mood Bubble ──────────────────────────────────────────────────────

class _NameMoodBubble extends StatelessWidget {
  final MoodType mood;
  const _NameMoodBubble({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(mood.emoji, style: const TextStyle(fontSize: 18)),
    ).animate().fadeIn().slideY(begin: -0.3);
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
// Flat warm beige board — matches reference image exactly.
// Each card gets ONE subtle decoration only: pin / tape / heart sticker.

class _PolaroidStrip extends StatelessWidget {
  final List<dynamic> memories;
  final double nightness;
  const _PolaroidStrip({required this.memories, required this.nightness});

  @override
  Widget build(BuildContext context) {
    final items = memories.take(6).toList();
    final boardColor = Color.lerp(
        const Color(0xFFE8D4B8), const Color(0xFFD0BC9C), nightness)!;

    return Container(
      height: 195,
      decoration: BoxDecoration(
        color: boardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 10),
        itemCount: items.length + 1,
        itemBuilder: (ctx, i) {
          if (i < items.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _PolaroidCard(
                  memory: items[i], index: i, nightness: nightness),
            );
          }
          // Sticky note at end
          return Padding(
            padding: const EdgeInsets.only(right: 16, top: 6),
            child: GestureDetector(
              onTap: () => ctx.push('/memory'),
              child: _StickyNote(nightness: nightness),
            ),
          );
        },
      ),
    );
  }
}

// ── Polaroid Card ─────────────────────────────────────────────────────────
//
// Decoration per index (cycles every 4):
//   0 → pink circle pin at top-center
//   1 → beige tape strip across top
//   2 → small pink heart '♥' sticker at top-right
//   3 → no decoration (clean)

class _PolaroidCard extends StatelessWidget {
  final dynamic memory;
  final int index;
  final double nightness;
  const _PolaroidCard(
      {required this.memory, required this.index, required this.nightness});

  static String _polaroidThumb(String url, bool isVideo) {
    if (isVideo && url.contains('cloudinary.com')) {
      return url.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$'), '.jpg');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    // Very slight rotations — real polaroids are nearly straight
    const angles = [-0.03, 0.02, -0.015, 0.025, -0.02, 0.03];
    final angle = angles[index % angles.length];
    final cardColor = Color.lerp(
        const Color(0xFFFFFDF8), const Color(0xFFF5EDE0), nightness)!;

    return GestureDetector(
      onTap: () => context.push('/memory/${memory.id}'),
      child: SizedBox(
        width: 112,
        height: 157,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // ── Polaroid frame ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  height: 148,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20 + nightness * 0.15),
                        blurRadius: 10,
                        offset: const Offset(1, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Photo area — equal border on 3 sides, thick bottom
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(1),
                            child: memory.imageUrl?.isNotEmpty == true
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: _polaroidThumb(memory.imageUrl as String, memory.isVideo as bool),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: (ctx, url) =>
                                            Container(color: const Color(0xFFDDCAB4)),
                                        errorWidget: (ctx, url, err) => Container(
                                          color: const Color(0xFFDDCAB4),
                                          child: const Icon(Icons.image_outlined,
                                              color: Colors.grey, size: 22),
                                        ),
                                      ),
                                      if (memory.isVideo as bool)
                                        const Center(
                                          child: Icon(Icons.play_circle_outline,
                                              color: Colors.white70, size: 28),
                                        ),
                                    ],
                                  )
                                : Container(
                                    color: const Color(0xFFDDCAB4),
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.grey, size: 22),
                                  ),
                          ),
                        ),
                      ),
                      // Thick bottom white strip — polaroid signature
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),

            // ── Decoration ──
            if (index % 4 == 0)
              // Pink circle push-pin at top center
              Positioned(
                top: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE88A8A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  // Tiny highlight dot
                  child: const Align(
                    alignment: Alignment(-0.4, -0.4),
                    child: SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x88FFFFFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (index % 4 == 1)
              // Beige/cream tape strip across the top edge
              Positioned(
                top: 8,
                child: Transform.rotate(
                  angle: angle * -0.8,
                  child: Container(
                    width: 46,
                    height: 13,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0C898).withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              )
            else if (index % 4 == 2)
              // Small heart sticker at top-right
              const Positioned(
                top: 4,
                right: 6,
                child: Text(
                  '♥',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFD4849A),
                  ),
                ),
              ),
            // index % 4 == 3 → no decoration (clean polaroid)
          ],
        ),
      ),
    );
  }
}

// ── Sticky Note ───────────────────────────────────────────────────────────

class _StickyNote extends StatelessWidget {
  final double nightness;
  const _StickyNote({required this.nightness});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.03,
      child: SizedBox(
        width: 95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small flower above note
            const Text('✿', style: TextStyle(fontSize: 20, color: Color(0xFFC4A870))),
            const SizedBox(height: 3),
            Container(
              width: 95,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8D6),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 7,
                    offset: const Offset(1, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'little\nmemories,\nbig\nmeaning',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7A6040),
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('♡',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD4849A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Settings Sheet ────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (value) {
      await FirebaseMessaging.instance.subscribeToTopic('all');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('all');
    }
    if (mounted) setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Preferences',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Notifications',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                Switch(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeThumbColor: AppColors.rose,
                ),
              ],
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
