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
import '../../core/delight/couple_character.dart';
import '../../core/delight/delight.dart';
import '../../core/delight/mascot_creature.dart';
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

class _HeartParticle {
  final double x;
  final AnimationController ctrl;
  _HeartParticle({required this.x, required this.ctrl});
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with TickerProviderStateMixin {
  final List<_HeartParticle> _hearts = [];
  String? _lastSignalId; // dedup — never show same signal twice
  StreamSubscription? _signalsSub;

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

  void _spawnHeart(double x) {
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    final particle = _HeartParticle(x: x, ctrl: ctrl);
    setState(() => _hearts.add(particle));
    ctrl.forward().then((_) {
      if (mounted) setState(() => _hearts.remove(particle));
      ctrl.dispose();
    });
  }

  void _spawnHearts(int count) {
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _spawnHeart(0.2 + rng.nextDouble() * 0.6);
      });
    }
  }

  @override
  void initState() {
    super.initState();
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
      _signalsSub =
          ref.read(firestoreServiceProvider).watchSignals(coupleId).listen((snap) {
        if (!mounted) return;
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final docId = doc.id;
          if (docId == _lastSignalId) return; // already shown this signal
          final data = doc.data() as Map<String, dynamic>;
          // Gifts are handled by the shell's present-box overlay.
          if (data['type'] == 'gift') return;
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
    _spawnHearts(4);

    final (emoji, text) = switch (type) {
      'goodMorning' => ('☀️', 'Good morning from your person!'),
      'goodNight' => ('🌙', 'Good night — sweet dreams ♡'),
      'gratitude' => ('🙏', 'Your person is grateful for you today ♡'),
      _ => ('♡', message ?? 'Thinking of you ♡'),
    };

    TopBanner.show(context, emoji: emoji, text: text);
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

  DateTime? _lastThinkingOfYouSent;

  void _sendThinkingOfYou([String? message]) async {
    // A short cooldown so mashing the pill can't flood the partner with a
    // burst of separate notifications/banners — one every few seconds max.
    final now = DateTime.now();
    if (_lastThinkingOfYouSent != null &&
        now.difference(_lastThinkingOfYouSent!) < const Duration(seconds: 3)) {
      return;
    }
    _lastThinkingOfYouSent = now;
    final coupleId = ref.read(coupleIdProvider);
    final partner = ref.read(partnerUserProvider).valueOrNull;
    if (coupleId == null) return;
    DelightHaptics.heartbeat();
    _spawnHearts(6);
    await ref.read(firestoreServiceProvider).sendThinkingOfYou(
      coupleId,
      toUid: partner?.uid,
      message: message,
    );
  }

  Future<void> _composeThinkingOfYou() async {
    HapticFeedback.selectionClick();
    final ctrl = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('♡ Add a little note',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 150,
          maxLines: 3,
          minLines: 1,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Optional — leave blank to just send ♡',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            filled: true,
            fillColor: AppColors.bgMid,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: const Text('Send ♡',
                style: TextStyle(
                    color: AppColors.rose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (message == null) return; // cancelled
    _sendThinkingOfYou(message.isEmpty ? null : message);
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
                return SquishyTap(
                  style: TapAnimationStyle.jelly,
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
          child: SquishyTap(
            onTap: _showMoodPicker,
            style: TapAnimationStyle.jelly,
            child: _CharNameLabel(name: myName, color: accent),
          ),
        ),

        // Partner name label
        Positioned(
          left: partnerLeft,
          right: partnerRight,
          top: partnerTop,
          child: SquishyTap(
            onTap: _showMoodPicker,
            style: TapAnimationStyle.jelly,
            child: _CharNameLabel(name: partnerName, color: AppColors.lavender),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _signalsSub?.cancel();
    for (final h in _hearts) {
      h.ctrl.dispose();
    }
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

          // 2b. Ambient seasonal particles (petals, rain, diyas…)
          const SeasonalDrift(),

          // 2c. Easter eggs — decorative only, pure charm, no navigation.
          // Tap the fairy lights → they sparkle. Tap the rug → hidden heart.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.09,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                DelightHaptics.soft();
                FloatingStickers.burst(
                  context,
                  stickers: const ['✨', '⭐'],
                  count: 5,
                  origin: Offset(size.width / 2, size.height * 0.08),
                );
              },
            ),
          ),
          Positioned(
            left: size.width * 0.25,
            top: size.height * 0.78,
            width: size.width * 0.5,
            height: size.height * 0.1,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                DelightHaptics.soft();
                _spawnHeart(0.5);
              },
            ),
          ),

          // 2d. The couple's little companion creature — original design,
          // pure CustomPainter (no external art), perched near the window.
          Positioned(
            right: size.width * 0.06,
            top: size.height * 0.16,
            child: const MascotCreature(),
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
                      // Listen Together — tap to open the shared Spotify room
                      SquishyTap(
                        style: TapAnimationStyle.pulse,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/listen');
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1DB954)
                                    .withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.music_note_rounded,
                              color: Colors.black, size: 20),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.08, 1.08),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          ),
                      _NotificationBell(
                        unreadCount: ref.watch(unreadNotificationsCountProvider),
                        accent: accent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/notifications');
                        },
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/you');
                        },
                      ),
                    ],
                  ),
                ),

                const _PartnerActivityBanner(),
                const _CouplePresenceCharacters(),

                // Characters area — pushed to the lower portion
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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

          // 4. Thinking of You pill — centered just above the characters
          Positioned(
            top: size.height * 0.42,
            left: 0,
            right: 0,
            child: Center(
              child: _ThinkingOfYouPill(
                accent: accent,
                onTap: _composeThinkingOfYou,
              ).animate().fadeIn(delay: 200.ms),
            ),
          ),

          // 5. Rising hearts (sender and receiver)
          ..._hearts.map((h) => AnimatedBuilder(
            animation: h.ctrl,
            builder: (_, _) {
              final t = h.ctrl.value;
              return Positioned(
                left: size.width * h.x,
                bottom: 80 + 320 * t,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1.0 + t * 0.6,
                    child: const Text('♡',
                        style: TextStyle(fontSize: 36, color: AppColors.rose)),
                  ),
                ),
              );
            },
          )),
        ],
      ),
    );
  }
}

