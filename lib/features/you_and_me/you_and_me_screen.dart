import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    const SizedBox(height: 20),

                    // Partner pairing
                    const _PartnerCodeSection()
                        .animate().fadeIn(delay: 100.ms),
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

// ── Partner Code Section ──────────────────────────────────────────────────

class _PartnerCodeSection extends StatefulWidget {
  const _PartnerCodeSection();

  @override
  State<_PartnerCodeSection> createState() => _PartnerCodeSectionState();
}

class _PartnerCodeSectionState extends State<_PartnerCodeSection> {
  final _codeCtrl = TextEditingController();
  String? _generatedCode;
  bool _showEnter = false;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final code = await FirestoreService().createInviteCode();
      setState(() => _generatedCode = code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final couple = await FirestoreService().redeemInviteCode(code);
      if (couple == null) {
        setState(() => _error = 'Code not found or already used.');
      } else {
        setState(() { _success = true; _showEnter = false; });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connect with partner',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Generate a code or enter your partner\'s code',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          if (_success) ...[
            const Row(
              children: [
                Icon(Icons.favorite_rounded, color: AppColors.rose, size: 18),
                SizedBox(width: 8),
                Text('Connected! ♡', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600)),
              ],
            ),
          ] else if (_generatedCode != null) ...[
            // Show generated code
            Center(
              child: Column(
                children: [
                  const Text('Share this code with your partner',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _generatedCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Code copied!'),
                          backgroundColor: AppColors.bgCard,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _generatedCode!,
                            style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold,
                              letterSpacing: 8, color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 8, height: 8,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose)),
                      SizedBox(width: 8),
                      Text('Waiting for partner…',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (_showEnter) ...[
            // Enter partner code
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24, letterSpacing: 8,
                fontWeight: FontWeight.bold, color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(counterText: '', hintText: '······'),
              onSubmitted: (_) => _redeem(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _redeem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Connect ♡', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() { _showEnter = false; _error = null; }),
              child: const Text('Back', style: TextStyle(color: AppColors.textMuted)),
            ),
          ] else ...[
            // Choice buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: _loading
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose))
                        : const Icon(Icons.add_link_rounded, size: 16),
                    label: const Text('Generate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.rose,
                      side: BorderSide(color: AppColors.rose.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() { _showEnter = true; _error = null; }),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16),
                    label: const Text('Enter Code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      side: BorderSide(color: AppColors.coral.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ],
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

