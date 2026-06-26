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
                title: Text('You & Me'),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

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

                    // Mood picker
                    _SectionLabel(label: 'HOW ARE YOU FEELING?'),
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
                      _SectionLabel(
                          label: '${partner.displayName.split(' ').first.toUpperCase()}\'S VIBE'),
                      const SizedBox(height: 10),
                      GlassCard(
                        child: partnerMood != null
                            ? Row(
                                children: [
                                  Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.bgCard,
                                      border: Border.all(color: AppColors.divider, width: 0.5),
                                    ),
                                    child: Center(
                                      child: Text(partnerMood.mood.emoji,
                                          style: const TextStyle(fontSize: 34)),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('They haven\'t shared their mood yet',
                                      style: Theme.of(context).textTheme.bodyMedium),
                                ),
                              ),
                      ).animate().fadeIn(delay: 100.ms),
                      const SizedBox(height: 20),
                    ],

                    // Profile / personal details
                    _SectionLabel(label: 'YOUR PROFILE'),
                    const SizedBox(height: 10),
                    _ProfileCard(me: me, accent: accent, ref: ref)
                        .animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 20),

                    // Partner details (read-only)
                    if (partner != null) ...[
                      _SectionLabel(
                          label: '${partner.displayName.split(' ').first.toUpperCase()}\'S DETAILS'),
                      const SizedBox(height: 10),
                      _PartnerDetailsCard(partner: partner, accent: accent)
                          .animate().fadeIn(delay: 250.ms),
                    ],
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

// ── Profile Card ──────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel? me;
  final Color accent;
  final WidgetRef ref;
  const _ProfileCard({required this.me, required this.accent, required this.ref});

  @override
  Widget build(BuildContext context) {
    final birthday = me?.birthday;
    final age = birthday != null ? _calcAge(birthday) : null;

    return GlassCard(
      child: Column(
        children: [
          // Avatar + name row
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [accent, AppColors.coral]),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(
                    me?.displayName.isNotEmpty == true
                        ? me!.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me?.displayName ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(me?.email ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 14),

          // Birthday row
          _DetailRow(
            icon: Icons.cake_outlined,
            label: 'Birthday',
            value: birthday != null
                ? '${_monthName(birthday.month)} ${birthday.day}'
                    '${age != null ? '  (${age}y)' : ''}'
                : 'Tap to set',
            missing: birthday == null,
            accent: accent,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: birthday ?? DateTime(DateTime.now().year - 20),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                helpText: 'Select your birthday',
                builder: (ctx, child) => Theme(
                  data: _pickerTheme(ctx, accent),
                  child: child!,
                ),
              );
              if (picked != null) {
                await ref.read(firestoreServiceProvider).updateBirthday(picked);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Partner Details Card ──────────────────────────────────────────────────

class _PartnerDetailsCard extends StatelessWidget {
  final UserModel partner;
  final Color accent;
  const _PartnerDetailsCard({required this.partner, required this.accent});

  @override
  Widget build(BuildContext context) {
    final birthday = partner.birthday;
    final age = birthday != null ? _calcAge(birthday) : null;
    final daysUntil = partner.nextBirthday != null
        ? DateTime.now().difference(partner.nextBirthday!).inDays.abs()
        : null;

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lavender.withValues(alpha: 0.2),
                  border: Border.all(color: AppColors.lavender.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    partner.displayName.isNotEmpty ? partner.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: AppColors.lavender),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(partner.displayName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
          if (birthday != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.cake_outlined,
              label: 'Birthday',
              value: '${_monthName(birthday.month)} ${birthday.day}'
                  '${age != null ? '  (${age}y)' : ''}'
                  '${daysUntil != null && daysUntil <= 30 ? '  🎉 ${daysUntil}d away!' : ''}',
              accent: AppColors.lavender,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 16),
                const SizedBox(width: 8),
                Text('${partner.displayName.split(' ').first} hasn\'t set their birthday yet',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Detail Row ────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool missing;
  final Color accent;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.missing = false,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      color: missing ? AppColors.textMuted : AppColors.textPrimary,
                      fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                    )),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.edit_outlined, color: accent.withValues(alpha: 0.7), size: 16),
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

// ── Section Label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
            color: AppColors.textMuted, letterSpacing: 1.5));
  }
}

// ── Mood Picker ───────────────────────────────────────────────────────────

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(colors: [accent.withValues(alpha: 0.3),
                      AppColors.coral.withValues(alpha: 0.2)])
                  : null,
              color: selected ? null : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? accent : AppColors.divider,
                width: selected ? 1.5 : 0.5,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: accent.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mood.emoji, style: TextStyle(fontSize: selected ? 22 : 20)),
                const SizedBox(width: 6),
                Text(mood.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

int _calcAge(DateTime birthday) {
  final now = DateTime.now();
  int age = now.year - birthday.year;
  if (now.month < birthday.month ||
      (now.month == birthday.month && now.day < birthday.day)) {
    age--;
  }
  return age;
}

String _monthName(int month) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return months[month];
}

ThemeData _pickerTheme(BuildContext context, Color accent) {
  return Theme.of(context).copyWith(
    colorScheme: ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.textPrimary,
    ),
  );
}
