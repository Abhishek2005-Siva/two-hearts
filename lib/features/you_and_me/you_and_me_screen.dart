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
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final moods = ref.watch(moodsProvider).valueOrNull ?? [];
    final uid = authUser.uid;

    final myMood = moods.where((m) => m.uid == uid).firstOrNull;
    final partnerMood = moods.where((m) => m.uid != uid).firstOrNull;

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
                title: Text('You & Me'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // My mood
                    _SectionLabel(label: 'YOUR MOOD'),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: _MoodPicker(
                        current: myMood?.mood,
                        accent: accent,
                        onSelect: (mood) async {
                          final coupleId = ref.read(coupleIdProvider);
                          if (coupleId == null) return;
                          await ref.read(firestoreServiceProvider).setMood(coupleId, mood);
                        },
                      ),
                    ).animate().fadeIn(),
                    const SizedBox(height: 20),

                    // Partner mood
                    if (partner != null) ...[
                      _SectionLabel(label: '${partner.displayName.split(' ').first.toUpperCase()}\'S MOOD'),
                      const SizedBox(height: 10),
                      GlassCard(
                        child: partnerMood != null
                            ? Row(
                                children: [
                                  Text(partnerMood.mood.emoji,
                                      style: const TextStyle(fontSize: 48)),
                                  const SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(partnerMood.mood.label,
                                          style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 4),
                                      Text(_timeAgo(partnerMood.updatedAt),
                                          style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ),
                                ],
                              )
                            : Center(
                                child: Text('They haven\'t set a mood yet',
                                    style: Theme.of(context).textTheme.bodyMedium),
                              ),
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 20),
                    ],

                    // Profile card
                    _SectionLabel(label: 'YOU'),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [accent, AppColors.coral],
                              ),
                              boxShadow: [
                                BoxShadow(color: accent.withValues(alpha: 0.4),
                                    blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                me?.displayName.isNotEmpty == true
                                    ? me!.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(me?.displayName ?? '',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(me?.email ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('Level ${me?.level ?? 1}',
                                      style: TextStyle(fontSize: 11, color: accent,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold,
            color: AppColors.textMuted, letterSpacing: 1.5));
  }
}

class _MoodPicker extends StatelessWidget {
  final MoodType? current;
  final Color accent;
  final void Function(MoodType) onSelect;

  const _MoodPicker({this.current, required this.accent, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: MoodType.values.map((mood) {
        final selected = current == mood;
        return GestureDetector(
          onTap: () => onSelect(mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(colors: [accent.withValues(alpha: 0.3), AppColors.coral.withValues(alpha: 0.2)])
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
                Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(mood.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
