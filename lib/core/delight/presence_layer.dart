// Presence & togetherness — the layer that makes the app feel shared.
//
//  • Walked-in moment: partner opens the app while you're in it → their
//    avatar slides in from the edge, the screen warms briefly, and a
//    heartbeat haptic plays.
//  • Warmth left behind: after they leave, a soft "was just here" trace
//    lingers and fades over ten minutes.
//  • Synced breathing: while you're both online, a barely-there warm glow
//    breathes at the bottom edge — almost subliminal.
//
// All of it respects Calm Mode.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'delight.dart';

class PresenceLayer extends ConsumerStatefulWidget {
  const PresenceLayer({super.key});

  @override
  ConsumerState<PresenceLayer> createState() => _PresenceLayerState();
}

class _PresenceLayerState extends ConsumerState<PresenceLayer>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _walkIn;

  bool? _lastOnline; // null until first real value — no fanfare on app open
  bool _showWalkIn = false;
  DateTime? _leftAt;
  Timer? _walkInTimer;
  Timer? _warmthTicker;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4200))
      ..repeat(reverse: true);
    _walkIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    // Refresh the fading warmth pill once a minute.
    _warmthTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _leftAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _walkInTimer?.cancel();
    _warmthTicker?.cancel();
    _breathe.dispose();
    _walkIn.dispose();
    super.dispose();
  }

  void _onWalkedIn() {
    if (ref.read(calmModeProvider)) return;
    DelightHaptics.heartbeat();
    setState(() {
      _showWalkIn = true;
      _leftAt = null;
    });
    _walkIn.forward(from: 0);
    _walkInTimer?.cancel();
    _walkInTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _showWalkIn = false);
    });
  }

  /// 1.0 right after they left → 0.0 after ten minutes.
  double get _warmth {
    if (_leftAt == null) return 0;
    final mins = DateTime.now().difference(_leftAt!).inMinutes;
    return (1 - mins / 10).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final calm = ref.watch(calmModeProvider);
    final online = ref.watch(partnerOnlineProvider).valueOrNull;
    final partner = ref.watch(partnerUserProvider).valueOrNull;
    final accent = ref.watch(accentColorProvider);

    if (online != null && online != _lastOnline) {
      final was = _lastOnline;
      _lastOnline = online;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (online && was == false) {
          _onWalkedIn();
        } else if (!online && was == true) {
          setState(() => _leftAt = DateTime.now());
        }
      });
    }

    final name = partner?.displayLabel.split(' ').first ?? 'Your person';
    final warmth = _warmth;

    return IgnorePointer(
      child: Stack(
        children: [
          // ── Synced breathing — soft glow along the bottom edge ──
          if (online == true && !calm)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: AnimatedBuilder(
                animation: _breathe,
                builder: (_, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        accent.withValues(
                            alpha: 0.05 + 0.07 * _breathe.value),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Walked-in moment ──
          if (_showWalkIn)
            AnimatedBuilder(
              animation: _walkIn,
              builder: (_, _) {
                final t = Curves.easeOutBack.transform(_walkIn.value);
                return Stack(
                  children: [
                    // The room brightens for a beat.
                    Positioned.fill(
                      child: Opacity(
                        opacity: (1 - _walkIn.value) * 0.14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                accent.withValues(alpha: 0.8),
                                accent.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -60 + 76 * t,
                      top: MediaQuery.of(context).size.height * 0.30,
                      child: _WalkInCard(
                          name: name,
                          avatarUrl: partner?.avatarUrl,
                          accent: accent),
                    ),
                  ],
                );
              },
            ),

          // ── Warmth left behind ──
          if (!_showWalkIn && online == false && warmth > 0 && !calm)
            Positioned(
              left: 14,
              bottom: 10,
              child: Opacity(
                opacity: 0.25 + 0.55 * warmth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25 * warmth),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    '$name was just here ✨',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WalkInCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Color accent;

  const _WalkInCard(
      {required this.name, required this.avatarUrl, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [accent, AppColors.coral]),
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover)
                : const Center(
                    child: Text('🙂', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Text('just walked in 💛',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}
