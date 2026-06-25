import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_service.dart';
import '../../core/firebase/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with TickerProviderStateMixin {
  bool _heartVisible = false;
  late AnimationController _heartCtrl;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _watchSignals();
  }

  void _watchSignals() {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    ref.read(firestoreServiceProvider).watchSignals(coupleId).listen((snap) {
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data() as Map<String, dynamic>;
        final uid = FirebaseAuth.instance.currentUser!.uid;
        if (data['fromUid'] != uid) {
          _showHeart();
        }
      }
    });
  }

  void _showHeart() {
    setState(() => _heartVisible = true);
    _heartCtrl.forward(from: 0);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _heartVisible = false);
    });
  }

  Future<void> _sendThinkingOfYou() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    await ref.read(firestoreServiceProvider).sendThinkingOfYou(coupleId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('♡ Sent to your person'),
        backgroundColor: ref.read(accentColorProvider),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final roomObjects = ref.watch(roomObjectsProvider).valueOrNull ?? [];
    final memories = ref.watch(memoriesProvider).valueOrNull ?? [];
    final letters = ref.watch(lettersProvider).valueOrNull ?? [];

    return Scaffold(
      body: Stack(
        children: [
          // Room background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withOpacity(0.08),
                  AppColors.warmCream,
                  AppColors.softPeach.withOpacity(0.4),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: couple != null
                      ? Text(
                          '${me?.displayName.split(' ').first ?? '?'} & ${partner?.displayName.split(' ').first ?? '?'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                      : const Text('Our Room'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => _showSettingsSheet(context),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatars row
                        _AvatarRow(
                          me: me,
                          partner: partner,
                          accent: accent,
                        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
                        const SizedBox(height: 24),

                        // Stats row
                        _StatsRow(
                          memories: memories.length,
                          letters: letters.length,
                          roomObjects: roomObjects.length,
                          couple: couple,
                          accent: accent,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 24),

                        // Room object gallery
                        if (roomObjects.isNotEmpty) ...[
                          Text('In your room',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _RoomObjectsGrid(objects: roomObjects, accent: accent),
                          const SizedBox(height: 24),
                        ],

                        // Quick actions
                        Text('Quick moments',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _QuickActions(accent: accent, onThinkingOfYou: _sendThinkingOfYou),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating heart animation
          if (_heartVisible)
            Positioned(
              left: MediaQuery.of(context).size.width / 2 - 30,
              bottom: 120,
              child: AnimatedBuilder(
                animation: _heartCtrl,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, -200 * _heartCtrl.value),
                  child: Opacity(
                    opacity: 1 - _heartCtrl.value,
                    child: const Text('♡', style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final couple = ref.read(coupleProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(couple: couple),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final UserModel? me;
  final UserModel? partner;
  final Color accent;

  const _AvatarRow({this.me, this.partner, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(child: _AvatarCard(user: me, accent: accent, isMe: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('♡', style: TextStyle(fontSize: 28, color: accent)),
          ),
          Expanded(child: _AvatarCard(user: partner, accent: accent, isMe: false)),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final UserModel? user;
  final Color accent;
  final bool isMe;

  const _AvatarCard({this.user, required this.accent, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withOpacity(0.15),
            border: Border.all(color: accent.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: Text(
              user?.displayName.isNotEmpty == true
                  ? user!.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user?.displayName.split(' ').first ?? (isMe ? 'You' : 'Partner'),
          style: Theme.of(context).textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
        if (isMe)
          Text('Lv.${user?.level ?? 1}',
              style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int memories;
  final int letters;
  final int roomObjects;
  final CoupleModel? couple;
  final Color accent;

  const _StatsRow({
    required this.memories,
    required this.letters,
    required this.roomObjects,
    this.couple,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final daysTogether = couple != null
        ? DateTime.now().difference(couple!.createdAt).inDays
        : 0;
    return Row(
      children: [
        _StatChip(label: 'Days', value: '$daysTogether', accent: accent),
        const SizedBox(width: 8),
        _StatChip(label: 'Memories', value: '$memories', accent: accent),
        const SizedBox(width: 8),
        _StatChip(label: 'Letters', value: '$letters', accent: accent),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _StatChip({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accent)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.warmGray)),
          ],
        ),
      ),
    );
  }
}

class _RoomObjectsGrid extends StatelessWidget {
  final List<RoomObject> objects;
  final Color accent;

  const _RoomObjectsGrid({required this.objects, required this.accent});

  IconData _iconFor(RoomObjectType type) {
    switch (type) {
      case RoomObjectType.photoFrame: return Icons.image_outlined;
      case RoomObjectType.letterEnvelope: return Icons.mail_outline;
      case RoomObjectType.journalBook: return Icons.menu_book_rounded;
      case RoomObjectType.bucketTrophy: return Icons.emoji_events_outlined;
      case RoomObjectType.gift: return Icons.card_giftcard_outlined;
    }
  }

  String _labelFor(RoomObjectType type) {
    switch (type) {
      case RoomObjectType.photoFrame: return 'Photo';
      case RoomObjectType.letterEnvelope: return 'Letter';
      case RoomObjectType.journalBook: return 'Journal';
      case RoomObjectType.bucketTrophy: return 'Trophy';
      case RoomObjectType.gift: return 'Gift';
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = objects.take(6).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: shown.map((obj) {
        return Container(
          width: (MediaQuery.of(context).size.width - 60) / 3,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Icon(_iconFor(obj.type), color: accent, size: 28),
              const SizedBox(height: 4),
              Text(_labelFor(obj.type),
                  style: const TextStyle(fontSize: 11, color: AppColors.warmGray)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final Color accent;
  final VoidCallback onThinkingOfYou;

  const _QuickActions({required this.accent, required this.onThinkingOfYou});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onThinkingOfYou,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.15), accent.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text('♡', style: TextStyle(fontSize: 36, color: accent)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thinking Of You',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('Tap to send a heart',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: accent),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  final CoupleModel? couple;
  const _SettingsSheet({this.couple});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('Couple accent color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: kCoupleAccents.map((a) {
              final color = a['color'] as Color;
              final isSelected = couple?.themeColor == color.value;
              return GestureDetector(
                onTap: () async {
                  if (couple != null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateCoupleTheme(couple!.id, color.value);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_outlined, color: AppColors.warmGray),
            title: const Text('Sign out'),
            onTap: () {
              FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
