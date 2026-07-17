import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                child: Text('Settings',
                    style: Theme.of(context).textTheme.displayMedium),
              ).animate().fadeIn(),
              const SizedBox(height: 24),

              // Profile picture
              const _ProfilePicSection().animate().fadeIn(delay: 40.ms),
              const SizedBox(height: 20),

              // Nickname — what your partner sees in chat & notifications
              const _NicknameSection().animate().fadeIn(delay: 60.ms),
              const SizedBox(height: 20),

              // Appearance toggle
              _AppearanceSection(accent: accent)
                  .animate().fadeIn(delay: 80.ms),
              const SizedBox(height: 20),

              // Love Dial Connection — mood link, alerts, theme
              _LoveDialCard(accent: accent, partner: partner)
                  .animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 20),

              // Once you're connected, you're connected — forever ♡
              if (partner != null)
                _ForeverCard(partner: partner, accent: accent)
                    .animate().fadeIn(delay: 160.ms),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 16),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance',
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

// ── Love Dial Connection — mood link + alerts + theme, all in one card ───

class _LoveDialCard extends ConsumerStatefulWidget {
  final Color accent;
  final UserModel? partner;
  const _LoveDialCard({required this.accent, required this.partner});

  @override
  ConsumerState<_LoveDialCard> createState() => _LoveDialCardState();
}

class _LoveDialCardState extends ConsumerState<_LoveDialCard> {
  bool _expanded = true;
  bool _notificationsEnabled = true;
  bool _prefLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _prefLoaded = true;
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
    final accent = widget.accent;
    final authUser = FirebaseAuth.instance.currentUser;
    final moods = ref.watch(moodsProvider).valueOrNull ?? [];
    final couple = ref.watch(coupleProvider).valueOrNull;
    final uid = authUser?.uid;

    final myMood = moods.where((m) => m.uid == uid).firstOrNull;
    final partnerMood = moods.where((m) => m.uid != uid).firstOrNull;
    final partnerName = widget.partner?.displayName.split(' ').first ?? 'Partner';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Love Dial Connection',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const Text('Your connection, your world.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: AppColors.bgCardLight, shape: BoxShape.circle),
                    child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MoodBubble(mood: myMood?.mood, label: 'You', accent: accent),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DottedLink(accent: accent),
                        ),
                      ),
                      _MoodBubble(
                          mood: partnerMood?.mood,
                          label: partnerName,
                          accent: accent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_rounded, color: accent, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            myMood != null && partnerMood != null
                                ? moodComboMessage(myMood.mood, partnerMood.mood)
                                : 'Set your mood on Home to see how you two align ♡',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12.5,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Connection alerts
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Connection Alerts',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('Get notified about important moments',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_prefLoaded)
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeThumbColor: AppColors.rose,
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            // Theme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Theme',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('Choose your couple theme',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  ...kCoupleAccents.take(4).map((a) {
                    final color = a['color'] as Color;
                    final selected = couple?.themeColor == color.toARGB32();
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: () {
                          if (couple != null) {
                            HapticFeedback.selectionClick();
                            ref
                                .read(firestoreServiceProvider)
                                .updateCoupleTheme(couple.id, color.toARGB32());
                          }
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DottedLink extends StatelessWidget {
  final Color accent;
  const _DottedLink({required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(painter: _DotsPainter(color: accent.withValues(alpha: 0.5))),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.link_rounded, color: accent, size: 15),
          ),
          Expanded(
            child: CustomPaint(painter: _DotsPainter(color: accent.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  const _DotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dotRadius = 1.6;
    const gap = 7.0;
    final y = size.height / 2;
    var x = dotRadius;
    while (x < size.width - dotRadius) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
      x += gap;
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.color != color;
}

class _MoodBubble extends StatelessWidget {
  final MoodType? mood;
  final String label;
  final Color accent;
  const _MoodBubble({required this.mood, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCardLight,
            border: Border.all(
                color: mood != null ? accent.withValues(alpha: 0.4) : AppColors.divider,
                width: mood != null ? 1.5 : 0.5),
          ),
          child: Center(
            child: Text(mood?.emoji ?? '❔', style: const TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(mood?.label ?? 'Not set',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: mood != null ? AppColors.textPrimary : AppColors.textMuted)),
      ],
    );
  }
}

// ── Nickname ─────────────────────────────────────────────────────────────

class _NicknameSection extends ConsumerStatefulWidget {
  const _NicknameSection();

  @override
  ConsumerState<_NicknameSection> createState() => _NicknameSectionState();
}

class _NicknameSectionState extends ConsumerState<_NicknameSection> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  bool _inited = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nick = _ctrl.text.trim();
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).updateUser({'nickname': nick});
      if (mounted) HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (!_inited && me != null) {
      _ctrl.text = me.nickname ?? '';
      _inited = true;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💕', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text('Your nickname',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('What your partner sees in chat & notifications',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLength: 20,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'e.g. Bubu, Cutie, Chikoo…',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.bgMid,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
                        )
                      : const Text('Save',
                          style: TextStyle(
                              color: AppColors.rose, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
