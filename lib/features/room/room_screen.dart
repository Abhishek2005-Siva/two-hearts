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

  // Partner mood overlay
  MoodType? _partnerMoodToShow;
  bool _partnerMoodVisible = false;
  MoodType? _lastKnownPartnerMood;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _listenSignals();
  }

  void _listenSignals() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coupleId = ref.read(coupleIdProvider);
      if (coupleId == null) return;
      ref.read(firestoreServiceProvider).watchSignals(coupleId).listen((snap) {
        if (!mounted) return;
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data() as Map<String, dynamic>;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && data['fromUid'] != uid) {
            // Only show if signal is fresh (within 15 seconds)
            final sentAt = (data['sentAt'] as dynamic)?.toDate() as DateTime?;
            final isRecent = sentAt == null ||
                DateTime.now().difference(sentAt).inSeconds < 15;
            if (isRecent) {
              final type = data['type'] as String? ?? 'thinkingOfYou';
              final message = data['message'] as String?;
              _showSignal(type: type, message: message);
            }
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
      'goodNight'   => ('🌙', 'Good night — sweet dreams ♡'),
      'gratitude'   => ('🙏', 'Your person is grateful for you today ♡'),
      _             => ('♡', message ?? 'Thinking of you ♡'),
    };

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Text('$emoji  ', style: const TextStyle(fontSize: 18)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ]),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final currentMood = ref.read(moodsProvider).valueOrNull
        ?.where((m) => m.uid == FirebaseAuth.instance.currentUser?.uid)
        .firstOrNull
        ?.mood;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(
          24, 20, 24,
          MediaQuery.of(sheetCtx).viewInsets.bottom +
              MediaQuery.of(sheetCtx).padding.bottom + 24,
        ),
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
                    await ref.read(firestoreServiceProvider).setMood(coupleId, mood);
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
                      color: selected ? null : AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? accent : AppColors.divider,
                        width: selected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood.emoji,
                            style: TextStyle(fontSize: selected ? 22 : 20)),
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

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(accentColorProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final moods = ref.watch(moodsProvider).valueOrNull ?? [];
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    final daysTogether = couple != null
        ? DateTime.now().difference(couple.createdAt).inDays
        : 0;

    // On This Day
    final now = DateTime.now();
    final onThisDay = memories.where((m) =>
        m.createdAt.month == now.month &&
        m.createdAt.day == now.day &&
        m.createdAt.year < now.year).toList();

    // Partner mood — show popup when it changes
    final partnerMoodEntry = moods.where((m) => m.uid != myUid).firstOrNull;
    final partnerMood = partnerMoodEntry?.mood;
    if (partnerMood != null && partnerMood != _lastKnownPartnerMood) {
      _lastKnownPartnerMood = partnerMood;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPartnerMoodPopup(partnerMood);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.5),
                radius: 1.2,
                colors: [
                  accent.withValues(alpha: 0.15),
                  AppColors.bg,
                  AppColors.bg,
                ],
              ),
            ),
          ),
          Positioned(
            top: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TwoHeartsLogo(size: 28),
                      const SizedBox(width: 10),
                      Text(
                        couple != null
                            ? '${me?.displayName.split(' ').first ?? '?'} & ${partner?.displayName.split(' ').first ?? '?'}'
                            : 'Two Hearts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => _showSettings(context),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // Avatar card — tap MY avatar to set mood
                      _AvatarCard(
                        me: me,
                        partner: partner,
                        accent: accent,
                        myMood: moods.where((m) => m.uid == myUid).firstOrNull?.mood,
                        partnerMood: partnerMood,
                        partnerMoodVisible: _partnerMoodVisible,
                        partnerMoodToShow: _partnerMoodToShow,
                        onMyAvatarTap: _showMoodPicker,
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        children: [
                          _StatPill(value: '$daysTogether', label: 'days', accent: accent),
                          const SizedBox(width: 10),
                          _StatPill(value: '${memories.length}', label: 'memories', accent: accent),
                          const SizedBox(width: 10),
                          _StatPill(value: '${letters.length}', label: 'letters', accent: accent),
                        ],
                      ).animate().fadeIn(delay: 150.ms),
                      const SizedBox(height: 16),

                      // On This Day banner
                      if (onThisDay.isNotEmpty) ...[
                        _OnThisDayBanner(memory: onThisDay.first, accent: accent)
                            .animate().fadeIn(delay: 180.ms).slideY(begin: -0.05),
                        const SizedBox(height: 16),
                      ],

                      // Thinking of you — hero button
                      _ThinkingOfYouButton(accent: accent, onTap: _sendThinkingOfYou)
                          .animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                      const SizedBox(height: 12),

                      // Quick send row
                      _QuickSendRow(
                        accent: accent,
                        onMorning: () {
                          HapticFeedback.lightImpact();
                          final coupleId = ref.read(coupleIdProvider);
                          if (coupleId == null) return;
                          ref.read(firestoreServiceProvider)
                              .sendSignal(coupleId, 'goodMorning').ignore();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('☀️ Good morning sent!'),
                            backgroundColor: AppColors.bgCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.all(16),
                          ));
                        },
                        onNight: () {
                          HapticFeedback.lightImpact();
                          final coupleId = ref.read(coupleIdProvider);
                          if (coupleId == null) return;
                          ref.read(firestoreServiceProvider)
                              .sendSignal(coupleId, 'goodNight').ignore();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('🌙 Good night sent!'),
                            backgroundColor: AppColors.bgCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.all(16),
                          ));
                        },
                        onGratitude: () {
                          HapticFeedback.lightImpact();
                          final coupleId = ref.read(coupleIdProvider);
                          if (coupleId == null) return;
                          ref.read(firestoreServiceProvider)
                              .sendSignal(coupleId, 'gratitude').ignore();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('🙏 Gratitude sent!'),
                            backgroundColor: AppColors.bgCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.all(16),
                          ));
                        },
                      ).animate().fadeIn(delay: 220.ms),
                      const SizedBox(height: 16),

                      // Recent memories — clickable
                      if (memories.isNotEmpty) ...[
                        _SectionHeader(title: 'Recent memories', count: memories.length),
                        const SizedBox(height: 10),
                        _MemoryPreview(memories: memories.take(4).toList())
                            .animate().fadeIn(delay: 300.ms),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Floating heart animation
          if (_heartVisible)
            AnimatedBuilder(
              animation: _heartCtrl,
              builder: (_, _) {
                final t = _heartCtrl.value;
                return Positioned(
                  left: MediaQuery.of(context).size.width * _heartX,
                  bottom: 100 + 300 * t,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.0 + t * 0.5,
                      child: const Text('♡',
                          style: TextStyle(fontSize: 40, color: AppColors.rose)),
                    ),
                  ),
                );
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
}

