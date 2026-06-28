import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class YouAndMeScreen extends ConsumerWidget {
  const YouAndMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final accent = ref.watch(accentColorProvider);
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final moods = ref.watch(moodsProvider).valueOrNull ?? [];
    final uid = authUser.uid;

    final myMood = moods.where((m) => m.uid == uid).firstOrNull;
    final partnerMood = moods.where((m) => m.uid != uid).firstOrNull;
    final bothHaveMood = myMood != null && partnerMood != null;

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
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                title: Text('Settings'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Appearance toggle
                    _AppearanceSection(accent: accent),
                    const SizedBox(height: 20),

                    // Mood match banner
                    if (bothHaveMood) ...[
                      _MoodMatchCard(
                        myMood: myMood.mood,
                        partnerMood: partnerMood.mood,
                        partnerName: partner?.displayName.split(' ').first ?? 'Partner',
                        accent: accent,
                      ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
                      const SizedBox(height: 20),
                    ],

                    // Compatibility score
                    _CompatibilityCard(accent: accent, ref: ref)
                        .animate().fadeIn(delay: 50.ms),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ── Appearance Section ────────────────────────────────────────────────────

class _AppearanceSection extends ConsumerWidget {
  final Color accent;
  const _AppearanceSection({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text(isDark ? 'Dark mode' : 'Light mode',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: isDark,
            onChanged: (val) {
              ref.read(themeModeProvider.notifier).state =
                  val ? ThemeMode.dark : ThemeMode.light;
            },
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}

// ── Mood Match Banner ─────────────────────────────────────────────────────

class _MoodMatchCard extends StatelessWidget {
  final MoodType myMood;
  final MoodType partnerMood;
  final String partnerName;
  final Color accent;

  const _MoodMatchCard({
    required this.myMood,
    required this.partnerMood,
    required this.partnerName,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final matched = myMood == partnerMood;
    final message = moodComboMessage(myMood, partnerMood);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: matched
              ? [accent.withValues(alpha: 0.25), AppColors.rose.withValues(alpha: 0.15)]
              : [AppColors.bgCard.withValues(alpha: 0.9), AppColors.bgMid.withValues(alpha: 0.8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: matched ? accent.withValues(alpha: 0.4) : AppColors.divider,
          width: matched ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MoodBubble(mood: myMood, label: 'You', accent: accent),
              const SizedBox(width: 16),
              matched
                  ? const Text('💞', style: TextStyle(fontSize: 28))
                  : const Text('↔️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              _MoodBubble(mood: partnerMood, label: partnerName, accent: accent),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _MoodBubble extends StatelessWidget {
  final MoodType mood;
  final String label;
  final Color accent;
  const _MoodBubble({required this.mood, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCard,
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Center(child: Text(mood.emoji, style: const TextStyle(fontSize: 32))),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(mood.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

// ── Compatibility Card ────────────────────────────────────────────────────

class _CompatibilityCard extends ConsumerWidget {
  final Color accent;
  final WidgetRef ref;
  const _CompatibilityCard({required this.accent, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(compatibilityStatsProvider);

    return GlassCard(
      child: statsAsync.when(
        loading: () => const Center(child: SizedBox(height: 60,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))),
        error: (_, _) => const SizedBox.shrink(),
        data: (stats) {
          final total = stats['total'] ?? 0;
          final matched = stats['matched'] ?? 0;
          final pct = total == 0 ? 0.0 : matched / total;
          final pctInt = (pct * 100).round();

          String label;
          String emoji;
          if (total == 0) {
            label = 'Play Would You Rather to see your score!';
            emoji = '🎯';
          } else if (pctInt >= 80) {
            label = 'You two are basically the same person 💕';
            emoji = '💞';
          } else if (pctInt >= 60) {
            label = 'Beautifully compatible ✨';
            emoji = '✨';
          } else if (pctInt >= 40) {
            label = 'Wonderfully different — opposites attract!';
            emoji = '🤝';
          } else {
            label = 'You keep each other interesting 😄';
            emoji = '🌟';
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compatibility Score',
                            style: TextStyle(fontSize: 11, color: accent,
                                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(label, style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary, height: 1.3)),
                      ],
                    ),
                  ),
                  if (total > 0)
                    Text('$pctInt%', style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800, color: accent)),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Matched $matched of $total questions',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ],
          );
        },
      ),
    );
  }
}