// ── Room actions — moved out of the home page top bar (kept: Spotify +
// notifications bell only), exposed here so /together can link to them ────

/// "Send a surprise" gift dialog — was the gift icon on the room top bar.
Future<void> sendHomeGiftDialog(BuildContext context, WidgetRef ref) async {
  final coupleId = ref.read(coupleIdProvider);
  final partnerUid = ref.read(partnerUserProvider).valueOrNull?.uid;
  if (coupleId == null || partnerUid == null) return;
  HapticFeedback.selectionClick();
  final ctrl = TextEditingController();
  final message = await showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('🎁 Send a surprise',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 200,
        maxLines: 4,
        minLines: 1,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Write something only they should read…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          filled: true,
          fillColor: AppColors.bgMid,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
          child: const Text('Wrap it up 🎁',
              style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (message == null || message.isEmpty || !context.mounted) return;
  HapticFeedback.mediumImpact();
  FloatingStickers.burst(context, stickers: const ['🎁', '🎀'], count: 5);
  await ref.read(firestoreServiceProvider).sendGift(coupleId, toUid: partnerUid, message: message);
}

/// The nickname / wild-ideas / notification-toggle sheet — was the tune
/// icon on the room top bar.
void showRoomSettingsSheet(BuildContext context) {
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

// Wild little things to fire at your partner, one tap each 😈 — shared by
// the room's Surprises & Settings sheet and the Together hub's Quick Pick.
const kWildIdeas = [
  ('😈', 'Dare them', [
    'I dare you to send me your best selfie in the next 5 minutes 😈',
    'Dare: voice note of you singing our song. Now. No excuses 🎤',
    'I dare you to tell me a secret you\'ve never told me 👀',
    'Dare: describe our first kiss in exactly 5 words 💋',
  ]),
  ('🔥', 'Flirt attack', [
    'Just so you know, I\'d absolutely swipe right on you again 🔥',
    'Warning: currently thinking about your smile. Productivity: 0%',
    'You + me + next visit = trouble 😏',
    'Reminder: you\'re the best-looking person in my phone 🔥',
  ]),
  ('💐', 'Compliment bomb', [
    'You make my whole day better just by existing 💐',
    'Someone as cute as you should be illegal, honestly',
    'Your laugh is my favourite sound in the world ♡',
    'I brag about you to everyone. Everyone. 💐',
  ]),
  ('🍕', 'Random question', [
    'Quick! Pizza or biryani for our first dinner together? 🍕',
    'If we could teleport anywhere right now — where? ✈️',
    'Rate my cuteness 1-10. Choose wisely 😌',
    'What are you wearing… on your feet? Socks check 🧦',
  ]),
];

Future<void> sendWildIdea(BuildContext context, WidgetRef ref, List<String> pool) async {
  final coupleId = ref.read(coupleIdProvider);
  final partnerUid = ref.read(partnerUserProvider).valueOrNull?.uid;
  if (coupleId == null || partnerUid == null) return;
  final msg = pool[math.Random().nextInt(pool.length)];
  HapticFeedback.mediumImpact();
  if (context.mounted) {
    FloatingStickers.burst(context, stickers: const ['🎁', '🎀'], count: 5);
  }
  await ref.read(firestoreServiceProvider).sendGift(coupleId, toUid: partnerUid, message: msg);
}

Future<void> sendCustomWildIdea(BuildContext context, WidgetRef ref) async {
  final coupleId = ref.read(coupleIdProvider);
  final partnerUid = ref.read(partnerUserProvider).valueOrNull?.uid;
  if (coupleId == null || partnerUid == null) return;
  final ctrl = TextEditingController();
  final message = await showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('✍️ Your own surprise',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 200,
        maxLines: 3,
        minLines: 1,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Write something only they should read…',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          filled: true,
          fillColor: AppColors.bgMid,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
          child: const Text('Wrap it up 🎁',
              style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  ctrl.dispose();
  if (message == null || message.isEmpty || !context.mounted) return;
  HapticFeedback.mediumImpact();
  FloatingStickers.burst(context, stickers: const ['🎁', '🎀'], count: 5);
  await ref.read(firestoreServiceProvider).sendGift(coupleId, toUid: partnerUid, message: message);
}

/// Standalone Wild Ideas picker — same content as the Surprises & Settings
/// sheet's "Wild ideas" card, reachable directly from Together's Quick Picks.
void showWildIdeasSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(sheetCtx).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎁 Wild ideas',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('One tap → a surprise lands on their phone',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...kWildIdeas.map((idea) => SquishyTap(
                    onTap: () => sendWildIdea(sheetCtx, ref, idea.$3),
                    style: TapAnimationStyle.jelly,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(idea.$1, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(idea.$2,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  )),
              SquishyTap(
                onTap: () => sendCustomWildIdea(sheetCtx, ref),
                style: TapAnimationStyle.jelly,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.45), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✍️', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Write your own',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
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
  const _ThinkingOfYouPill({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.heartBeat,
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

// ── Partner Activity Banner ─────────────────────────────────────────────────
//
// Honesty principle: only ever shows a real, screen-supplied activity label
// (via ActivityAnnouncer) or the coarser tab-level section — never guesses.
// Only rendered while the partner is genuinely online (heartbeat within the
// last 90s via partnerOnlineProvider) — if-and-only-if-online, per the ask.
class _PartnerActivityBanner extends ConsumerWidget {
  const _PartnerActivityBanner();

  static const _sectionLabels = {
    'room': 'On the Home page',
    'chat': 'In Chat',
    'memory': 'Looking at Memories',
    'calendar': 'On the Calendar',
    'together': 'In Fun',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    if (!online) return const SizedBox.shrink();

    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final chatActivity = ref.watch(partnerActivityStatusProvider).valueOrNull;
    final typing = ref.watch(partnerTypingProvider).valueOrNull ?? false;
    final activityLabel = ref.watch(partnerActivityLabelProvider).valueOrNull;
    final section = ref.watch(partnerSectionProvider).valueOrNull;

    // Priority mirrors Chat's own header status logic: recording/uploading
    // beats typing beats a specific per-screen activity beats a generic
    // "which tab" fallback.
    final String? label;
    if (chatActivity == 'recording') {
      label = 'Recording a voice note';
    } else if (chatActivity == 'uploading_snap') {
      label = "Uploading today's snap";
    } else if (chatActivity == 'uploading') {
      label = 'Uploading…';
    } else if (typing) {
      label = 'Typing…';
    } else if (activityLabel != null) {
      label = activityLabel;
    } else {
      label = _sectionLabels[section];
    }
    if (label == null) return const SizedBox.shrink();

    final name = partner?.displayName.split(' ').first ?? 'Your person';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  '$name · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Couple Presence Characters ───────────────────────────────────────────
//
// Asher & Wren, the couple's two illustrated characters (real commissioned
// art, assets/characters/), shown together as a small companion pair.
// The pose reflects real state, not decoration: idle by default, a brief
// wave the moment the partner comes online, or asleep if it's night hours
// on this device and the partner is offline.
class _CouplePresenceCharacters extends ConsumerStatefulWidget {
  const _CouplePresenceCharacters();

  @override
  ConsumerState<_CouplePresenceCharacters> createState() =>
      _CouplePresenceCharactersState();
}

class _CouplePresenceCharactersState extends ConsumerState<_CouplePresenceCharacters> {
  bool? _lastOnline;
  bool _justWaved = false;

  void _handleOnlineChange(bool online) {
    if (_lastOnline == false && online == true) {
      setState(() => _justWaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justWaved = false);
      });
    }
    _lastOnline = online;
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleOnlineChange(online));

    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 6;

    final String pose;
    if (_justWaved) {
      pose = 'excited';
    } else if (isNight && !online) {
      pose = 'goodnight';
    } else {
      pose = 'idle';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: CoupleCharacter(
          character: CoupleCharacterId.combo,
          pose: pose,
          height: 70,
        ),
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final Color accent;
  final VoidCallback onTap;

  const _NotificationBell({
    required this.unreadCount,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final bell = SquishyTap(
      onTap: onTap,
      style: TapAnimationStyle.wobble,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: hasUnread
                ? accent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.15),
            width: hasUnread ? 1.2 : 0.8,
          ),
          boxShadow: hasUnread
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.55), blurRadius: 14),
                  BoxShadow(
                      color: accent.withValues(alpha: 0.25), blurRadius: 26),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(Icons.mail_outline_rounded,
                  color: Colors.white, size: 18),
            ),
            if (hasUnread)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  constraints: const BoxConstraints(minWidth: 17),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.7), blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (!hasUnread) return bell;
    return bell
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.06, 1.06),
          duration: 900.ms,
          curve: Curves.easeInOut,
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
            child: SquishyTap(
              onTap: () => ctx.push('/memory'),
              style: TapAnimationStyle.pulse,
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

    return SquishyTap(
      onTap: () => context.push('/memory/${memory.id}'),
      style: TapAnimationStyle.pulse,
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
  final _nicknameCtrl = TextEditingController();
  bool _nicknameSaving = false;
  bool _nicknameInited = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final nick = _nicknameCtrl.text.trim();
    setState(() => _nicknameSaving = true);
    try {
      await ref.read(firestoreServiceProvider).updateUser({'nickname': nick});
      if (mounted) HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _nicknameSaving = false);
    }
  }

  // NOTE: wild-idea sending logic lives in the top-level sendWildIdea /
  // sendCustomWildIdea functions below this class (shared with
  // showWildIdeasSheet, the Together hub's standalone Quick Pick entry).

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
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (!_nicknameInited && me != null) {
      _nicknameCtrl.text = me.nickname ?? '';
      _nicknameInited = true;
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
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

          // Nickname — how you appear in chat & their notifications
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('💕', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Your nickname',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                    'What your partner sees in chat & notifications',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameCtrl,
                        maxLength: 20,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'e.g. Bubu, Cutie, Chikoo…',
                          hintStyle: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgMid,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SquishyTap(
                      onTap: _nicknameSaving ? null : _saveNickname,
                      style: TapAnimationStyle.bounce,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.rose.withValues(alpha: 0.4)),
                        ),
                        child: _nicknameSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.rose))
                            : const Text('Save',
                                style: TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Wild ideas — one-tap mischief
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🎁', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text('Wild ideas',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('One tap → a surprise lands on their phone',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...kWildIdeas.map((idea) {
                      return SquishyTap(
                        onTap: () => sendWildIdea(context, ref, idea.$3),
                        style: TapAnimationStyle.jelly,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgMid,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.divider, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(idea.$1,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(idea.$2,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Write your own — wrapped and delivered the same way
                    SquishyTap(
                      onTap: () => sendCustomWildIdea(context, ref),
                      style: TapAnimationStyle.jelly,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.rose.withValues(alpha: 0.45),
                              width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✍️', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text('Your own words',
                                style: TextStyle(
                                    color: AppColors.rose,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
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
              return SquishyTap(
                onTap: () async {
                  if (couple != null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateCoupleTheme(
                            couple.id, color.toARGB32());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                style: TapAnimationStyle.jelly,
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
          SquishyTap(
            style: TapAnimationStyle.shake,
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
      ),
    );
  }
}