// ── Avatar Card ───────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  final dynamic me;
  final dynamic partner;
  final Color accent;
  final MoodType? myMood;
  final MoodType? partnerMood;
  final bool partnerMoodVisible;
  final MoodType? partnerMoodToShow;
  final VoidCallback onMyAvatarTap;

  const _AvatarCard({
    this.me,
    this.partner,
    required this.accent,
    this.myMood,
    this.partnerMood,
    required this.partnerMoodVisible,
    this.partnerMoodToShow,
    required this.onMyAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // MY avatar — tappable for mood
              Expanded(
                child: GestureDetector(
                  onTap: onMyAvatarTap,
                  child: _CharCol(
                    user: me,
                    color: accent,
                    isMe: true,
                    mood: myMood,
                    showTapHint: true,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TwoHeartsLogo(size: 30),
                  const SizedBox(height: 4),
                  Text('together',
                      style: TextStyle(
                          fontSize: 10, color: accent, letterSpacing: 1)),
                ],
              ),
              // PARTNER avatar — shows mood popup overlay
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _CharCol(
                      user: partner,
                      color: AppColors.lavender,
                      isMe: false,
                      mood: partnerMood,
                    ),
                    if (partnerMoodVisible && partnerMoodToShow != null)
                      Positioned(
                        top: -14,
                        right: 0,
                        left: 0,
                        child: Center(
                          child: _MoodPopup(mood: partnerMoodToShow!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            CharacterAvatar(color: color, name: name, size: 86),
            if (mood != null)
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider, width: 0.5),
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
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (showTapHint)
          Text('tap to share mood',
              style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 0.3)),
      ],
    );
  }
}

