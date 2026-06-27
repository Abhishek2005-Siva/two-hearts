import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/character_avatar.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with TickerProviderStateMixin {
  // Parallax
  Offset _parallax = Offset.zero;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  // Signal animation
  bool _signalVisible = false;
  String _signalEmoji = '♡';
  String _signalText = '';
  late AnimationController _signalCtrl;

  // Gesture ring (swipe up from bottom)
  bool _ringVisible = false;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _signalCtrl = AnimationController(vsync: this, duration: 3.seconds);
    _startParallax();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenSignals());
  }

  void _startParallax() {
    try {
      _accelSub = accelerometerEventStream().listen((e) {
        if (!mounted) return;
        final tx = (-e.x.clamp(-4.0, 4.0) / 4.0) * 20;
        final ty = (e.y.clamp(-4.0, 4.0) / 4.0) * 12;
        setState(() {
          _parallax = Offset(
            _parallax.dx * 0.88 + tx * 0.12,
            _parallax.dy * 0.88 + ty * 0.12,
          );
        });
      });
    } catch (_) {}
  }

  void _listenSignals() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    ref.read(firestoreServiceProvider).watchSignals(coupleId).listen((snap) {
      if (!mounted || snap.docs.isEmpty) return;
      final data = snap.docs.first.data() as Map<String, dynamic>;
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid == null || data['fromUid'] == myUid) return;
      final type = data['type'] as String? ?? 'thinkingOfYou';
      _triggerSignal(type, data['message'] as String?);
    });
  }

  void _triggerSignal(String type, String? message) {
    HapticFeedback.mediumImpact();
    final (emoji, text) = switch (type) {
      'goodMorning' => ('☀️', 'Good morning from your person!'),
      'goodNight'   => ('🌙', 'Good night — sweet dreams ♡'),
      'gratitude'   => ('🙏', 'Grateful for you today ♡'),
      _             => ('♡', message ?? 'Thinking of you ♡'),
    };
    setState(() {
      _signalVisible = true;
      _signalEmoji = emoji;
      _signalText = text;
    });
    _signalCtrl.forward(from: 0);
    Future.delayed(5.seconds, () {
      if (mounted) setState(() => _signalVisible = false);
    });
  }

  void _showRing() {
    HapticFeedback.lightImpact();
    setState(() => _ringVisible = true);
    _ringTimer?.cancel();
    _ringTimer = Timer(4.seconds, () {
      if (mounted) setState(() => _ringVisible = false);
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _signalCtrl.dispose();
    _ringTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final accent = ref.watch(accentColorProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final bucket = ref.watch(bucketListProvider).valueOrNull ?? [];
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final partnerOnline = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();

    final unreadLetters = letters.where((l) => l.isUnlocked && !l.opened).length;
    final bucketPending = bucket.where((b) => b.status == BucketStatus.someday).length;

    // Journal glowing if today's entry not done by me
    final todayKey = _todayKey(now);
    final todayJournal = journal.where((j) => j.id == todayKey).firstOrNull;
    final journalGlowing = todayJournal == null ||
        (todayJournal.uidA != myUid && todayJournal.uidB != myUid);

    final onThisDay = memories.where((m) =>
        m.createdAt.month == now.month &&
        m.createdAt.day == now.day &&
        m.createdAt.year < now.year).toList();

    return Scaffold(
      body: Stack(
        children: [
          // ── Background (time-of-day + accent glow + floor) ──────────────
          _RoomBackground(now: now, accent: accent, parallax: _parallax, partnerOnline: partnerOnline),

          // ── Room scene (all objects with parallax) ───────────────────────
          _RoomScene(
            size: size,
            parallax: _parallax,
            accent: accent,
            me: me,
            partner: partner,
            memories: memories.take(3).toList(),
            unreadLetters: unreadLetters,
            bucketPending: bucketPending,
            journalGlowing: journalGlowing,
            onNavigate: (path) => context.push(path),
          ),

          // ── Floating signal heart ────────────────────────────────────────
          if (_signalVisible)
            _FloatingSignal(
              emoji: _signalEmoji,
              text: _signalText,
              ctrl: _signalCtrl,
              size: size,
            ),

          // ── On This Day chip (bottom) ────────────────────────────────────
          if (onThisDay.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 76,
              left: 16, right: 16,
              child: _OnThisDayChip(memory: onThisDay.first, accent: accent)
                  .animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
            ),

          // ── Top bar ──────────────────────────────────────────────────────
          _TopBar(
            me: me,
            partner: partner,
            couple: couple,
            accent: accent,
            partnerOnline: partnerOnline,
            onSettings: () => _showSettings(context),
          ),

          // ── Bottom swipe zone (triggers gesture ring) ────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: 72,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (d) {
                if (d.velocity.pixelsPerSecond.dy < -200) _showRing();
              },
              child: Center(
                child: AnimatedOpacity(
                  opacity: _ringVisible ? 0.0 : 0.5,
                  duration: 300.ms,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40, height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('swipe up', style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Gesture ring ─────────────────────────────────────────────────
          if (_ringVisible)
            _GestureRing(
              accent: accent,
              onNavigate: (path) {
                setState(() => _ringVisible = false);
                context.push(path);
              },
            ),
        ],
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

  String _todayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// ── Background ─────────────────────────────────────────────────────────────

class _RoomBackground extends StatelessWidget {
  final DateTime now;
  final Color accent;
  final Offset parallax;
  final bool partnerOnline;
  const _RoomBackground({required this.now, required this.accent, required this.parallax, required this.partnerOnline});

  @override
  Widget build(BuildContext context) {
    final bg = RoomTod.bgGradient(now);
    final sky = RoomTod.skyCeiling(now);
    final glowMul = RoomTod.glow(now) * (partnerOnline ? 1.35 : 1.0);
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.3, 0.65, 1.0],
              colors: [bg[0], AppColors.bgMid, AppColors.bg, bg[1]],
            ),
          ),
        ),

        // Sky tint at ceiling
        Positioned(
          top: 0, left: 0, right: 0,
          height: size.height * 0.28,
          child: Container(color: sky),
        ),

        // Accent glow (parallax-shifted slightly)
        Transform.translate(
          offset: Offset(-parallax.dx * 0.15, -parallax.dy * 0.1),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.15),
                radius: 0.85,
                colors: [
                  accent.withValues(alpha: 0.13 * glowMul),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // If partner online → warm brightening
        if (partnerOnline)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [accent.withValues(alpha: 0.07), Colors.transparent],
              ),
            ),
          ),

        // Wall-to-floor perspective divider
        Positioned(
          top: size.height * 0.63,
          left: 0, right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                accent.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // Floor darkening
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: size.height * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Room Scene (all interactive objects) ──────────────────────────────────

class _RoomScene extends StatelessWidget {
  final Size size;
  final Offset parallax;
  final Color accent;
  final dynamic me;
  final dynamic partner;
  final List<MemoryModel> memories;
  final int unreadLetters;
  final int bucketPending;
  final bool journalGlowing;
  final void Function(String) onNavigate;

  const _RoomScene({
    required this.size,
    required this.parallax,
    required this.accent,
    required this.me,
    required this.partner,
    required this.memories,
    required this.unreadLetters,
    required this.bucketPending,
    required this.journalGlowing,
    required this.onNavigate,
  });

  Offset _pos(double fx, double fy, double depth) => Offset(
        fx * size.width + parallax.dx * depth,
        fy * size.height + parallax.dy * depth,
      );

  @override
  Widget build(BuildContext context) {
    // Object positions: (fracX, fracY, depth, widget)
    return Stack(
      children: [
        // ── Photo frames on the back wall ─────────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.05, 0.19, 0.28).dx, _pos(0.05, 0.19, 0.28).dy, 68, 82),
          child: _PhotoFrame(
            memory: memories.isNotEmpty ? memories[0] : null,
            onTap: () => onNavigate('/memory'),
          ).animate().fadeIn(delay: 200.ms),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.34, 0.15, 0.22).dx, _pos(0.34, 0.15, 0.22).dy, 82, 98),
          child: _PhotoFrame(
            memory: memories.length > 1 ? memories[1] : null,
            onTap: () => onNavigate('/memory'),
            large: true,
          ).animate().fadeIn(delay: 300.ms),
        ),
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.65, 0.19, 0.28).dx, _pos(0.65, 0.19, 0.28).dy, 68, 82),
          child: _PhotoFrame(
            memory: memories.length > 2 ? memories[2] : null,
            onTap: () => onNavigate('/memory'),
          ).animate().fadeIn(delay: 250.ms),
        ),

        // ── Bookshelf (left, mid depth) ───────────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.02, 0.51, 0.52).dx, _pos(0.02, 0.51, 0.52).dy, 110, 130),
          child: _Bookshelf(
            glowing: journalGlowing,
            accent: accent,
            onTap: () => onNavigate('/together/journal'),
          ).animate().fadeIn(delay: 350.ms),
        ),

        // ── Cabinet / letters (right, mid depth) ──────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.65, 0.50, 0.52).dx, _pos(0.65, 0.50, 0.52).dy, 100, 115),
          child: _LetterCabinet(
            unreadCount: unreadLetters,
            accent: accent,
            onTap: () => onNavigate('/together'),
          ).animate().fadeIn(delay: 350.ms),
        ),

        // ── Corkboard (lower left) ────────────────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.03, 0.68, 0.72).dx, _pos(0.03, 0.68, 0.72).dy, 98, 82),
          child: _Corkboard(
            pendingCount: bucketPending,
            accent: accent,
            onTap: () => onNavigate('/together'),
          ).animate().fadeIn(delay: 450.ms),
        ),

        // ── Chat desk / camera (center lower) ─────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.42, 0.66, 0.78).dx, _pos(0.42, 0.66, 0.78).dy, 92, 74),
          child: _ChatDesk(
            accent: accent,
            onTap: () => onNavigate('/chat'),
          ).animate().fadeIn(delay: 450.ms),
        ),

        // ── Games cube (right lower) ───────────────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.71, 0.68, 0.78).dx, _pos(0.71, 0.68, 0.78).dy, 74, 68),
          child: _GamesCube(
            accent: accent,
            onTap: () => onNavigate('/games'),
          ).animate().fadeIn(delay: 500.ms),
        ),

        // ── Avatar pair (center floor) ─────────────────────────
        Positioned.fromRect(
          rect: Rect.fromLTWH(_pos(0.16, 0.75, 1.0).dx, _pos(0.16, 0.75, 1.0).dy, 180, 98),
          child: _AvatarPair(
            me: me,
            partner: partner,
            accent: accent,
            onTap: () => onNavigate('/you'),
          ).animate().fadeIn(delay: 500.ms),
        ),

        // ── "You & Me" label ──────────────────────────────────
        Positioned(
          left: _pos(0.16, 0.75, 1.0).dx,
          top: _pos(0.16, 0.75, 1.0).dy + 100,
          width: 180,
          child: const Center(
            child: Text('tap to visit your profiles',
                style: TextStyle(color: AppColors.textMuted, fontSize: 9, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }
}

// ── Room object widgets ────────────────────────────────────────────────────

class _PhotoFrame extends StatelessWidget {
  final MemoryModel? memory;
  final VoidCallback onTap;
  final bool large;
  const _PhotoFrame({this.memory, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF5C3A22),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(3, 7)),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: memory != null
            ? CachedNetworkImage(
                imageUrl: memory!.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _emptySlot(),
              )
            : _emptySlot(),
      ),
    );
  }

  Widget _emptySlot() => Container(
        color: const Color(0xFF2A1A0E),
        child: const Center(
          child: Text('📸', style: TextStyle(fontSize: 18)),
        ),
      );
}

