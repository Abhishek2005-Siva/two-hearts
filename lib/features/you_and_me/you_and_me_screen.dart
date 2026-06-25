import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class YouAndMeScreen extends ConsumerWidget {
  const YouAndMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final moodsAsync = ref.watch(moodsProvider);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final moods = moodsAsync.valueOrNull ?? [];
    final myMood = moods.where((m) => m.uid == uid).firstOrNull;
    final partnerMood = moods.where((m) => m.uid != uid).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('You & Me')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Mood section
          Text('How are you feeling?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _MoodPicker(
            currentMood: myMood?.mood,
            accent: accent,
            onSelect: (mood) async {
              final coupleId = ref.read(coupleIdProvider)!;
              await ref.read(firestoreServiceProvider).setMood(coupleId, mood);
            },
          ).animate().fadeIn(),
          const SizedBox(height: 24),

          // Partner mood
          if (partner != null) ...[
            Text("${partner.displayName.split(' ').first}'s mood",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Text(
                    partnerMood?.mood.emoji ?? '—',
                    style: const TextStyle(fontSize: 44),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerMood?.mood.label ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (partnerMood != null)
                        Text(
                          'Updated ${_timeAgo(partnerMood.updatedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 24),
          ],

          // Profile section
          Text('You', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: accent.withOpacity(0.2),
                  child: Text(
                    me?.displayName.isNotEmpty == true ? me!.displayName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 22, color: accent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me?.displayName ?? '', style: Theme.of(context).textTheme.titleMedium),
                      Text(me?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Level ${me?.level ?? 1}',
                          style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
        ],
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

class _MoodPicker extends StatelessWidget {
  final MoodType? currentMood;
  final Color accent;
  final void Function(MoodType) onSelect;

  const _MoodPicker({
    this.currentMood,
    required this.accent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: MoodType.values.map((mood) {
        final selected = currentMood == mood;
        return GestureDetector(
          onTap: () => onSelect(mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? accent : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  mood.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? accent : AppColors.darkBrown,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