// ── Stat Pill ─────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;
  const _StatPill({required this.value, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: [accent, AppColors.coral]).createShader(b),
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Thinking Of You Button ────────────────────────────────────────────────

class _ThinkingOfYouButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _ThinkingOfYouButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.2),
              AppColors.coral.withValues(alpha: 0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, AppColors.coral]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: const Text('♡', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thinking Of You',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text('Tap to send a heart that floats in their room',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

// ── Memory Preview — clickable ─────────────────────────────────────────────

class _MemoryPreview extends StatelessWidget {
  final List<dynamic> memories;
  const _MemoryPreview({required this.memories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: memories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final memory = memories[i];
          return GestureDetector(
            onTap: () => context.push('/memory/${memory.id}'),
            child: Hero(
              tag: 'memory_${memory.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 110,
                  child: memory.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: memory.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppColors.bgCard),
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.bgCard,
                            child: const Icon(Icons.image_outlined,
                                color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          color: AppColors.bgCard,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.textMuted),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── On This Day Banner ────────────────────────────────────────────────────

class _OnThisDayBanner extends StatelessWidget {
  final MemoryModel memory;
  final Color accent;
  const _OnThisDayBanner({required this.memory, required this.accent});

  @override
  Widget build(BuildContext context) {
    final yearsAgo = DateTime.now().year - memory.createdAt.year;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), AppColors.bgCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/memory/${memory.id}'),
            child: Hero(
              tag: 'memory_${memory.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
                child: CachedNetworkImage(
                  imageUrl: memory.imageUrl,
                  width: 80, height: 80,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 80, height: 80, color: AppColors.bgCard,
                    child: const Icon(Icons.photo_outlined,
                        color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('📅 ', style: TextStyle(fontSize: 14)),
                  Text('$yearsAgo year${yearsAgo == 1 ? '' : 's'} ago today',
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text(
                  memory.caption?.isNotEmpty == true
                      ? memory.caption!
                      : 'A memory from this day',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── Quick Send Row ────────────────────────────────────────────────────────

class _QuickSendRow extends StatelessWidget {
  final Color accent;
  final VoidCallback onMorning;
  final VoidCallback onNight;
  final VoidCallback onGratitude;

  const _QuickSendRow({
    required this.accent,
    required this.onMorning,
    required this.onNight,
    required this.onGratitude,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _QuickBtn(emoji: '☀️', label: 'Morning',
            onTap: onMorning, accent: accent)),
        const SizedBox(width: 8),
        Expanded(child: _QuickBtn(emoji: '🌙', label: 'Night',
            onTap: onNight, accent: accent)),
        const SizedBox(width: 8),
        Expanded(child: _QuickBtn(emoji: '🙏', label: 'Grateful',
            onTap: onGratitude, accent: accent)),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  const _QuickBtn({
    required this.emoji,
    required this.label,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Your colour', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kCoupleAccents.map((a) {
              final color = a['color'] as Color;
              final selected = couple?.themeColor == color.toARGB32();
              return GestureDetector(
                onTap: () async {
                  if (couple != null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateCoupleTheme(couple.id, color.toARGB32());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 12)]
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
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded,
                      color: AppColors.textMuted, size: 20),
                  SizedBox(width: 12),
                  Text('Sign out',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
