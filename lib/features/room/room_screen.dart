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
            final type = data['type'] as String? ?? 'thinkingOfYou';
            final message = data['message'] as String?;
            _showSignal(type: type, message: message);
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
      'goodMorning'  => ('☀️', 'Good morning from your person!'),
      'goodNight'    => ('🌙', 'Good night — sweet dreams ♡'),
      'gratitude'    => ('🙏', 'Your person is grateful for you today ♡'),
      _              => ('♡', message ?? 'Thinking of you ♡'),
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


  void _sendThinkingOfYou() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('♡', style: TextStyle(fontSize: 52, color: AppColors.rose)),
                const SizedBox(height: 12),
                Text('Thinking Of You',
                    style: Theme.of(ctx).textTheme.titleLarge),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        margin: const EdgeInsets.all(16),
                      ));
                    }
                  },
                ),
              ],
            ),
          ),
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
    final roomObjects = ref.watch(roomObjectsProvider).valueOrNull ?? [];
    final daysTogether = couple != null ? DateTime.now().difference(couple.createdAt).inDays : 0;

    // On This Day: memories created on today's month/day in a prior year
    final now = DateTime.now();
    final onThisDay = memories.where((m) =>
        m.createdAt.month == now.month &&
        m.createdAt.day == now.day &&
        m.createdAt.year < now.year).toList();

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
          // Top glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App bar
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
                      icon: const Icon(Icons.tune_rounded, color: AppColors.textSecondary),
                      onPressed: () => _showSettings(context),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // Avatars card
                      _AvatarCard(me: me, partner: partner, accent: accent)
                          .animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
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

                      // Thinking of you — big hero button
                      _ThinkingOfYouButton(accent: accent, onTap: _sendThinkingOfYou)
                          .animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                      const SizedBox(height: 12),

                      // Quick send row: Good Morning / Good Night / Gratitude
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

                      // Room objects
                      if (roomObjects.isNotEmpty) ...[
                        _SectionHeader(title: 'In your room', count: roomObjects.length),
                        const SizedBox(height: 10),
                        _RoomObjectsRow(objects: roomObjects, accent: accent)
                            .animate().fadeIn(delay: 250.ms),
                        const SizedBox(height: 16),
                      ],

                      // Recent memories preview
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

          // Floating heart
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
                      child: const Text('♡', style: TextStyle(fontSize: 40, color: AppColors.rose)),
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

class _AvatarCard extends StatelessWidget {
  final dynamic me;
  final dynamic partner;
  final Color accent;
  const _AvatarCard({this.me, this.partner, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _CharCol(user: me, color: accent, isMe: true)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TwoHeartsLogo(size: 30),
              const SizedBox(height: 4),
              Text('together',
                  style: TextStyle(fontSize: 10, color: accent, letterSpacing: 1)),
            ],
          ),
          Expanded(
            child: _CharCol(user: partner, color: AppColors.lavender, isMe: false),
          ),
        ],
      ),
    );
  }
}

class _CharCol extends StatelessWidget {
  final dynamic user;
  final Color color;
  final bool isMe;
  const _CharCol({this.user, required this.color, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName as String? ?? (isMe ? 'You' : '?');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CharacterAvatar(color: color, name: name, size: 86),
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

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
              shaderCallback: (b) => LinearGradient(
                colors: [accent, AppColors.coral],
              ).createShader(b),
              child: Text(value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

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
            colors: [accent.withValues(alpha: 0.2), AppColors.coral.withValues(alpha: 0.1)],
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
                  BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6)),
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
          child: Text('$count', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _RoomObjectsRow extends StatelessWidget {
  final List<RoomObject> objects;
  final Color accent;
  const _RoomObjectsRow({required this.objects, required this.accent});

  String _emojiFor(RoomObjectType t) {
    switch (t) {
      case RoomObjectType.photoFrame: return '🖼️';
      case RoomObjectType.letterEnvelope: return '💌';
      case RoomObjectType.journalBook: return '📖';
      case RoomObjectType.bucketTrophy: return '🏆';
      case RoomObjectType.gift: return '🎁';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: objects.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final obj = objects[i];
          return Container(
            width: 72,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_emojiFor(obj.type), style: const TextStyle(fontSize: 26)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemoryPreview extends StatelessWidget {
  final List<dynamic> memories;
  const _MemoryPreview({required this.memories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: memories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 100,
              color: AppColors.bgCard,
              child: memories[i].imageUrl.isNotEmpty
                  ? Image.network(memories[i].imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: AppColors.textMuted))
                  : const Icon(Icons.image_outlined, color: AppColors.textMuted),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).valueOrNull;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
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
                    await ref.read(firestoreServiceProvider).updateCoupleTheme(couple.id, color.toARGB32());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)] : null,
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
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
                  Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
                  SizedBox(width: 12),
                  Text('Sign out', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
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
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
            child: Image.network(
              memory.imageUrl,
              width: 80, height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80, height: 80, color: AppColors.bgCard,
                child: const Icon(Icons.photo_outlined, color: AppColors.textMuted),
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
                      style: TextStyle(color: accent, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text(
                  memory.caption?.isNotEmpty == true ? memory.caption! : 'A memory from this day',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
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
        Expanded(child: _QuickBtn(emoji: '☀️', label: 'Morning', onTap: onMorning, accent: accent)),
        const SizedBox(width: 8),
        Expanded(child: _QuickBtn(emoji: '🌙', label: 'Night', onTap: onNight, accent: accent)),
        const SizedBox(width: 8),
        Expanded(child: _QuickBtn(emoji: '🙏', label: 'Grateful', onTap: onGratitude, accent: accent)),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  const _QuickBtn({required this.emoji, required this.label,
      required this.onTap, required this.accent});

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
            Text(label, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