class _Bookshelf extends StatelessWidget {
  final bool glowing;
  final Color accent;
  final VoidCallback onTap;
  const _Bookshelf({required this.glowing, required this.accent, required this.onTap});

  static const _spines = [
    Color(0xFFFF6B8A), Color(0xFFB8A0D9), Color(0xFFFFD166),
    Color(0xFF6FBFA0), Color(0xFF5B9BD5), Color(0xFFFF8C42),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A1810),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF4A2E18), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(4, 6)),
            if (glowing) BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 18),
          ],
        ),
        child: Column(
          children: [
            _shelf(_spines.sublist(0, 5)),
            Container(height: 3, color: const Color(0xFF3A2010)),
            _shelf(_spines.sublist(1, 5)),
            Container(height: 3, color: const Color(0xFF3A2010)),
            _shelf(_spines.sublist(0, 3)),
          ],
        ),
      ),
    );
  }

  Widget _shelf(List<Color> colors) => Expanded(
        child: Row(
          children: colors.map((c) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          )).toList(),
        ),
      );
}

class _LetterCabinet extends StatelessWidget {
  final int unreadCount;
  final Color accent;
  final VoidCallback onTap;
  const _LetterCabinet({required this.unreadCount, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C1A0E),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF4A2E18), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(3, 5)),
            if (unreadCount > 0) BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1008),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 0 ? '💌' : '📬',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                Container(height: 2, color: const Color(0xFF4A2E18)),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C3A22),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF8B6020), width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (unreadCount > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Corkboard extends StatelessWidget {
  final int pendingCount;
  final Color accent;
  final VoidCallback onTap;
  const _Corkboard({required this.pendingCount, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF9B7D3A),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFF5C3C10), width: 4),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(3, 5)),
          ],
        ),
        child: Stack(
          children: [
            // Pinned notes
            Positioned(top: 6, left: 6,
                child: _NotePin(color: accent)),
            Positioned(top: 22, left: 28,
                child: _NotePin(color: AppColors.lavender)),
            Positioned(top: 8, left: 54,
                child: _NotePin(color: AppColors.gold)),
            Positioned(top: 36, left: 10,
                child: _NotePin(color: AppColors.coral)),
            // Count badge
            if (pendingCount > 0)
              Positioned(
                bottom: 5, right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pendingCount left',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotePin extends StatelessWidget {
  final Color color;
  const _NotePin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)]),
        ),
        Container(
          width: 18, height: 20,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _ChatDesk extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _ChatDesk({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A1810),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF4A2E18), width: 1.5),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(3, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📷', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text('Chat', style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _GamesCube extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _GamesCube({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1430),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(2, 4)),
            BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text('Games', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _AvatarPair extends StatelessWidget {
  final dynamic me;
  final dynamic partner;
  final Color accent;
  final VoidCallback onTap;
  const _AvatarPair({this.me, this.partner, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meName = me?.displayName as String? ?? 'You';
    final pName = partner?.displayName as String? ?? '?';
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterAvatar(color: accent, name: meName, size: 72),
              const SizedBox(height: 4),
              Text(meName.split(' ').first,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
          const SizedBox(width: 10),
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('♡', style: TextStyle(color: AppColors.rose, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterAvatar(color: AppColors.lavender, name: pName, size: 72),
              const SizedBox(height: 4),
              Text(pName.split(' ').first,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Signal overlay ─────────────────────────────────────────────────────────

class _FloatingSignal extends StatelessWidget {
  final String emoji;
  final String text;
  final AnimationController ctrl;
  final Size size;
  const _FloatingSignal({required this.emoji, required this.text, required this.ctrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) {
        final t = ctrl.value;
        return Stack(
          children: [
            // Rising heart
            Positioned(
              left: size.width * 0.45,
              bottom: size.height * 0.12 + t * size.height * 0.4,
              child: Opacity(
                opacity: (1 - t * 1.2).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1.0 + t * 0.6,
                  child: Text(emoji, style: const TextStyle(fontSize: 44)),
                ),
              ),
            ),
            // Banner
            if (t < 0.6)
              Positioned(
                bottom: size.height * 0.12,
                left: 24, right: 24,
                child: Opacity(
                  opacity: (1 - t / 0.6).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                    ),
                    child: Text(text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── On This Day chip ───────────────────────────────────────────────────────

class _OnThisDayChip extends StatelessWidget {
  final MemoryModel memory;
  final Color accent;
  const _OnThisDayChip({required this.memory, required this.accent});

  @override
  Widget build(BuildContext context) {
    final years = DateTime.now().year - memory.createdAt.year;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: memory.imageUrl,
              width: 44, height: 44, fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(width: 44, height: 44,
                  color: AppColors.bgCardLight,
                  child: const Icon(Icons.photo_outlined, color: AppColors.textMuted, size: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📅 $years year${years == 1 ? '' : 's'} ago today',
                    style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
                if (memory.caption?.isNotEmpty == true)
                  Text(memory.caption!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final dynamic me;
  final dynamic partner;
  final CoupleModel? couple;
  final Color accent;
  final bool partnerOnline;
  final VoidCallback onSettings;
  const _TopBar({this.me, this.partner, this.couple, required this.accent, required this.partnerOnline, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final meName = (me?.displayName as String? ?? '?').split(' ').first;
    final pName = (partner?.displayName as String? ?? '?').split(' ').first;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    couple != null ? '$meName & $pName' : 'Two Hearts',
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary,
                    ),
                  ),
                  if (partnerOnline)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(color: Color(0xFF44EE88), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text('both here ♡', style: TextStyle(color: Color(0xFF44EE88), fontSize: 10)),
                    ])
                  else
                    Text(
                      couple != null
                          ? '${DateTime.now().difference(couple!.createdAt).inDays} days together'
                          : '',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.3),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onSettings,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gesture Ring ───────────────────────────────────────────────────────────

class _GestureRing extends StatelessWidget {
  final Color accent;
  final void Function(String) onNavigate;
  const _GestureRing({required this.accent, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 20)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RingBtn(icon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat', accent: accent, onTap: onNavigate),
              _RingBtn(icon: Icons.photo_library_rounded, label: 'Memories', path: '/memory', accent: accent, onTap: onNavigate),
              _RingBtn(icon: Icons.favorite_rounded, label: 'Together', path: '/together', accent: accent, onTap: onNavigate),
              _RingBtn(icon: Icons.casino_rounded, label: 'Games', path: '/games', accent: accent, onTap: onNavigate),
              _RingBtn(icon: Icons.people_rounded, label: 'You & Me', path: '/you', accent: accent, onTap: onNavigate),
            ],
          ),
        ).animate().scale(begin: const Offset(0.85, 0.85), curve: Curves.elasticOut).fade(),
      ),
    );
  }
}

class _RingBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final Color accent;
  final void Function(String) onTap;
  const _RingBtn({required this.icon, required this.label, required this.path, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Settings Sheet ─────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).valueOrNull;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Your colour', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: kCoupleAccents.map((a) {
              final color = a['color'] as Color;
              final selected = couple?.themeColor == color.toARGB32();
              return GestureDetector(
                onTap: () async {
                  if (couple != null) {
                    await ref.read(firestoreServiceProvider).updateCoupleTheme(couple.id, color.toARGB32());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)] : null,
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
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
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: const Row(children: [
                Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
                SizedBox(width: 12),
                Text('Sign out', style: TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
