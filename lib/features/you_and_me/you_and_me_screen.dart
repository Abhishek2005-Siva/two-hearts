import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/cloudinary_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';

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

                    // Profile picture
                    const _ProfilePicSection()
                        .animate().fadeIn(),
                    const SizedBox(height: 20),

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

                    // Once you're connected, you're connected — forever ♡
                    if (partner != null)
                      _ForeverCard(partner: partner, accent: accent)
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

// ── Forever Card — you two are locked in ♡ ────────────────────────────────

class _ForeverCard extends StatelessWidget {
  final UserModel partner;
  final Color accent;
  const _ForeverCard({required this.partner, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            AppColors.coral.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (partner.avatarUrl != null)
            CircleAvatar(
                radius: 22,
                backgroundImage:
                    CachedNetworkImageProvider(partner.avatarUrl!))
          else
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.2),
              child: Text(
                partner.displayLabel.isNotEmpty
                    ? partner.displayLabel[0].toUpperCase()
                    : '♡',
                style: TextStyle(
                    color: accent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connected with ${partner.displayLabel}',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Two hearts, one bond — forever ♡',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Text('🔒', style: TextStyle(fontSize: 20)),
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
              ref
                  .read(themeModeProvider.notifier)
                  .set(val ? ThemeMode.dark : ThemeMode.light);
            },
            activeThumbColor: accent,
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

// ── Profile Picture Section ───────────────────────────────────────────────

class _ProfilePicSection extends ConsumerStatefulWidget {
  const _ProfilePicSection();

  @override
  ConsumerState<_ProfilePicSection> createState() => _ProfilePicSectionState();
}

class _ProfilePicSectionState extends ConsumerState<_ProfilePicSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes, folder: 'avatars');
      await ref.read(firestoreServiceProvider).updateUser({'avatarUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated ♡'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final myUser = ref.watch(currentUserProvider).valueOrNull;
    final accent = ref.watch(accentColorProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            // Tap the picture to view it fullscreen; use the edit badge or
            // "Change Photo" button to replace it.
            onTap: _uploading
                ? null
                : myUser?.avatarUrl != null
                    ? () => FullscreenImageViewer.open(
                        context, myUser!.avatarUrl!)
                    : _pickAndUpload,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  backgroundImage: myUser?.avatarUrl != null
                      ? CachedNetworkImageProvider(myUser!.avatarUrl!)
                      : null,
                  child: myUser?.avatarUrl == null
                      ? Text(
                          authUser?.displayName?.isNotEmpty == true
                              ? authUser!.displayName![0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: accent,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                if (_uploading)
                  const Positioned.fill(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.black54,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgCard, width: 2),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile picture',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text('Shows next to your name in chat',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _uploading ? null : _pickAndUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _uploading ? 'Uploading…' : 'Change Photo',
                      style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

