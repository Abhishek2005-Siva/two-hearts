import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firebase/models.dart';
import '../../core/models/content_block.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/rich_content_viewer.dart';

class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final bucket = ref.watch(bucketListProvider).valueOrNull ?? [];
    final journal = ref.watch(journalProvider).valueOrNull ?? [];
    final cinema = ref.watch(cinemaSessionProvider).valueOrNull;
    final partnerOnline = ref.watch(partnerOnlineProvider).valueOrNull ?? false;
    final nowShowing = (cinema?['title'] as String?)?.trim();

    final unlockedLetters = letters.where((l) => l.isUnlocked && !l.opened).length;
    final bucketDone = bucket.where((b) => b.status == BucketStatus.done).length;
    final wildcards = ref.watch(wildcardsProvider).valueOrNull ?? [];
    final wildcardsUnredeemed = wildcards.where((w) => !w.redeemed).length;
    final todayKey = _todayKey();
    final todayEntry = journal.where((j) => j.id == todayKey).firstOrNull;

    final hero = _pickTonightsPick(
      context: context,
      ref: ref,
      accent: accent,
      cinemaActive: cinema != null,
      nowShowing: nowShowing,
      unlockedLetters: unlockedLetters,
      hasWrittenToday: todayEntry != null,
    );

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _Header(
                accent: accent,
                onSurpriseMe: () => _surpriseMe(context, ref, accent),
              ).animate().fadeIn(),
              const SizedBox(height: 20),
              _HeroPickCard(accent: accent, pick: hero)
                  .animate()
                  .fadeIn(delay: 80.ms)
                  .slideY(begin: 0.04),
              const SizedBox(height: 28),

              _SectionHeader(title: 'Share Together'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      emoji: '📖',
                      title: 'Journal',
                      subtitle: todayEntry == null
                          ? 'Write today\'s thoughts'
                          : todayEntry.bothSubmitted
                              ? 'Both wrote — read it ♡'
                              : 'You wrote — waiting on them',
                      badge: todayEntry != null && !todayEntry.bothSubmitted
                          ? '1/2'
                          : null,
                      colors: const [Color(0xFF6E4A2E), Color(0xFF3E2A19)],
                      onTap: () => context.push('/together/journal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      emoji: '💌',
                      title: 'Letters',
                      subtitle: unlockedLetters > 0
                          ? '$unlockedLetters waiting to open'
                          : letters.isEmpty
                              ? 'None yet ♡'
                              : '${letters.length} for you',
                      badge: unlockedLetters > 0 ? 'New' : null,
                      colors: const [Color(0xFF7A2E44), Color(0xFF44182A)],
                      onTap: () => _showLettersSheet(context, ref, accent),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.04),
              const SizedBox(height: 28),

              _SectionHeader(title: 'Play Together'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      emoji: '🎮',
                      title: 'Games',
                      subtitle: 'WYR, Truth, RPS & more',
                      badge: partnerOnline ? 'Online' : null,
                      colors: const [Color(0xFF243156), Color(0xFF141B30)],
                      onTap: () => context.push('/games'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      emoji: '🍿',
                      title: 'Movie Night',
                      subtitle: cinema != null
                          ? (nowShowing != null && nowShowing.isNotEmpty
                              ? 'Playing: $nowShowing'
                              : 'Playing now — join in')
                          : 'Perfect for tonight',
                      badge: cinema != null ? 'Live' : null,
                      colors: const [Color(0xFF2A2149), Color(0xFF17122B)],
                      onTap: () => context.push('/cinema'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04),
              const SizedBox(height: 28),

              _SectionHeader(title: 'Plan Together'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      emoji: '🏔️',
                      title: 'Bucket List',
                      subtitle: bucket.isEmpty
                          ? 'Start dreaming together'
                          : '$bucketDone / ${bucket.length} done',
                      progress: bucket.isEmpty ? null : bucketDone / bucket.length,
                      colors: const [Color(0xFF1F4A45), Color(0xFF112B28)],
                      onTap: () => context.push('/together/bucket'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      emoji: '🎡',
                      title: 'Date Idea',
                      subtitle: 'Spin for a surprise date',
                      colors: const [Color(0xFF432A5E), Color(0xFF251937)],
                      onTap: () => context.push('/dates'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 260.ms).slideY(begin: 0.04),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      emoji: '📍',
                      title: 'Destinations',
                      subtitle: 'Pin dream spots',
                      colors: const [Color(0xFF1F4058), Color(0xFF122733)],
                      onTap: () => context.push('/places'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeatureCard(
                      emoji: '📚',
                      title: 'Books',
                      subtitle: 'Shared reading list',
                      colors: const [Color(0xFF5E3A2A), Color(0xFF332016)],
                      onTap: () => context.push('/books'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.04),
              const SizedBox(height: 12),
              _FeatureCard(
                emoji: '🃏',
                title: 'Wildcards',
                subtitle: wildcards.isEmpty
                    ? 'Special favors, just for us ♡'
                    : '$wildcardsUnredeemed waiting to be redeemed',
                colors: const [Color(0xFF5E1F3A), Color(0xFF2E0F1D)],
                onTap: () => context.push('/together/wildcards'),
              ).animate().fadeIn(delay: 330.ms).slideY(begin: 0.04),
              const SizedBox(height: 28),

              _SectionHeader(title: 'Quick Picks'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickPick(
                      icon: Icons.style_rounded,
                      label: 'Random\nQuestion',
                      accent: accent,
                      onTap: () => _showRandomQuestion(context, accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPick(
                      icon: Icons.favorite_rounded,
                      label: 'Love\nQuiz',
                      accent: accent,
                      onTap: () => context.push('/games'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPick(
                      icon: Icons.mood_rounded,
                      label: 'Mood\nCheck',
                      accent: accent,
                      onTap: () => _showMoodCheck(context, ref, accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPick(
                      icon: Icons.monetization_on_rounded,
                      label: 'Coin\nToss',
                      accent: accent,
                      onTap: () => _showCoinToss(context, accent),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 360.ms),
            ],
          ),
        ),
      ),
    );
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Tonight's Pick — a real, data-driven suggestion, not a fixed demo ──

  _TonightsPick _pickTonightsPick({
    required BuildContext context,
    required WidgetRef ref,
    required Color accent,
    required bool cinemaActive,
    required String? nowShowing,
    required int unlockedLetters,
    required bool hasWrittenToday,
  }) {
    if (cinemaActive) {
      return _TonightsPick(
        tag: 'PLAYING NOW',
        emoji: '🍿',
        title: 'Movie Night',
        subtitle: nowShowing != null && nowShowing.isNotEmpty
            ? 'Now playing: $nowShowing'
            : 'A movie is playing — jump in',
        cta: 'Join now',
        onTap: () => context.push('/cinema'),
      );
    }
    if (unlockedLetters > 0) {
      return _TonightsPick(
        tag: 'WAITING FOR YOU',
        emoji: '💌',
        title: 'A Letter Arrived',
        subtitle: '$unlockedLetters letter${unlockedLetters > 1 ? 's' : ''} '
            'to open ♡',
        cta: 'Open it',
        onTap: () => _showLettersSheet(context, ref, accent),
      );
    }
    if (!hasWrittenToday) {
      return _TonightsPick(
        tag: "TONIGHT'S PICK",
        emoji: '📖',
        title: 'Journal Together',
        subtitle: 'Write down today before it fades ♡',
        cta: 'Write now',
        onTap: () => context.push('/together/journal'),
      );
    }
    return _TonightsPick(
      tag: "TONIGHT'S PICK",
      emoji: '🎮',
      title: 'Game Night',
      subtitle: 'WYR, Truth, RPS & more — who\'s in?',
      cta: 'Play now',
      onTap: () => context.push('/games'),
    );
  }

  void _surpriseMe(BuildContext context, WidgetRef ref, Color accent) {
    HapticFeedback.mediumImpact();
    final options = <VoidCallback>[
      () => context.push('/games'),
      () => context.push('/cinema'),
      () => context.push('/dates'),
      () => context.push('/together/bucket'),
      () => context.push('/together/journal'),
      () => context.push('/places'),
      () => _showLettersSheet(context, ref, accent),
      () => _showRandomQuestion(context, accent),
      () => _showCoinToss(context, accent),
    ]..shuffle();
    options.first();
  }

  void _showLettersSheet(BuildContext context, WidgetRef ref, Color accent) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _LettersSheet(accent: accent),
      ),
    );
  }

  static const _questions = [
    'What\'s a small thing I did recently that made you smile?',
    'If we could teleport anywhere for one evening, where would we go?',
    'What\'s one thing you want us to try together this year?',
    'What\'s your favourite memory of us so far?',
    'What made you fall for me a little more this week?',
    'If our love story was a movie, what would the title be?',
    'What\'s something you\'ve never told me but want to?',
    'What\'s a tiny habit of mine you secretly love?',
    'What song reminds you of us?',
    'What\'s one dream you want us to chase together?',
  ];

  void _showRandomQuestion(BuildContext context, Color accent) {
    HapticFeedback.selectionClick();
    final q = _questions[math.Random().nextInt(_questions.length)];
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎴', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 16),
              Text(q,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _showRandomQuestion(context, accent);
                    },
                    child: const Text('Another one',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogCtx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient:
                            LinearGradient(colors: [accent, AppColors.coral]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Done',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoodCheck(BuildContext context, WidgetRef ref, Color accent) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24,
            MediaQuery.of(sheetCtx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How are you feeling?',
                style: Theme.of(sheetCtx).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Your partner will see your vibe ♡',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: MoodType.values.map((mood) {
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    HapticFeedback.lightImpact();
                    await ref.read(firestoreServiceProvider).setMood(coupleId, mood);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(mood.label,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
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

  void _showCoinToss(BuildContext context, Color accent) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => _CoinTossDialog(accent: accent),
    );
  }
}

class _TonightsPick {
  final String tag;
  final String emoji;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
  _TonightsPick({
    required this.tag,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Color accent;
  final VoidCallback onSurpriseMe;
  const _Header({required this.accent, required this.onSurpriseMe});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Let\'s spend time\ntogether',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 26, height: 1.2)),
              const SizedBox(height: 6),
              const Text('Pick something and create a memory today.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SquishyTap(
          onTap: onSurpriseMe,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shuffle_rounded, color: accent, size: 20),
                const SizedBox(height: 4),
                Text('Surprise\nMe',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: accent, fontSize: 10, fontWeight: FontWeight.w700, height: 1.2)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hero "Tonight's Pick" card ───────────────────────────────────────────

class _HeroPickCard extends StatelessWidget {
  final Color accent;
  final _TonightsPick pick;
  const _HeroPickCard({required this.accent, required this.pick});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: pick.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.28),
              AppColors.coral.withValues(alpha: 0.12),
              AppColors.bgCard,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 30),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -10,
              bottom: -18,
              child: Opacity(
                opacity: 0.18,
                child: Text(pick.emoji, style: const TextStyle(fontSize: 110)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pick.tag,
                    style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(pick.title,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontSize: 26)),
                const SizedBox(height: 8),
                Text(pick.subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4)),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withValues(alpha: 0.4), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pick.cta,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

// ── Feature card (used in the 2-up rows) ─────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? badge;
  final double? progress;
  final List<Color> colors;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.badge,
    this.progress,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        height: 152,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -8,
              bottom: -10,
              child: Opacity(
                opacity: 0.16,
                child: Text(emoji, style: const TextStyle(fontSize: 64)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11.5,
                            height: 1.3)),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick pick chip ───────────────────────────────────────────────────────

class _QuickPick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _QuickPick({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Coin toss ─────────────────────────────────────────────────────────────

class _CoinTossDialog extends StatefulWidget {
  final Color accent;
  const _CoinTossDialog({required this.accent});

  @override
  State<_CoinTossDialog> createState() => _CoinTossDialogState();
}

class _CoinTossDialogState extends State<_CoinTossDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool? _heads;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _flip();
  }

  void _flip() {
    setState(() => _heads = null);
    _ctrl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _heads = math.Random().nextBool());
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) {
                final spin = _ctrl.value * 10 * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.003)
                    ..rotateY(spin),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [widget.accent, AppColors.coral]),
                      boxShadow: [
                        BoxShadow(
                            color: widget.accent.withValues(alpha: 0.4),
                            blurRadius: 20),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _heads == null ? '🪙' : (_heads! ? 'H' : 'T'),
                        style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _heads == null
                  ? 'Flipping…'
                  : (_heads! ? 'Heads! 🎉' : 'Tails! 🎉'),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _heads == null ? null : _flip,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [widget.accent, AppColors.coral]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Flip again',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Letters Sheet ─────────────────────────────────────────────────────────
// Only shows letters the current user received (sender cannot see their own sent letters).
// Locked letters are invisible.

class _LettersSheet extends ConsumerStatefulWidget {
  final Color accent;
  const _LettersSheet({required this.accent});

  @override
  ConsumerState<_LettersSheet> createState() => _LettersSheetState();
}

class _LettersSheetState extends ConsumerState<_LettersSheet> {
  bool _showSent = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    // lettersProvider already filters to receiver-only + unlocked-only
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];
    final sentLetters = ref.watch(sentLettersProvider).valueOrNull ?? [];
    final partnerUid = ref.watch(partnerUserProvider).valueOrNull?.uid;

    return _Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Letters 💌', style: Theme.of(context).textTheme.titleLarge),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/together/letter/new');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.coral]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Write',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _LetterTabButton(
                    label: 'Received',
                    selected: !_showSent,
                    accent: accent,
                    onTap: () => setState(() => _showSent = false),
                  ),
                ),
                Expanded(
                  child: _LetterTabButton(
                    label: 'Sent',
                    selected: _showSent,
                    accent: accent,
                    onTap: () => setState(() => _showSent = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _showSent
                ? 'Long-press a letter to see how many times it\'s been opened ♡'
                : 'Letters written for you — locked ones are invisible until they unlock ♡',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (_showSent) ...[
            if (sentLetters.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'You haven\'t sent any letters yet ♡',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...sentLetters.map((l) => _SentLetterTile(
                    letter: l,
                    accent: accent,
                    partnerUid: partnerUid,
                  )),
          ] else ...[
            if (letters.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No letters from your partner yet.\nThey\'ll write you something special ♡',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              ...letters.map((l) => _LetterTile(letter: l, accent: accent, ref: ref)),
          ],
        ],
      ),
    );
  }
}

class _LetterTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _LetterTabButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SentLetterTile extends StatelessWidget {
  final LetterModel letter;
  final Color accent;
  final String? partnerUid;

  const _SentLetterTile({required this.letter, required this.accent, required this.partnerUid});

  @override
  Widget build(BuildContext context) {
    final viewCount = letter.viewCountOf(partnerUid);
    return GestureDetector(
      onLongPress: () => _showViewCount(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            const Text('📤', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(letter.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    letter.isUnlocked ? 'Unlocked' : 'Still locked',
                    style: TextStyle(fontSize: 12, color: accent),
                  ),
                ],
              ),
            ),
            Icon(Icons.remove_red_eye_outlined, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 4),
            Text('$viewCount', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showViewCount(BuildContext context) {
    HapticFeedback.mediumImpact();
    final viewCount = letter.viewCountOf(partnerUid);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('"${letter.title}"', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          viewCount == 0
              ? 'Not opened yet ♡'
              : 'Opened $viewCount time${viewCount == 1 ? '' : 's'} ♡',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }
}

class _LetterTile extends StatelessWidget {
  final LetterModel letter;
  final Color accent;
  final WidgetRef ref;
  const _LetterTile({required this.letter, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Receiver can open & re-read unlimited times; opened flag is just informational
    return GestureDetector(
      onTap: () => _openLetter(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !letter.opened ? accent.withValues(alpha: 0.5) : AppColors.divider,
            width: !letter.opened ? 1.5 : 0.5,
          ),
          boxShadow: !letter.opened
              ? [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12)]
              : null,
        ),
        child: Row(
          children: [
            Text(letter.opened ? '📬' : '💌', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(letter.title, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    letter.opened ? 'Tap to read again ♡' : 'Tap to open ♡',
                    style: TextStyle(fontSize: 12, color: accent),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 18),
          ],
        ),
      ),
    );
  }

  void _openLetter(BuildContext context) {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    // Mark as opened (idempotent)
    ref.read(firestoreServiceProvider).openLetter(coupleId, letter.id).ignore();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      ref.read(firestoreServiceProvider).incrementLetterView(coupleId, letter.id, myUid).ignore();
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💌', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(letter.title, style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _LetterBody(body: letter.body),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Close ♡',
                onTap: () => Navigator.pop(dialogCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Letter body renderer ──────────────────────────────────────────────────

class _LetterBody extends StatelessWidget {
  final String body;
  const _LetterBody({required this.body});

  List<ContentBlock> _parseBlocks(String raw) {
    if (raw.trimLeft().startsWith('[')) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((m) => ContentBlock.fromMap(m as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    return [ContentBlock(id: '0', type: BlockType.text, text: raw, textSize: TextSize.body)];
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(body);
    if (blocks.length == 1 && blocks.first.type == BlockType.text) {
      return Text(
        blocks.first.text ?? '',
        style: const TextStyle(fontSize: 16, height: 1.75, color: AppColors.textPrimary),
      );
    }
    return RichContentViewer(blocks: blocks);
  }
}

// ── Shared bottom sheet wrapper ───────────────────────────────────────────

class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
